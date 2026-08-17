#!/usr/bin/env bash
# Interactive client-machine installer for Elder Brain.
# Writes only to user-owned config, local binaries, systemd user units and
# optional Claude Code / Omarchy configuration. No sudo required.
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR="$HOME/.config/elder-brain"

echo "🧠 Elder Brain — client machine setup"
echo

# --- 1. Connection and canonical scope -----------------------------------------
read -rp "Server URL (for example, http://<PRIVATE_IP>:49374): " URL
URL="${URL%/}"
read -rsp "Bearer token: " TOKEN
echo
DEFAULT_SCOPE="default/$(id -un)"
read -rp "Canonical scope [${DEFAULT_SCOPE}]: " SCOPE
SCOPE="${SCOPE:-$DEFAULT_SCOPE}"

[[ "$SCOPE" == */* ]] || {
  echo "Invalid scope; use workspace/project." >&2
  exit 1
}
[[ -n "$URL" && -n "$TOKEN" ]] || {
  echo "Server URL and token are required." >&2
  exit 1
}
case "$URL" in
  http://* | https://*) ;;
  *) echo "Server URL must start with http:// or https://." >&2; exit 1 ;;
esac

# --- 2. Private local configuration --------------------------------------------
install -dm700 "$CONFIG_DIR"
printf '%s' "$TOKEN" > "$CONFIG_DIR/token"
printf '%s' "$URL" > "$CONFIG_DIR/url"
printf '%s' "$SCOPE" > "$CONFIG_DIR/scope"
chmod 600 "$CONFIG_DIR"/{token,url,scope}

if [[ ! -f "$CONFIG_DIR/machines" ]]; then
  hostname -s | tr 'A-Z' 'a-z' > "$CONFIG_DIR/machines"
fi
chmod 600 "$CONFIG_DIR/machines"
echo "✓ private config written to ~/.config/elder-brain/"

# --- 3. Connectivity and authentication ----------------------------------------
HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 6 \
  -H "Authorization: Bearer $TOKEN" "$URL/web/" || true)
if [[ "$HTTP_CODE" == 401 ]]; then
  echo "✗ token rejected (HTTP 401); verify it and run the installer again." >&2
  exit 1
fi
if [[ "$HTTP_CODE" == 000 ]]; then
  echo "✗ server is unreachable; verify the private network and URL." >&2
  exit 1
fi
echo "✓ server responded (HTTP $HTTP_CODE)"

# --- 4. Claude Code hooks (optional) -------------------------------------------
HOOKS_DIR="$HOME/.local/share/ai-memory/hooks/claude-code"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [[ -d "$HOOKS_DIR" && -f "$CLAUDE_SETTINGS" ]]; then
  read -rp "Point detected Claude Code ai-memory hooks to Elder Brain? [y/N] " REPLY
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    backup="$CLAUDE_SETTINGS.bak.$(date +%s)"
    cp -a "$CLAUDE_SETTINGS" "$backup"
    TOKEN_PATH="$CONFIG_DIR/token" python3 - "$URL" "$CLAUDE_SETTINGS" <<'PYEOF'
import json
import os
import shlex
import stat
import sys
from pathlib import Path

url = sys.argv[1]
settings_path = Path(sys.argv[2])
token_path = os.environ["TOKEN_PATH"]
data = json.loads(settings_path.read_text())
replacement = (
    f"AI_MEMORY_HOOK_URL={shlex.quote(url)} "
    f"AI_MEMORY_AUTH_TOKEN=$(cat {shlex.quote(token_path)})"
)
changed = 0
for group in data.get("hooks", {}).values():
    for entry in group:
        for hook in entry.get("hooks", []):
            command = hook.get("command", "")
            marker = "AI_MEMORY_HOOK_URL=http://127.0.0.1:49374"
            if marker in command:
                hook["command"] = command.replace(marker, replacement)
                changed += 1

temporary = settings_path.with_suffix(settings_path.suffix + ".tmp")
temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
os.chmod(temporary, stat.S_IMODE(settings_path.stat().st_mode))
os.replace(temporary, settings_path)
print(f"✓ updated {changed} Claude Code hooks (backup: {settings_path.name}.bak.*)")
PYEOF
  fi
else
  echo "– Claude Code ai-memory hooks not detected; skipping (see docs/install.md)."
fi

# --- 5. Hourly machine heartbeat (optional) ------------------------------------
read -rp "Enable the hourly machine heartbeat for the status panel? [y/N] " REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  install -Dm755 "$SCRIPT_DIR/elder-brain-status" "$HOME/.local/bin/elder-brain-status"
  install -dm700 "$HOME/.config/systemd/user"

  cat > "$HOME/.config/systemd/user/elder-brain-heartbeat.service" <<'EOF'
[Unit]
Description=Elder Brain heartbeat

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 %h/.local/bin/elder-brain-status --heartbeat
EOF

  cat > "$HOME/.config/systemd/user/elder-brain-heartbeat.timer" <<'EOF'
[Unit]
Description=Hourly Elder Brain heartbeat

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now elder-brain-heartbeat.timer
  systemctl --user start elder-brain-heartbeat.service
  echo "✓ hourly heartbeat enabled"
fi

# --- 6. Omarchy status panel (optional) ----------------------------------------
if [[ -d "$HOME/.config/omarchy" ]] && command -v omarchy >/dev/null 2>&1; then
  read -rp "Install and enable the Omarchy bar panel? [y/N] " REPLY
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    USERNAME=$(id -un)
    PLUGIN_ID="${USERNAME}.elder-brain"
    DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

    if [[ -e "$DEST" ]]; then
      mv "$DEST" "$DEST.bak.$(date +%s)"
    fi
    cp -a "$SCRIPT_DIR/../omarchy-plugin" "$DEST"
    sed -i \
      -e "s/\"id\": \"community.elder-brain\"/\"id\": \"$PLUGIN_ID\"/" \
      "$DEST/manifest.json"
    sed -i \
      -e "s/moduleName: \"community.elder-brain\"/moduleName: \"$PLUGIN_ID\"/" \
      -e "s/ipcTarget: \"community.elder-brain\"/ipcTarget: \"$PLUGIN_ID\"/" \
      "$DEST/Panel.qml"

    omarchy plugin validate "$DEST"
    omarchy-shell shell rescanPlugins >/dev/null
    omarchy plugin enable "$PLUGIN_ID" --section right
    echo "✓ Omarchy panel installed and enabled as $PLUGIN_ID"
  fi
fi

echo
echo "🧠 setup complete. Verify with: elder-brain-status"
