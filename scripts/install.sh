#!/usr/bin/env bash
# install.sh — conecta esta máquina a um Elder Brain.
# Interativo. Não grava nada fora de ~/.config/elder-brain e systemd user.
set -euo pipefail

echo "🧠 Elder Brain — setup de máquina cliente"
echo

# --- 1. coleta -----------------------------------------------------------------
read -rp "URL do servidor (ex.: http://100.x.y.z:49374): " URL
URL="${URL%/}"
read -rsp "Token (Bearer): " TOKEN; echo
[ -n "$URL" ] && [ -n "$TOKEN" ] || { echo "URL e token são obrigatórios."; exit 1; }

# --- 2. config base -------------------------------------------------------------
install -dm700 "$HOME/.config/elder-brain"
printf '%s' "$TOKEN" > "$HOME/.config/elder-brain/token"
printf '%s' "$URL"   > "$HOME/.config/elder-brain/url"
chmod 600 "$HOME/.config/elder-brain"/{token,url}
[ -f "$HOME/.config/elder-brain/machines" ] || hostname -s | tr 'A-Z' 'a-z' > "$HOME/.config/elder-brain/machines"
echo "✓ config em ~/.config/elder-brain/"

# --- 3. teste -------------------------------------------------------------------
CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 6 \
  -H "Authorization: Bearer $TOKEN" "$URL/web/" || true)
if [ "$CODE" = "401" ]; then echo "✗ token recusado (401). Confira e rode de novo."; exit 1; fi
[ "$CODE" = "000" ] && { echo "✗ servidor inalcançável. Está na rede privada?"; exit 1; }
echo "✓ servidor respondeu (HTTP $CODE)"

# --- 4. Claude Code (opcional) --------------------------------------------------
HOOKS_DIR="$HOME/.local/share/ai-memory/hooks/claude-code"
if [ -d "$HOOKS_DIR" ] && [ -f "$HOME/.claude/settings.json" ]; then
  read -rp "Apontar hooks do Claude Code pro Elder Brain? [s/N] " R
  if [ "$R" = "s" ] || [ "$R" = "S" ]; then
    cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak.$(date +%s)"
    TOKEN_PATH="$HOME/.config/elder-brain/token" \
    python3 - "$URL" <<'PYEOF'
import json, os, sys
url = sys.argv[1]
token_path = os.environ["TOKEN_PATH"]
p = os.path.expanduser("~/.claude/settings.json")
d = json.load(open(p))
n = 0
for group in d.get("hooks", {}).values():
    for entry in group:
        for h in entry.get("hooks", []):
            cmd = h.get("command", "")
            if "AI_MEMORY_HOOK_URL=http://127.0.0.1:49374" in cmd:
                h["command"] = cmd.replace(
                    "AI_MEMORY_HOOK_URL=http://127.0.0.1:49374",
                    f"AI_MEMORY_HOOK_URL={url} AI_MEMORY_AUTH_TOKEN=$(cat {token_path})")
                n += 1
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
print(f"✓ {n} hooks apontados (backup em settings.json.bak.*)")
PYEOF
  fi
else
  echo "– Claude Code com hooks ai-memory não detectado; pulando (veja docs/install.md §3)"
fi

# --- 5. heartbeat ---------------------------------------------------------------
read -rp "Ativar heartbeat horário (aparecer no painel de máquinas)? [s/N] " R
if [ "$R" = "s" ] || [ "$R" = "S" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  install -Dm755 "$SCRIPT_DIR/elder-brain-status" "$HOME/.local/bin/elder-brain-status"
  mkdir -p "$HOME/.config/systemd/user"
  cat > "$HOME/.config/systemd/user/elder-brain-heartbeat.service" <<EOF
[Unit]
Description=Elder Brain heartbeat
[Service]
Type=oneshot
ExecStart=/usr/bin/python3 %h/.local/bin/elder-brain-status --heartbeat
EOF
  cat > "$HOME/.config/systemd/user/elder-brain-heartbeat.timer" <<EOF
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
  echo "✓ heartbeat ativo"
fi

# --- 6. painel Omarchy (opcional) ----------------------------------------------
if [ -d "$HOME/.config/omarchy" ]; then
  read -rp "Instalar widget da barra Omarchy? [s/N] " R
  if [ "$R" = "s" ] || [ "$R" = "S" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    USERNAME="$(id -un)"
    DEST="$HOME/.config/omarchy/plugins/${USERNAME}.elder-brain"
    cp -r "$SCRIPT_DIR/../omarchy-plugin" "$DEST"
    sed -i "s/\"id\": \"gatsby.elder-brain\"/\"id\": \"${USERNAME}.elder-brain\"/" "$DEST/manifest.json"
    sed -i "s/moduleName: \"gatsby.elder-brain\"/moduleName: \"${USERNAME}.elder-brain\"/; s/ipcTarget: \"gatsby.elder-brain\"/ipcTarget: \"${USERNAME}.elder-brain\"/" "$DEST/Panel.qml"
    echo "✓ plugin em $DEST"
    echo "  Agora adicione {\"id\": \"${USERNAME}.elder-brain\"} à seção desejada de ~/.config/omarchy/shell.json"
  fi
fi

echo
echo "🧠 pronto. Teste: elder-brain-status"
