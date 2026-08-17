import QtQuick
import QtQuick.Shapes
import qs.Commons

// A marca illithid: crânio em escudo com o queixo em ponta e quatro tentáculos
// abrindo em leque. Vetor monocromático em caixa 1:1, na convenção do
// TailscaleIcon e do DropboxIcon — herda a cor do tema e não traz asset.
//
// O símbolo de referência é entrelaçado (nós celtas nos tentáculos). Isso não
// sobrevive a um slot de 16px, então aqui fica a silhueta: o que identifica um
// mind flayer em tamanho pequeno é o crânio bulboso terminando em ponta somado
// ao leque de tentáculos, não o ornamento.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  // O BarIconButton estica o componente pro canvas óptico real (16px) via
  // Loader com anchors.fill — então o desenho usa o tamanho RENDERIZADO,
  // não a propriedade. Assim a proporção casa com os ícones nativos
  // (DropboxIcon desenha em função de root.width pelo mesmo motivo).
  readonly property real s: Math.min(width, height)
  readonly property real tentacleStroke: Math.max(1, s * 0.085)

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4
    preferredRendererType: Shape.CurveRenderer

    // Crânio: ombros largos no alto, lados retos convergindo para a ponta.
    ShapePath {
      fillColor: root.color
      strokeWidth: 0

      startX: root.s * 0.50
      startY: root.s * 0.05

      PathCubic {
        x: root.s * 0.81; y: root.s * 0.30
        control1X: root.s * 0.68; control1Y: root.s * 0.05
        control2X: root.s * 0.81; control2Y: root.s * 0.15
      }
      PathCubic {
        x: root.s * 0.50; y: root.s * 0.61
        control1X: root.s * 0.79; control1Y: root.s * 0.43
        control2X: root.s * 0.62; control2Y: root.s * 0.53
      }
      PathCubic {
        x: root.s * 0.19; y: root.s * 0.30
        control1X: root.s * 0.38; control1Y: root.s * 0.53
        control2X: root.s * 0.21; control2Y: root.s * 0.43
      }
      PathCubic {
        x: root.s * 0.50; y: root.s * 0.05
        control1X: root.s * 0.19; control1Y: root.s * 0.15
        control2X: root.s * 0.32; control2Y: root.s * 0.05
      }
    }

    // Tentáculos internos: curtos, saindo do queixo e abrindo pouco.
    Tentacle {
      x1: root.s * 0.44; y1: root.s * 0.57
      cx1: root.s * 0.42; cy1: root.s * 0.74
      cx2: root.s * 0.39; cy2: root.s * 0.85
      x2: root.s * 0.32; y2: root.s * 0.94
    }
    Tentacle {
      x1: root.s * 0.56; y1: root.s * 0.57
      cx1: root.s * 0.58; cy1: root.s * 0.74
      cx2: root.s * 0.61; cy2: root.s * 0.85
      x2: root.s * 0.68; y2: root.s * 0.94
    }

    // Tentáculos externos: saem mais alto, varrem para fora e recolhem na ponta.
    Tentacle {
      x1: root.s * 0.28; y1: root.s * 0.47
      cx1: root.s * 0.16; cy1: root.s * 0.62
      cx2: root.s * 0.06; cy2: root.s * 0.74
      x2: root.s * 0.14; y2: root.s * 0.90
    }
    Tentacle {
      x1: root.s * 0.72; y1: root.s * 0.47
      cx1: root.s * 0.84; cy1: root.s * 0.62
      cx2: root.s * 0.94; cy2: root.s * 0.74
      x2: root.s * 0.86; y2: root.s * 0.90
    }
  }

  component Tentacle: ShapePath {
    // ShapePath não é um Item: o PathCubic aninhado precisa do id, não de `parent`.
    id: tentacle

    property real x1: 0
    property real y1: 0
    property real cx1: 0
    property real cy1: 0
    property real cx2: 0
    property real cy2: 0
    property real x2: 0
    property real y2: 0

    fillColor: "transparent"
    strokeColor: root.color
    strokeWidth: root.tentacleStroke
    capStyle: ShapePath.RoundCap

    startX: tentacle.x1
    startY: tentacle.y1

    PathCubic {
      x: tentacle.x2; y: tentacle.y2
      control1X: tentacle.cx1; control1Y: tentacle.cy1
      control2X: tentacle.cx2; control2Y: tentacle.cy2
    }
  }
}
