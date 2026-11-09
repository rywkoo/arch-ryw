import QtQuick

// Item that leans "/" (real skew, so text slants too)
Item {
    id: s
    property real k: 0.22
    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(1, -s.k, 0, s.k * s.height / 2,
                             0, 1, 0, 0,
                             0, 0, 1, 0,
                             0, 0, 0, 1)
    }
}