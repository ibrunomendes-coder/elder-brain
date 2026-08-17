# Elder Brain installation guide

This guide deploys one private ai-memory server and connects any number of client machines to the same canonical memory scope.

## 0. Prerequisites

### Server

- Linux host that remains online (a VPS, home server or always-on workstation)
- Docker Engine with Docker Compose
- a private network path from every client to the server: Tailscale, WireGuard or a trusted LAN
- optional LLM API key for consolidation and embeddings

### Clients

- Linux or macOS machine that can reach the private server address
- `curl` and Python 3
- ai-memory client/hooks when integrating Claude Code
- optional Omarchy installation for the status panel

> Do not publish the plain HTTP service directly to the public internet. Read [security.md](security.md) before deploying.

## 1. Deploy the server

```bash
git clone https://github.com/ibrunomendes-coder/elder-brain.git
cd elder-brain/deploy
cp .env.example .env
chmod 600 .env
```

Generate the master Bearer token:

```bash
openssl rand -hex 32
```

Edit `.env`:

```dotenv
AI_MEMORY_AUTH_TOKEN=<GENERATED_TOKEN>
BIND_IP=<PRIVATE_INTERFACE_IP>
ALLOWED_HOSTS=localhost,127.0.0.1,::1,<PRIVATE_INTERFACE_IP>
GEMINI_API_KEY=<OPTIONAL_PROVIDER_KEY>
```

Start the server:

```bash
docker compose config
docker compose up -d
docker compose ps
docker compose logs --tail=100 elder-brain
```

### Validate the authentication boundary

A request without the token must be rejected:

```bash
curl -i http://<PRIVATE_INTERFACE_IP>:49374/web/
# expected: HTTP 401
```

The authenticated request must reach the web endpoint:

```bash
TOKEN=$(cat .env | awk -F= '$1 == "AI_MEMORY_AUTH_TOKEN" {print $2}')
curl -i \
  -H "Authorization: Bearer $TOKEN" \
  http://<PRIVATE_INTERFACE_IP>:49374/web/
# expected: HTTP 200 or redirect
```

Do not paste the token into shell history on shared machines. The example above reads it from the local mode-600 file.

### Pin the image after evaluation

The example defaults to `akitaonrails/ai-memory:latest` for discovery. For a production deployment, resolve and pin a tested version or digest in `.env`:

```dotenv
AI_MEMORY_IMAGE=akitaonrails/ai-memory@sha256:<TESTED_DIGEST>
```

Updates then become deliberate operations instead of silent supply-chain changes.

## 2. Back up the server data

All durable memory lives in `deploy/data/` as SQLite plus Markdown pages.

A valid backup must:

1. include the entire data directory;
2. preserve ownership expected by container UID/GID `1000:1000`;
3. be encrypted before leaving the host;
4. be restored and tested periodically.

Example local snapshot:

```bash
docker compose stop elder-brain
tar -C . -czf elder-brain-data-$(date +%F).tar.gz data/
docker compose start elder-brain
```

For offsite storage, encrypt the archive first (for example with `age`) and only then upload it.

## 3. Connect a client with the interactive installer

From the repository root:

```bash
./scripts/install.sh
```

The installer asks for:

- private server URL;
- Bearer token (hidden input);
- canonical `workspace/project` scope;
- optional Claude Code hook migration;
- optional hourly heartbeat;
- optional Omarchy panel.

It writes credentials only to `~/.config/elder-brain/` with private permissions and creates timestamped backups before modifying Claude Code settings.

## 4. Manual client configuration

```bash
install -dm700 ~/.config/elder-brain
printf '%s' '<TOKEN>' > ~/.config/elder-brain/token
printf '%s' 'http://<PRIVATE_INTERFACE_IP>:49374' > ~/.config/elder-brain/url
printf '%s' 'default/<YOUR_PROJECT>' > ~/.config/elder-brain/scope
printf '%s\n' 'studio' 'laptop' > ~/.config/elder-brain/machines
chmod 600 ~/.config/elder-brain/{token,url,scope,machines}
```

### Why the canonical scope is mandatory

ai-memory routes events by `workspace/project`. Without an explicit shared scope, different working directories can silently create separate memory buckets. The data still exists, but clients appear to disagree about pages, sessions, observations and machine heartbeats.

Use the same value on every client:

```text
default/<YOUR_PROJECT>
```

Also create an ai-memory marker for session hooks:

```toml
# ~/.ai-memory.toml
workspace = "default"
project = "<YOUR_PROJECT>"
```

The marker search walks upward from the current working directory. Any work root outside `$HOME` needs its own `.ai-memory.toml` at or above that tree—for example `/mnt/storage/.ai-memory.toml` or the root of a synced projects folder.

## 5. Claude Code integration

Install the upstream ai-memory hooks first:

```bash
ai-memory install-hooks --apply
```

Each ai-memory hook command in `~/.claude/settings.json` must receive the remote URL and token:

```json
{
  "type": "command",
  "command": "AI_MEMORY_HOOK_URL=http://<PRIVATE_INTERFACE_IP>:49374 AI_MEMORY_AUTH_TOKEN=$(cat $HOME/.config/elder-brain/token) $HOME/.local/share/ai-memory/hooks/claude-code/session-start.sh"
}
```

The interactive installer patches detected localhost hooks automatically and backs up the original settings file.

Test a session-start event:

```bash
echo '{"session_id":"elder-brain-test","cwd":"'"$HOME"'"}' | \
  AI_MEMORY_HOOK_URL="$(cat ~/.config/elder-brain/url)" \
  AI_MEMORY_AUTH_TOKEN="$(cat ~/.config/elder-brain/token)" \
  sh ~/.local/share/ai-memory/hooks/claude-code/session-start.sh
```

An empty JSON object (`{}`) indicates success. An authentication error means the URL or token does not match the server.

## 6. Pi integration

A Pi extension can expose tools such as:

- `elder_brain_recall`
- `elder_brain_recent`
- `elder_brain_status`

Clients may read configuration from:

```text
~/.config/elder-brain/url
~/.config/elder-brain/token
~/.config/elder-brain/scope
```

or from environment variables:

```text
ELDER_BRAIN_URL
ELDER_BRAIN_TOKEN
ELDER_BRAIN_SCOPE
```

The extension itself is not bundled in this repository; use the client integration appropriate to your agent runtime.

## 7. Enable machine heartbeats

Install the status helper:

```bash
install -Dm755 scripts/elder-brain-status ~/.local/bin/elder-brain-status
```

Create the systemd user service:

```ini
# ~/.config/systemd/user/elder-brain-heartbeat.service
[Unit]
Description=Elder Brain heartbeat

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 %h/.local/bin/elder-brain-status --heartbeat
```

Create the timer:

```ini
# ~/.config/systemd/user/elder-brain-heartbeat.timer
[Unit]
Description=Hourly Elder Brain heartbeat

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and test it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now elder-brain-heartbeat.timer
systemctl --user start elder-brain-heartbeat.service
journalctl --user -u elder-brain-heartbeat.service --since today
```

The helper writes `machines/<hostname>.md` inside the configured canonical scope. A machine is considered alive when its heartbeat is less than 90 minutes old.

## 8. Install the Omarchy panel manually

The interactive installer can perform this step. To do it manually:

```bash
username=$(id -un)
plugin_id="$username.elder-brain"
plugin_dir="$HOME/.config/omarchy/plugins/$plugin_id"

cp -a omarchy-plugin "$plugin_dir"
sed -i \
  -e "s/\"id\": \"community.elder-brain\"/\"id\": \"$plugin_id\"/" \
  "$plugin_dir/manifest.json"
sed -i \
  -e "s/moduleName: \"community.elder-brain\"/moduleName: \"$plugin_id\"/" \
  -e "s/ipcTarget: \"community.elder-brain\"/ipcTarget: \"$plugin_id\"/" \
  "$plugin_dir/Panel.qml"

omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable "$plugin_id" --section right
```

The panel displays server availability, latency, page/session/observation counts, known machines and recent non-heartbeat activity.

## 9. Verify the complete client

```bash
elder-brain-status | jq
```

Expected shape:

```json
{
  "ok": true,
  "alive": true,
  "latency_ms": 34,
  "counts": {
    "pages_latest": 128,
    "sessions": 42,
    "observations": 12480
  },
  "machines": [],
  "recent": []
}
```

Also verify permissions:

```bash
stat -c '%a %n' ~/.config/elder-brain/{token,url,scope,machines}
# expected: 600 for every file
```

## 10. Rollback

To stop using the shared server:

1. disable the heartbeat timer;
2. point ai-memory hooks back to a local server or remove the remote environment variables;
3. remove the Omarchy panel if installed;
4. keep or archive `~/.config/elder-brain/` according to your credential-retention policy.

```bash
systemctl --user disable --now elder-brain-heartbeat.timer
```

No server-side memory is deleted by disconnecting a client.
