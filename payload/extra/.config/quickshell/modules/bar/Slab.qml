import QtQuick
import QtQuick.Shapes

import "../../theme" as SharedTheme
// Slanted "/" parallelogram that wraps whatever you put inside it.
Item {
    id: root

    property color fill: SharedTheme.Theme.deep
    property color edge: SharedTheme.Theme.cyan
    property bool underline: false
    property real skew: 10
    property real pad: 14
    property alias spacing: row.spacing
    default property alias content: row.data
    signal clicked()

    implicitHeight: 30
    implicitWidth: row.implicitWidth + pad * 2 + skew

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.fill
            strokeColor: "transparent"
            startX: root.skew; startY: 0
            PathLine { x: root.width;              y: 0 }
            PathLine { x: root.width - root.skew;  y: root.height }
            PathLine { x: 0;                       y: root.height }
            PathLine { x: root.skew;               y: 0 }
        }
    }

    Rectangle {
        visible: root.underline
        color: root.edge
        height: 2
        width: root.width - root.skew
        y: root.height - 2
    }

    // Declared before the content so child mouse areas win clicks
    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }

    Row {
        id: row
        x: root.pad + root.skew / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
    }
}
