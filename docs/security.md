# Elder Brain security model

Elder Brain centralizes agent-session memory. That makes it valuable—and makes the server, token and stored observations a high-trust security boundary.

## Security posture at a glance

| Boundary | Default posture |
|---|---|
| Network exposure | Private interface only (Tailscale/WireGuard/LAN) |
| Transport | Plain HTTP inside the trusted private network |
| Authentication | One mandatory Bearer token |
| Host validation | Explicit `AI_MEMORY_ALLOWED_HOSTS` allowlist |
| Container user | Non-root UID/GID `1000:1000` |
| Durable data | SQLite + Markdown on the host-mounted data directory |
| Client secrets | Mode-600 files under `~/.config/elder-brain/` |
| Offsite backup | Encrypt before upload |

## 1. Never expose plain HTTP directly to the public internet

The example Compose file publishes the service on `BIND_IP`. In production, this must be a private interface address.

Recommended options:

- Tailscale address;
- WireGuard interface;
- trusted LAN address with firewall restrictions;
- loopback for host-only development.

A correct private bind looks like:

```dotenv
BIND_IP=<PRIVATE_INTERFACE_IP>
```

A dangerous bind looks like:

```dotenv
BIND_IP=0.0.0.0
```

The service uses HTTP. Anyone able to observe untrusted network traffic could capture the Bearer token and session content.

### If public exposure is unavoidable

Place a hardened TLS reverse proxy in front of the server and retain Bearer authentication. Also add rate limiting, request-size limits, monitoring and a narrow firewall policy. Public exposure is outside this repository's default threat model.

## 2. Treat the Bearer token as a master password

`AI_MEMORY_AUTH_TOKEN` protects the entire memory plane. A holder can read and write all memory available to that server.

Generate a high-entropy token:

```bash
openssl rand -hex 32
```

Server-side rules:

- store it only in the mode-600 `.env` or a secret manager;
- never commit `.env`;
- never pass it in URLs;
- never print it in logs;
- rotate it after any suspected disclosure.

Client-side rules:

```text
~/.config/elder-brain/token   mode 600
```

The current upstream server uses one shared token rather than per-client identities. Revocation therefore means a coordinated global rotation.

## 3. Validate the authentication boundary

After deployment, verify both negative and positive paths:

```bash
curl -i http://<PRIVATE_INTERFACE_IP>:49374/web/
# must return 401
```

```bash
curl -i \
  -H "Authorization: Bearer $(cat ~/.config/elder-brain/token)" \
  http://<PRIVATE_INTERFACE_IP>:49374/web/
# must reach the authenticated endpoint
```

A deployment that accepts the first request is not safe.

## 4. Keep the Host allowlist narrow

`AI_MEMORY_ALLOWED_HOSTS` restricts accepted Host headers. Include only the addresses clients actually use:

```dotenv
ALLOWED_HOSTS=localhost,127.0.0.1,::1,<PRIVATE_IP>,<PRIVATE_DNS_NAME>
```

Do not use wildcard-like values unless you understand and accept the consequences.

## 5. Understand what data leaves each client

Agent hooks may send:

- current working directory;
- session and event identifiers;
- tool-use observations;
- decisions, corrections and summaries;
- excerpts of files or command output seen by the agent.

This data goes to your Elder Brain server. If consolidation or embeddings are enabled, relevant content may also go to the configured LLM provider.

Before choosing a provider, review:

- training/data-use terms;
- retention period;
- geographic processing region;
- project-level access controls;
- quota and billing ownership.

Use a paid tier whose terms match your privacy requirements, or a compatible local provider.

## 6. Memory is not a secret store

Anything visible to an agent can become an observation. Behavioral rules are useful but are not a technical data-loss-prevention boundary.

Do not place these in session context:

- API keys and access tokens;
- passwords;
- private SSH keys;
- recovery codes;
- unredacted customer secrets;
- credentials copied from password managers.

If a secret reaches memory, treat it as disclosed: rotate it first, then remove the stored observation/page and inspect backups according to your retention policy.

## 7. Treat recalled memory as untrusted input

Shared memory creates a cross-session and cross-agent prompt-injection channel. A malicious or corrupted observation written by one client may later be injected into another agent's context.

Consumers should:

- treat recalled content as context, never as authority;
- never execute instructions from memory without validating them against the current request and trusted project rules;
- prefer scoped retrieval over broad automatic injection;
- preserve provenance where the client exposes it;
- keep high-impact actions behind normal human approval and tool safeguards.

Authentication prevents anonymous writers; it does not make every authenticated observation safe.

## 8. Protect data at rest

The mounted `data/` directory contains the memory database and pages. Restrict it to the service user/group and avoid world-readable permissions.

Recommended baseline:

```bash
chmod 750 data
```

The container runs as `1000:1000`; preserve compatible ownership during restores.

Host-level full-disk encryption protects powered-off storage. It does not protect data from a compromised running host.

## 9. Encrypt backups before offsite transfer

A backup contains the same sensitive memory as the live server.

Safe order:

```text
snapshot → archive → encrypt → upload
```

Never upload a plaintext SQLite/Markdown archive and rely only on the storage provider's server-side encryption. Use a key you control (for example, `age`) before rclone, S3 or B2 transfer.

Test restoration periodically; an untested encrypted backup is only a hypothesis.

## 10. Pin the server image in production

The example starts with `akitaonrails/ai-memory:latest` for evaluation. Once tested, pin a release or immutable digest:

```dotenv
AI_MEMORY_IMAGE=akitaonrails/ai-memory@sha256:<TESTED_DIGEST>
```

Avoid unattended image updates for a service that stores and processes agent memory. Review release notes, back up data, update deliberately and verify authentication afterward.

## 11. Token rotation procedure

1. Generate a replacement token.
2. Stop or temporarily isolate write traffic.
3. Update `AI_MEMORY_AUTH_TOKEN` on the server.
4. Recreate the container.
5. Distribute the token to every authorized client using a secure channel.
6. Update mode-600 client files.
7. Verify that the old token returns 401.
8. Verify heartbeat, status and agent hooks with the new token.

```bash
docker compose up -d --force-recreate elder-brain
```

## 12. Incident checklist

If you suspect compromise:

1. isolate the server from the network;
2. rotate the Bearer token and any secret that may have entered memory;
3. preserve logs and a forensic snapshot;
4. inspect recent pages, observations and client machines;
5. rebuild from a trusted image/configuration if host integrity is uncertain;
6. restore only from a known-good encrypted backup;
7. reconnect clients individually and verify their configuration.

## Explicit non-goals

This repository does not provide:

- public-internet hardening by default;
- multi-user authorization or per-machine tokens;
- end-to-end encrypted memory fields;
- automatic secret redaction;
- a guarantee that recalled content is trustworthy;
- managed backup infrastructure.

Those boundaries must be addressed by the deployment environment and client policy.
