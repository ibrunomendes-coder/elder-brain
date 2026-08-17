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
  moduleName: "community.elder-brain"
  ipcTarget: "community.elder-brain"
  manageIpc: false

  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    return url.replace(/^file:\/\//, "").replace(/\/$/, "")
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) brain.refresh()

  // Application-wide fallback: closes even if focus is trapped inside the
  // Flickable or another panel instance in a multi-monitor setup.
  Shortcut {
    enabled: root.opened
    sequence: "Escape"
    context: Qt.ApplicationShortcut
    onActivated: root.close()
  }

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
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          panelFlick.contentY = Math.max(0, Math.min(
            panelFlick.contentY + dy * Style.space(56),
            Math.max(0, panelFlick.contentHeight - panelFlick.height)
          ))
      }
      onActivateRequested: brain.refresh()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") brain.refresh() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(14)

          // ---------- Identity and status ----------
          PanelHero {
            width: parent.width
            title: "Elder Brain"
            meta: brain.status.alive
              ? "COLLECTIVE MEMORY · " + (brain.status.latency_ms || "—") + " MS"
              : "COLLECTIVE MEMORY UNAVAILABLE"
            detail: brain.status.alive ? "ONLINE" : "OFFLINE"
            foreground: brain.status.alive ? root.foreground : root.urgent
            fontFamily: root.fontFamily
            iconComponent: Component {
              ElderBrainIcon {
                iconSize: Style.font.display
                color: brain.status.alive ? root.foreground : root.urgent
              }
            }
          }

          // ---------- Primary metrics ----------
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            MetricCard {
              Layout.fillWidth: true
              label: "PAGES"
              value: Model.formatCount((brain.status.counts || {}).pages_latest)
            }
            MetricCard {
              Layout.fillWidth: true
              label: "SESSIONS"
              value: Model.formatCount((brain.status.counts || {}).sessions)
            }
            MetricCard {
              Layout.fillWidth: true
              label: "OBSERVATIONS"
              value: Model.formatCount((brain.status.counts || {}).observations)
            }
          }

          // ---------- Connection health ----------
          BorderSurface {
            width: parent.width
            implicitHeight: healthRow.implicitHeight + Style.space(16)
            color: brain.status.alive
              ? root.alpha(root.foreground, 0.045)
              : root.alpha(root.urgent, 0.08)
            borderSpec: Border.flat(
              brain.status.alive ? root.alpha(root.foreground, 0.13) : root.alpha(root.urgent, 0.30),
              1
            )
            radius: Style.cornerRadius

            RowLayout {
              id: healthRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(8)

              Text {
                text: brain.status.alive ? "●  SERVER ONLINE" : "○  NO RESPONSE"
                color: brain.status.alive ? root.foreground : root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Item { Layout.fillWidth: true; height: 1 }

              Text {
                text: Model.checkedAt(brain.status.ts)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          BorderSurface {
            visible: brain.lastError !== ""
            width: parent.width
            implicitHeight: errorText.implicitHeight + Style.space(20)
            color: root.alpha(root.urgent, 0.08)
            borderSpec: Border.flat(root.alpha(root.urgent, 0.30), 1)
            radius: Style.cornerRadius

            Text {
              id: errorText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              text: brain.lastError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }

          // ---------- Machines ----------
          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            RowLayout {
              width: parent.width

              PanelSectionHeader {
                text: "MACHINES"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Item { Layout.fillWidth: true; height: 1 }

              Text {
                text: String((brain.status.machines || []).length)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Text {
              visible: (brain.status.machines || []).length === 0
              width: parent.width
              text: "No machines registered."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(8)
              bottomPadding: Style.space(8)
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: brain.status.machines || []
                MachineRow {
                  required property var modelData
                  width: parent.width
                  machine: modelData
                }
              }
            }
          }

          // ---------- Recent activity ----------
          PanelSeparator {
            foreground: root.foreground
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            RowLayout {
              width: parent.width

              PanelSectionHeader {
                text: "RECENT ACTIVITY"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Item { Layout.fillWidth: true; height: 1 }

              Text {
                text: String((brain.status.recent || []).length)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            Text {
              visible: (brain.status.recent || []).length === 0
              width: parent.width
              text: "No recent activity."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(8)
              bottomPadding: Style.space(8)
            }

            Column {
              width: parent.width

              Repeater {
                model: brain.status.recent || []
                ActivityRow {
                  required property var modelData
                  required property int index
                  width: parent.width
                  item: modelData
                  rowIndex: index
                  showDivider: index < (brain.status.recent || []).length - 1
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          Text {
            width: parent.width
            text: "R  REFRESH    ·    ESC  CLOSE"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.8
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }

  component MetricCard: BorderSurface {
    property string label: ""
    property string value: "0"

    implicitHeight: metricLabels.implicitHeight + Style.space(18)
    color: root.alpha(root.foreground, 0.045)
    borderSpec: Border.flat(root.alpha(root.foreground, 0.13), 1)
    radius: Style.cornerRadius

    Column {
      id: metricLabels
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: value
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 0.8
      }
    }
  }

  component MachineRow: BorderSurface {
    property var machine: ({})

    implicitHeight: Math.max(machineLabels.implicitHeight, machineAge.implicitHeight) + Style.space(16)
    color: root.alpha(root.foreground, 0.035)
    borderSpec: Border.flat(root.alpha(root.foreground, 0.10), 1)
    radius: Style.cornerRadius

    Rectangle {
      id: machineDot
      width: Style.space(7)
      height: width
      radius: width / 2
      color: machine && machine.alive ? root.foreground : root.dim
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      id: machineLabels
      anchors.left: machineDot.right
      anchors.leftMargin: Style.space(9)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      Text {
        text: machine ? String(machine.name || "") : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        text: Model.machineState(machine)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Text {
      id: machineAge
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: Model.machineAge(machine)
      color: machine && machine.alive ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  component ActivityRow: Item {
    property var item: ({})
    property int rowIndex: 0
    property bool showDivider: false

    implicitHeight: activityTitle.implicitHeight + Style.space(14)

    Text {
      id: activityIndex
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(26)
      text: ("0" + (rowIndex + 1)).slice(-2)
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      id: activityTitle
      anchors.left: activityIndex.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: item ? String(item.title || item.path || "") : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      maximumLineCount: 1
    }

    Rectangle {
      visible: showDivider
      anchors.left: activityTitle.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 1
      color: root.alpha(root.foreground, 0.08)
    }
  }
}
