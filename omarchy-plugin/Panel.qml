import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "gatsby.elder-brain"
  ipcTarget: "gatsby.elder-brain"
  manageIpc: false

  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    return url.replace(/^file:\/\//, "").replace(/\/$/, "")
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) brain.refresh()

  Service {
    id: brain
    settings: root.settings
    pluginDir: root.pluginDir
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { brain.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      ElderBrainIcon {
        iconSize: Style.font.icon
        color: brain.status.alive ? root.foreground : root.dim
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) brain.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Elder Brain"
          meta: Model.summary(brain.status)
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            ElderBrainIcon {
              iconSize: Style.font.display
              color: brain.status.alive ? root.foreground : root.urgent
            }
          }
        }

        Text {
          visible: brain.lastError !== ""
          width: parent.width
          text: brain.lastError
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        // ---- Latência + última checagem ----
        Text {
          visible: brain.status.alive
          width: parent.width
          text: "Latência: " + (brain.status.latency_ms || "?") + " ms · checado " + String(brain.status.ts || "").replace("T", " ").replace("+00:00", " UTC")
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        // ---- Máquinas da colônia ----
        Text {
          width: parent.width
          text: "MÁQUINAS"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1.2
        }

        Repeater {
          model: brain.status.machines || []
          Text {
            required property var modelData
            width: parent.width
            text: (modelData.alive ? "● " : "○ ") + Model.machineLine(modelData)
            color: modelData.alive ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }

        // ---- Atividade recente ----
        Text {
          width: parent.width
          text: "ATIVIDADE RECENTE"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.letterSpacing: 1.2
        }

        Repeater {
          model: brain.status.recent || []
          Text {
            required property var modelData
            width: parent.width
            text: "· " + (modelData.title || modelData.path)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            maximumLineCount: 1
          }
        }
      }
    }
  }
}
