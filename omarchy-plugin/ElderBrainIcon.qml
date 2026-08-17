import QtQuick
import QtQuick.Shapes
import qs.Commons

// Illithid mask inside a circular medallion, shared by the bar and PanelHero.
// Diagonal negative-space eyes and four tentacles preserve the Mind Flayer
// silhouette at very small sizes.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  readonly property real s: Math.min(width, height)
  readonly property real originX: (width - s) / 2
  readonly property real originY: (height - s) / 2

  // Keep the same outer ring at every size for a consistent identity.
  Shape {
    x: root.originX
    y: root.originY
    width: 100
    height: 100
    scale: root.s / 100
    transformOrigin: Item.TopLeft

    antialiasing: true
    layer.enabled: true
    layer.samples: 4
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: 6

      PathSvg {
        path: "M 50 14 C 69.9 14 86 30.1 86 50 C 86 69.9 69.9 86 50 86 " +
              "C 30.1 86 14 69.9 14 50 C 14 30.1 30.1 14 50 14 Z"
      }
    }
  }

  IllithidGlyph {
    x: root.originX + root.s * 0.22
    y: root.originY + root.s * 0.22
    scale: root.s * 0.56 / 100
    transformOrigin: Item.TopLeft
    glyphColor: root.color
  }

  component IllithidGlyph: Shape {
    property color glyphColor: root.color

    width: 100
    height: 100
    antialiasing: true
    layer.enabled: true
    layer.samples: 4
    preferredRendererType: Shape.CurveRenderer

    // Four filled tentacles: two curved outer arms and two inner arms.
    ShapePath {
      fillColor: glyphColor
      strokeWidth: 0

      PathSvg {
        path: "M 38 43 C 29 49 17 55 11 66 C 5 77 8 90 18 94 " +
              "C 24 97 31 93 31 87 C 25 90 20 88 19 83 " +
              "C 17 75 25 68 40 61 Z " +
              "M 62 43 C 71 49 83 55 89 66 C 95 77 92 90 82 94 " +
              "C 76 97 69 93 69 87 C 75 90 80 88 81 83 " +
              "C 83 75 75 68 60 61 Z " +
              "M 44 49 C 39 62 37 78 34 91 C 32 97 39 99 43 94 " +
              "C 47 82 48 67 49 55 Z " +
              "M 56 49 C 61 62 63 78 66 91 C 68 97 61 99 57 94 " +
              "C 53 82 52 67 51 55 Z"
      }
    }

    // Tall skull with sharp eyes cut out through the odd-even fill rule.
    ShapePath {
      fillColor: glyphColor
      strokeWidth: 0
      fillRule: ShapePath.OddEvenFill

      PathSvg {
        path: "M 50 3 C 63 3 72 10 74 21 C 76 32 71 45 62 54 " +
              "L 50 65 L 38 54 C 29 45 24 32 26 21 C 28 10 37 3 50 3 Z " +
              "M 32 29 L 47 33 L 44 40 L 31 35 Z " +
              "M 68 29 L 53 33 L 56 40 L 69 35 Z"
      }
    }
  }
}
