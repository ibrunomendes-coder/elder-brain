#!/usr/bin/env python3
"""Elder Brain status helper for the Omarchy plugin and heartbeat timer.

Queries a remote ai-memory server over MCP-over-HTTP and writes exactly one JSON
object to stdout. Python standard library only; no pip dependencies.

The Bearer token is read from ~/.config/elder-brain/token and is never written
by this script. With --heartbeat, the helper updates machines/<host>.md so the
status panel can determine which client machines are alive.
"""

import json
import os
import socket
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

TOKEN_FILE = Path.home() / ".config" / "elder-brain" / "token"
URL_FILE = Path.home() / ".config" / "elder-brain" / "url"
SCOPE_FILE = Path.home() / ".config" / "elder-brain" / "scope"
MACHINES_FILE = Path.home() / ".config" / "elder-brain" / "machines"
TIMEOUT = 6


def load_url() -> str:
    """Load the server URL from ELDER_BRAIN_URL or the local config file."""
    if os.environ.get("ELDER_BRAIN_URL"):
        return os.environ["ELDER_BRAIN_URL"].rstrip("/")
    if URL_FILE.exists():
        return URL_FILE.read_text().strip().rstrip("/")
    raise RuntimeError(
        "server URL is not configured: set ELDER_BRAIN_URL or write "
        "~/.config/elder-brain/url (for example: http://<PRIVATE_IP>:49374)"
    )


def load_scope() -> dict:
    """Load the canonical workspace/project scope from env or local config."""
    value = os.environ.get("ELDER_BRAIN_SCOPE", "").strip()
    if not value and SCOPE_FILE.exists():
        value = SCOPE_FILE.read_text().strip()
    if not value:
        return {}
    parts = value.split("/", 1)
    if len(parts) != 2 or not all(part.strip() for part in parts):
        raise RuntimeError(
            "invalid scope: use workspace/project in ELDER_BRAIN_SCOPE "
            "or ~/.config/elder-brain/scope"
        )
    return {"workspace": parts[0].strip(), "project": parts[1].strip()}


def known_machines() -> list:
    """Load colony hostnames from ~/.config/elder-brain/machines."""
    if MACHINES_FILE.exists():
        return [
            line.strip()
            for line in MACHINES_FILE.read_text().splitlines()
            if line.strip() and not line.startswith("#")
        ]
    return [socket.gethostname().lower()]


def load_token() -> str:
    return TOKEN_FILE.read_text().strip()


def mcp_call(tool: str, args: dict, token: str, url: str) -> dict:
    body = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": int(time.time() * 1000),
            "method": "tools/call",
            "params": {"name": tool, "arguments": args},
        }
    ).encode()
    request = urllib.request.Request(
        f"{url}/mcp",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": f"Bearer {token}",
        },
    )
    started = time.monotonic()
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        raw = response.read().decode()
    latency_ms = int((time.monotonic() - started) * 1000)

    # MCP responses may be direct JSON or SSE (`data: {...}`).
    if raw.lstrip().startswith("{"):
        payload = json.loads(raw)
    else:
        line = next(
            (line for line in raw.splitlines() if line.startswith("data:")),
            "data: {}",
        )
        payload = json.loads(line[5:].strip())

    if payload.get("error"):
        raise RuntimeError(payload["error"].get("message", "MCP error"))

    text = (payload.get("result", {}).get("content") or [{}])[0].get("text", "")
    try:
        inner = json.loads(text)
    except json.JSONDecodeError:
        inner = {"raw": text}
    inner["_latency_ms"] = latency_ms
    return inner


def heartbeat(token: str, url: str, scope: dict) -> None:
    host = socket.gethostname().lower()
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    args = {
        "path": f"machines/{host}.md",
        "body": f"# {host}\n\n- **last_seen:** {now}\n- **agent:** elder-brain-status heartbeat\n",
        **scope,
    }
    mcp_call("memory_write_page", args, token, url)


def machine_states(token: str, url: str, scope: dict) -> list:
    states = []
    now = datetime.now(timezone.utc)
    for name in known_machines():
        entry = {"name": name, "alive": False, "last_seen": None, "age_min": None}
        try:
            page = mcp_call(
                "memory_read_page",
                {"path": f"machines/{name}.md", **scope},
                token,
                url,
            )
            content = page.get("body") or page.get("content") or page.get("raw") or ""
            for line in content.splitlines():
                if "last_seen:" in line:
                    timestamp = line.split("last_seen:", 1)[1].strip().strip("*").strip()
                    seen = datetime.fromisoformat(timestamp)
                    entry["last_seen"] = timestamp
                    entry["age_min"] = round((now - seen).total_seconds() / 60, 1)
                    entry["alive"] = entry["age_min"] < 90
        except Exception:
            # A missing or malformed heartbeat marks only that machine offline;
            # it must not make the entire status request fail.
            pass
        states.append(entry)
    return states


def main() -> None:
    try:
        url = load_url()
        token = load_token()
        scope = load_scope()
    except Exception as exc:
        print(json.dumps({"ok": False, "alive": False, "error": str(exc)}))
        return

    if "--heartbeat" in sys.argv:
        try:
            heartbeat(token, url, scope)
            print(json.dumps({"ok": True, "heartbeat": socket.gethostname().lower()}))
        except Exception as exc:
            print(json.dumps({"ok": False, "error": str(exc)}))
        return

    output = {
        "ok": True,
        "alive": False,
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    try:
        status = mcp_call("memory_status", scope, token, url)
        output["alive"] = True
        output["latency_ms"] = status.pop("_latency_ms", None)
        output["counts"] = status.get("counts", {})

        # Heartbeats are infrastructure, not meaningful recent memory activity.
        # Fetch extra rows so six content entries remain after filtering.
        recent = mcp_call("memory_recent", {"limit": 12, **scope}, token, url)
        meaningful = [
            hit
            for hit in recent.get("hits", [])
            if not str(hit.get("path", "")).startswith("machines/")
        ]
        output["recent"] = [
            {"title": hit.get("title", ""), "path": hit.get("path", "")}
            for hit in meaningful[:6]
        ]
        output["machines"] = machine_states(token, url, scope)
    except (urllib.error.URLError, RuntimeError, TimeoutError, OSError) as exc:
        output["ok"] = False
        output["error"] = str(exc)

    print(json.dumps(output, ensure_ascii=False))


if __name__ == "__main__":
    main()
