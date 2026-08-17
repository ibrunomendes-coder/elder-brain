// Elder Brain — formatação pura (sem Qt), testável sob node.

function defaultStatus() {
  return {
    ok: true,
    alive: false,
    ts: "",
    latency_ms: null,
    counts: {},
    recent: [],
    machines: []
  }
}

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return defaultStatus()
  try {
    var parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object") return defaultStatus()
    return parsed
  } catch (e) {
    var failed = defaultStatus()
    failed.ok = false
    failed.error = "Resposta ilegível do helper"
    return failed
  }
}

// Estado agregado do ícone: "down" | "ok"
function level(status) {
  if (!status || !status.alive) return "down"
  return "ok"
}

function summary(status) {
  if (!status || !status.alive) return "Elder Brain sem resposta"
  var c = status.counts || {}
  return (c.pages_latest || 0) + " páginas · " + (c.sessions || 0) + " sessões · " + (c.observations || 0) + " observações"
}

function machineLine(m) {
  if (!m) return ""
  if (m.alive) return m.name + " — viva (vista há " + Math.round(m.age_min || 0) + " min)"
  if (m.last_seen) return m.name + " — sem sinal há " + Math.round(m.age_min || 0) + " min"
  return m.name + " — nunca vista"
}
