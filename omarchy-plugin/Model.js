// Elder Brain — pure formatting helpers with no Qt dependencies.

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
    failed.error = "Unreadable response from status helper"
    return failed
  }
}

// Aggregated icon state: "down" | "ok".
function level(status) {
  if (!status || !status.alive) return "down"
  return "ok"
}

function summary(status) {
  if (!status || !status.alive) return "Elder Brain is not responding"
  var c = status.counts || {}
  return (c.pages_latest || 0) + " pages · " + (c.sessions || 0) + " sessions · " + (c.observations || 0) + " observations"
}

function formatCount(value) {
  var n = Number(value || 0)
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

function checkedAt(ts) {
  var value = String(ts || "")
  if (value.length < 19) return "WAITING FOR UPDATE"
  return "UPDATED " + value.slice(11, 19) + " UTC"
}

function machineState(m) {
  if (!m) return "Unknown state"
  if (m.alive) return "Connected to collective memory"
  if (m.last_seen) return "No recent signal"
  return "No heartbeat received yet"
}

function machineAge(m) {
  if (!m || !m.last_seen) return "NEVER SEEN"
  var minutes = Math.max(0, Math.round(Number(m.age_min || 0)))
  if (minutes < 1) return "NOW"
  if (minutes < 60) return minutes + " MIN AGO"
  var hours = Math.round(minutes / 60)
  return hours + (hours === 1 ? " HOUR AGO" : " HOURS AGO")
}

function machineLine(m) {
  if (!m) return ""
  if (m.alive) return m.name + " — alive (seen " + Math.round(m.age_min || 0) + " min ago)"
  if (m.last_seen) return m.name + " — no signal for " + Math.round(m.age_min || 0) + " min"
  return m.name + " — never seen"
}
