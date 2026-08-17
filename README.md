<div align="center">

<img src="assets/logo.png" width="140" alt="Elder Brain"/>

# Elder Brain

**Collective memory for AI agents** — one self-hosted server that every agent,
on every machine, reads from and writes to.

[![License: MIT](https://img.shields.io/badge/license-MIT-2b2b2b)](LICENSE)
[![Protocol](https://img.shields.io/badge/protocol-MCP--over--HTTP-4a3f35)](https://modelcontextprotocol.io)
[![Deploy](https://img.shields.io/badge/deploy-docker--compose-4a3f35)](deploy/)

[Português (Brasil)](README.pt-BR.md)

</div>

What one Claude learns on your desktop, the agent on your laptop already knows.
A living memory organism — yours, on your infrastructure, outside any vendor.

<div align="center">
<img src="assets/panel-omarchy.png" width="380" alt="Elder Brain status panel for Omarchy — health, latency, page/session/observation counts, connected machines and recent activity (UI shown in pt-BR)"/>
<br/><sub>The Omarchy status panel: health, latency, counts, connected machines, recent activity.</sub>
</div>

## Why

AI agents accumulate experience every session — decisions, corrections, hard-won
context. By default that memory dies on the machine where it was born. Elder
Brain centralizes it:

```
laptop ──┐
desktop ─┼─→  elder-brain (your VPS, private network)  ←── any future machine
CI ──────┘        one Bearer token + one URL = the same living memory everywhere
```

- **Agent-agnostic** — speaks MCP-over-HTTP: Claude Code, Pi, Codex, scripts, any MCP client
- **Self-hosted** — one Docker container; data is SQLite + Markdown, on your disk
- **Private by design** — binds to a private network (Tailscale/VPN/LAN) and refuses to run without an auth token
- **Observable** — a status bar panel shows health, latency and which machines are alive

Elder Brain is a **distribution, not a fork**: it deploys the excellent
[`akitaonrails/ai-memory`](https://github.com/akitaonrails/ai-memory) server
unmodified, and adds everything around it — deployment recipe, multi-machine
conventions, client installer, status CLI and the Omarchy panel.

## Quickstart

### 1. Server (any Linux host with Docker)

```bash
cp deploy/.env.example deploy/.env   # fill in: token, BIND_IP, GEMINI_API_KEY
cd deploy && docker compose up -d

# validate: no token must give 401, with token it opens
curl -i http://<BIND_IP>:49374/web/
curl -i -H "Authorization: Bearer <TOKEN>" http://<BIND_IP>:49374/web/
```

> ⚠️ Publish **only on a private network** (Tailscale, WireGuard, LAN). For
> public exposure put a TLS reverse proxy in front — see [docs/security.md](docs/security.md).

### 2. Each client machine

```bash
./scripts/install.sh
# interactive: asks URL + token, wires Claude Code hooks,
# heartbeat and (optionally) the Omarchy panel
```

Manual path: **[docs/install.md](docs/install.md)**.

### 3. Verify

```bash
elder-brain-status
# {"ok": true, "alive": true, "latency_ms": 34, "counts": {...}, "machines": [...]}
```

## Scope routing — read this before your second machine

Hooks route each event by walking up from the session's working directory
looking for a `.ai-memory.toml` marker. **No marker means the server buckets
your memory by folder name and your colony silently fragments.** Pin one
canonical scope everywhere:

```toml
# ~/.ai-memory.toml  (and at the root of every work tree OUTSIDE $HOME)
workspace = "default"
project   = "your-name"
```

Rule of thumb: every work root that is not under `$HOME` (e.g. `/mnt/storage`)
needs its own marker. A marker dropped in a synced folder (Dropbox root, etc.)
propagates to the whole colony for free. Routing is evaluated **per event**, so
a running session migrates to the right bucket the moment the marker appears.

## What's in the box

| Path | What it is |
|---|---|
| `deploy/` | Docker Compose for the server (parameterized, private-bind, token required) |
| `scripts/install.sh` | Interactive client-machine installer |
| `scripts/elder-brain-status` | Status CLI (Python stdlib only): health, counts, machines, recent activity |
| `omarchy-plugin/` | Status bar panel for [Omarchy](https://omarchy.org) — live icon, latency, machines, activity |
| `docs/` | Install guide, security model, runbook |

## How agents connect

| Agent | Integration |
|---|---|
| **Claude Code** | Lifecycle hooks (`session-start`, `post-tool-use`, `pre-compact`…) pointed at the server via `AI_MEMORY_HOOK_URL` + `AI_MEMORY_AUTH_TOKEN` |
| **Pi** | Extension with recall/recent/status tools (MCP-over-HTTP) |
| **Any MCP client** | `POST /mcp` with `Authorization: Bearer <token>` |

Machines announce themselves with an hourly heartbeat (a `machines/<host>.md`
page) — that is how the panel knows who is alive.

## Security & privacy

Short version — the full model lives in [docs/security.md](docs/security.md):

- The server **refuses** a non-loopback bind without `AI_MEMORY_AUTH_TOKEN`; whoever holds the token reads and writes the whole memory. Treat it as a master password, rotate it from the server `.env`.
- Session **content flows to your server** — and, if you enable LLM consolidation/embeddings, to that LLM provider too. If your sessions touch sensitive work, use a paid API tier (whose terms exclude training) or a local provider.
- Keep secrets out of agent sessions; anything an agent sees can end up in memory.
- Back up the data dir (`SQLite + Markdown`) — and **encrypt before shipping offsite** (e.g. `age` + rclone).

## Status

v0.1 — running in production on the author's fleet (desktop + laptop + VPS,
Tailscale mesh, ~60k observations). The recipe is small on purpose: read it in
one sitting, deploy in one evening.

## Credits & license

Built on [`ai-memory`](https://github.com/akitaonrails/ai-memory) by
[AkitaOnRails](https://github.com/akitaonrails) (its own license applies to the
server). The Cthulhu medallion artwork is third-party and **not** covered by the MIT license. Everything else in this repository — recipe, scripts, panel — is
[MIT](LICENSE).
