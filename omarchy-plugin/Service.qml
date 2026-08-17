import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Owns the plugin's data. Shells out to status.py (que detém o token e fala
// MCP com o Elder Brain) e mantém o painel livre de credenciais.
Item {
  id: root

  property var settings: ({})
  property string pluginDir: ""

  property var status: Model.defaultStatus()
  property bool refreshing: false
  property string lastError: ""

  readonly property int refreshIntervalSec: {
    var n = parseInt(String(settings ? settings["refreshIntervalSec"] : 120), 10)
    return isFinite(n) ? Math.max(60, Math.min(900, n)) : 120
  }

  property string _output: ""

  function refresh() {
    if (statusProcess.running || pluginDir === "") return
    _output = ""
    statusProcess.exec({ command: ["python3", pluginDir + "/status.py"] })
    refreshing = true
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    stdout: SplitParser {
      onRead: function(data) { root._output += data }
    }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode === 0 && root._output.trim() !== "") {
        root.status = Model.parseStatus(root._output)
        root.lastError = root.status.alive ? "" : (root.status.error || "Elder Brain sem resposta")
      } else {
        root.status = Model.defaultStatus()
        root.lastError = "status.py falhou (exit " + exitCode + ")"
      }
    }
  }
}
