# Segurança — Elder Brain

## Regras de ouro

1. **Nunca exponha a porta 49374 na internet pública.** O servidor fala HTTP
   puro. O desenho assume rede overlay privada (Tailscale, WireGuard, LAN).
2. **Token é obrigatório fora do loopback** — o ai-memory recusa subir sem
   `AI_MEMORY_AUTH_TOKEN` quando o bind não é loopback. Não tente contornar
   com `--allow-insecure-no-auth`.
3. **Token por máquina em `~/.config/elder-brain/token` (600).** Credencial se
   referencia (cofre), nunca se versiona.

## Se precisar de exposição pública

Coloque um proxy reverso com TLS na frente (Caddy/Traefik/Nginx) e mantenha o
Bearer. Sem TLS, o token viaja em claro — não faça isso fora de rede privada.

## O que circula pela rede

- Hooks de sessão: cwd, nome de evento, IDs de sessão, e o conteúdo das
  observações que o agente registra (trechos de trabalho).
- **Não devem** circular segredos: oriente seus agentes (AGENTS.md) a nunca
  colar credenciais em contexto de sessão — mesma regra de qualquer transcript.

## Superfície de ataque

- Quem tem o token lê e escreve a memória inteira. Trate-o como senha mestra.
- `AI_MEMORY_ALLOWED_HOSTS` limita o header Host aceito — mantenha a lista curta.
- Revogação: troque o token no `.env` do servidor (`docker compose up -d`) e
  distribua o novo. Tokens antigos morrem na hora.
