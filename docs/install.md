# Guia de instalação — Elder Brain

## 0. Pré-requisitos

**Servidor:** Linux + Docker + Docker Compose. Recomendado: host sempre ligado
(VPS) numa rede overlay privada (Tailscale é o caminho testado).

**Clientes:** qualquer máquina que alcance o servidor pela rede privada.

## 1. Servidor

```bash
mkdir -p ~/elder-brain && cd ~/elder-brain
cp /caminho/do/repo/deploy/docker-compose.yml .
cp /caminho/do/repo/deploy/.env.example .env
$EDITOR .env        # AI_MEMORY_AUTH_TOKEN (openssl rand -hex 32), BIND_IP, GEMINI_API_KEY
docker compose up -d
```

Validação:

```bash
curl -i http://<BIND_IP>:49374/web/                                    # esperado: 401
curl -i -H "Authorization: Bearer $TOKEN" http://<BIND_IP>:49374/web/  # esperado: 308/200
```

**Backup:** os dados vivem em `./data` (SQLite + páginas Markdown). Inclua esse
diretório no backup do host. Restore = recolocar o diretório e subir o container.

## 2. Cliente — configuração base (toda máquina)

```bash
install -Dm700 -d ~/.config/elder-brain
printf '%s' '<TOKEN>'        > ~/.config/elder-brain/token     # chmod 600
printf '%s' 'http://<IP>:49374' > ~/.config/elder-brain/url
printf '%s\n' 'desktop' 'laptop' > ~/.config/elder-brain/machines   # nomes da colônia
chmod 600 ~/.config/elder-brain/{token,url,machines}
```

## 3. Cliente — Claude Code

Pré-requisito: hooks do ai-memory instalados
(`ai-memory install-hooks --apply` ou equivalente — eles ficam em
`~/.local/share/ai-memory/hooks/claude-code/`).

No `~/.claude/settings.json`, cada hook ai-memory recebe URL + token:

```json
{
  "type": "command",
  "command": "AI_MEMORY_HOOK_URL=http://<IP>:49374 AI_MEMORY_AUTH_TOKEN=$(cat $HOME/.config/elder-brain/token) $HOME/.local/share/ai-memory/hooks/claude-code/session-start.sh"
}
```

Teste:

```bash
echo '{"session_id":"test","cwd":"'$HOME'"}' | \
  AI_MEMORY_HOOK_URL=http://<IP>:49374 \
  AI_MEMORY_AUTH_TOKEN=$(cat ~/.config/elder-brain/token) \
  sh ~/.local/share/ai-memory/hooks/claude-code/session-start.sh
# '{}' = ok · "auth required" = token/env errado
```

## 4. Cliente — Pi

A extensão `elder-brain` (tools `elder_brain_recall`, `elder_brain_recent`,
`elder_brain_status`) vive no ecossistema Pi; com o token configurado (passo 2)
ela funciona sem mais nada. Variáveis aceitas: `ELDER_BRAIN_URL`,
`ELDER_BRAIN_TOKEN` (ou os arquivos do passo 2).

## 5. Cliente — heartbeat (aparecer como "máquina viva")

```bash
install -Dm755 scripts/elder-brain-status ~/.local/bin/elder-brain-status

cat > ~/.config/systemd/user/elder-brain-heartbeat.service <<'EOF'
[Unit]
Description=Elder Brain heartbeat
[Service]
Type=oneshot
ExecStart=/usr/bin/python3 %h/.local/bin/elder-brain-status --heartbeat
EOF

cat > ~/.config/systemd/user/elder-brain-heartbeat.timer <<'EOF'
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
```

## 6. Cliente — painel Omarchy (opcional)

```bash
cp -r omarchy-plugin ~/.config/omarchy/plugins/<seu-usuario>.elder-brain
# ajuste o "id" no manifest.json e adicione {"id": "<seu-usuario>.elder-brain"}
# à seção desejada de ~/.config/omarchy/shell.json — hot-reload automático
```

O painel mostra: ícone vivo/morto · latência · contagens · máquinas conectadas
(via heartbeat) · atividade recente.

## 7. Rollback

Parar de usar o cérebro central = apontar os hooks de volta pra uma instância
local (`http://127.0.0.1:49374`) ou remover as variáveis. Nenhum dado local é
apagado no processo.
