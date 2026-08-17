#!/usr/bin/env python3
"""Elder Brain status helper para o plugin Omarchy.

Consulta a memória coletiva (ai-memory central na VPS Hermes) via MCP-over-HTTP
e imprime UM objeto JSON no stdout. Só stdlib — sem pip.

Token lido de ~/.config/elder-brain/token (nunca em config nem em disco por este
script). Com --heartbeat, grava/atualiza a página machines/<host>.md no Elder
Brain (é assim que o painel sabe quais máquinas estão vivas).
"""

import json
import socket
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

TOKEN_FILE = Path.home() / ".config" / "elder-brain" / "token"
URL_FILE = Path.home() / ".config" / "elder-brain" / "url"
MACHINES_FILE = Path.home() / ".config" / "elder-brain" / "machines"
TIMEOUT = 6


def load_url() -> str:
    """URL do servidor: env ELDER_BRAIN_URL ou ~/.config/elder-brain/url."""
    import os
    if os.environ.get("ELDER_BRAIN_URL"):
        return os.environ["ELDER_BRAIN_URL"].rstrip("/")
    if URL_FILE.exists():
        return URL_FILE.read_text().strip().rstrip("/")
    raise RuntimeError(
        "URL não configurada: defina ELDER_BRAIN_URL ou escreva "
        "~/.config/elder-brain/url (ex.: http://100.x.y.z:49374)"
    )


def known_machines() -> list:
    """Máquinas da colônia: ~/.config/elder-brain/machines (uma por linha)."""
    if MACHINES_FILE.exists():
        return [l.strip() for l in MACHINES_FILE.read_text().splitlines()
                if l.strip() and not l.startswith("#")]
    return [socket.gethostname().lower()]


def load_token() -> str:
    return TOKEN_FILE.read_text().strip()


def mcp_call(tool: str, args: dict, token: str, url: str) -> dict:
    body = json.dumps({
        "jsonrpc": "2.0",
        "id": int(time.time() * 1000),
        "method": "tools/call",
        "params": {"name": tool, "arguments": args},
    }).encode()
    req = urllib.request.Request(
        f"{url}/mcp",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "Authorization": f"Bearer {token}",
        },
    )
    started = time.monotonic()
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        raw = resp.read().decode()
    latency_ms = int((time.monotonic() - started) * 1000)
    # Resposta pode ser JSON direto ou SSE (linhas "data: {...}").
    if raw.lstrip().startswith("{"):
        payload = json.loads(raw)
    else:
        line = next((l for l in raw.splitlines() if l.startswith("data:")), "data: {}")
        payload = json.loads(line[5:].strip())
    if payload.get("error"):
        raise RuntimeError(payload["error"].get("message", "erro MCP"))
    text = (payload.get("result", {}).get("content") or [{}])[0].get("text", "")
    try:
        inner = json.loads(text)
    except json.JSONDecodeError:
        inner = {"raw": text}
    inner["_latency_ms"] = latency_ms
    return inner


def heartbeat(token: str, url: str) -> None:
    host = socket.gethostname().lower()
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    mcp_call("memory_write_page", {
        "path": f"machines/{host}.md",
        "body": f"# {host}\n\n- **last_seen:** {now}\n- **agente:** heartbeat elder-brain-status\n",
    }, token, url)


def machine_states(token: str, url: str) -> list:
    states = []
    now = datetime.now(timezone.utc)
    for name in known_machines():
        entry = {"name": name, "alive": False, "last_seen": None, "age_min": None}
        try:
            page = mcp_call("memory_read_page", {"path": f"machines/{name}.md"}, token, url)
            content = page.get("body") or page.get("content") or page.get("raw") or ""
            for line in content.splitlines():
                if "last_seen:" in line:
                    ts = line.split("last_seen:", 1)[1].strip().strip("*").strip()
                    seen = datetime.fromisoformat(ts)
                    entry["last_seen"] = ts
                    entry["age_min"] = round((now - seen).total_seconds() / 60, 1)
                    entry["alive"] = entry["age_min"] < 90
        except Exception:
            pass
        states.append(entry)
    return states


def main() -> None:
    try:
        url = load_url()
        token = load_token()
    except Exception as exc:
        print(json.dumps({"ok": False, "alive": False, "error": str(exc)}))
        return

    if "--heartbeat" in sys.argv:
        try:
            heartbeat(token, url)
            print(json.dumps({"ok": True, "heartbeat": socket.gethostname().lower()}))
        except Exception as exc:
            print(json.dumps({"ok": False, "error": str(exc)}))
        return

    out = {"ok": True, "alive": False, "ts": datetime.now(timezone.utc).isoformat(timespec="seconds")}
    try:
        status = mcp_call("memory_status", {}, token, url)
        out["alive"] = True
        out["latency_ms"] = status.pop("_latency_ms", None)
        out["counts"] = status.get("counts", {})
        recent = mcp_call("memory_recent", {"limit": 6}, token, url)
        out["recent"] = [
            {"title": h.get("title", ""), "path": h.get("path", "")}
            for h in recent.get("hits", [])[:6]
        ]
        out["machines"] = machine_states(token, url)
    except (urllib.error.URLError, RuntimeError, TimeoutError, OSError) as exc:
        out["ok"] = False
        out["error"] = str(exc)
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
