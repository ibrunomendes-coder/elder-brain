# Elder Brain 🧠

**Memória coletiva para agentes de IA** — um servidor central, agnóstico de
agente e self-hosted, do qual qualquer agente em qualquer máquina lê e escreve
experiências de sessão. O que um Claude aprendeu no desktop, o Pi no laptop já
sabe. Um organismo vivo de memória, seu, fora de qualquer vendor.

Construído sobre o [`akitaonrails/ai-memory`](https://github.com/akitaonrails/ai-memory)
(MCP-over-HTTP). Este repositório é a **receita completa**: servidor Docker,
integrações por agente, heartbeat de máquinas e painel de status para Omarchy.

## Por quê

Agentes de IA acumulam experiência por sessão — decisões, correções, contexto.
Por padrão essa memória morre na máquina onde nasceu. O Elder Brain centraliza:

```
laptop ──┐
desktop ─┼─→  elder-brain (sua VPS, rede privada)  ←── qualquer máquina futura
CI ──────┘      1 token Bearer + 1 URL = mesma memória viva em todos
```

- **Agnóstico**: fala MCP-over-HTTP — Claude Code, Pi, Codex, scripts, qualquer cliente MCP
- **Self-hosted**: um container Docker; dados em SQLite + Markdown, seus
- **Seguro por desenho**: bind em rede privada (tailnet/LAN) + token obrigatório
- **Observável**: painel de barra mostra saúde, latência e máquinas conectadas

## Quickstart

### 1. Servidor (qualquer host Linux com Docker)

```bash
cp deploy/.env.example deploy/.env   # preencha: token, BIND_IP, GEMINI_API_KEY
cd deploy && docker compose up -d

# valide: sem token deve dar 401, com token deve abrir
curl -i http://<BIND_IP>:49374/web/
curl -i -H "Authorization: Bearer <TOKEN>" http://<BIND_IP>:49374/web/
```

> ⚠️ Publique **somente em rede privada** (Tailscale, VPN, LAN). Para exposição
> pública, coloque atrás de proxy com TLS — veja `docs/security.md`.

### 2. Cada máquina cliente

```bash
./scripts/install.sh
# interativo: pede URL + token, configura hooks do Claude Code,
# heartbeat e (opcional) o painel Omarchy
```

Ou manualmente — guia completo em **[docs/install.md](docs/install.md)**.

### 3. Verifique

```bash
elder-brain-status
# {"ok": true, "alive": true, "latency_ms": 34, "counts": {...}, "machines": [...]}
```

## Componentes

| Pasta | O que é |
|---|---|
| `deploy/` | Docker Compose do servidor |
| `scripts/elder-brain-status` | CLI de status (stdlib Python): saúde, contagens, máquinas, atividade recente |
| `scripts/install.sh` | Instalador interativo de máquina cliente |
| `omarchy-plugin/` | Widget de barra para [Omarchy](https://omarchy.org): ícone vivo/morto, latência, máquinas conectadas, atividade recente |
| `docs/` | Guias: instalação detalhada, segurança, como funciona |

## Como os agentes se conectam

| Agente | Integração |
|---|---|
| **Claude Code** | Hooks de lifecycle (`session-start`, `post-tool-use`, `pre-compact`…) apontados pro servidor via `AI_MEMORY_HOOK_URL` + `AI_MEMORY_AUTH_TOKEN` |
| **Pi** | Extensão com tools de recall/recent/status (MCP-over-HTTP) |
| **Qualquer MCP client** | `POST /mcp` com `Authorization: Bearer <token>` |

## Modelo de segurança

- Servidor **recusa** bind não-loopback sem `AI_MEMORY_AUTH_TOKEN` (guarda nativa do ai-memory)
- Token por máquina em `~/.config/elder-brain/token` (chmod 600) — nunca em repo
- Tráfego dentro da sua overlay network (Tailscale recomendada)
- Este repositório não contém nenhum dado, IP ou credencial real — configure via `.env`

## Licença

MIT — veja [LICENSE](LICENSE). O servidor subjacente
[`ai-memory`](https://github.com/akitaonrails/ai-memory) é de AkitaOnRails e tem
licença própria.
