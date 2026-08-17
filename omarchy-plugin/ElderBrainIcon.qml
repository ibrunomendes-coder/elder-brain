import QtQuick
import qs.Commons

// Nerd Fonts Material Design `brain` (U+F09D1).
// A standard glyph stays legible in the bar's 16 px optical box and follows
// the same monochrome color contract as first-party Omarchy icons.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Text {
    anchors.fill: parent
    text: "󰧑"
    color: root.color
    font.family: "Symbols Nerd Font"
    font.pixelSize: root.iconSize * 1.08
    font.hintingPreference: Font.PreferFullHinting
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
  }
}
