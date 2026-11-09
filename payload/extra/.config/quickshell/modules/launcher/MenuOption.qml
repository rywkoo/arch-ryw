import QtQuick

import "." as LauncherTypes
import "../../theme" as SharedTheme
Item {
    id: opt

    property real u: 1
    property string label
    property bool selected
    property int idx
    property color tint: "#16cffb"
    property real rot: 0     // resting tilt (deg)
    property real ox: 0      // horizontal offset
    property real oy: 0      // vertical position
    property real prog: 0    // entrance 0..1
    property real out: 1     // exit 1..0

    readonly property real fs: 64 * u

    function easeOutBack(x) {
        const c1 = 1.6, c3 = c1 + 1
        return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2)
    }

    width: txt.implicitWidth + 90 * u
    height: fs
    x: ox - (1 - easeOutBack(prog)) * 900 * u - (1 - out) * 600 * u
    y: oy
    opacity: Math.min(1, prog * 3) * out

    Item {
        id: pop
        width: opt.width
        height: opt.height
        transformOrigin: Item.Left

        // selected options straighten up slightly and pop out
        rotation: opt.selected ? opt.rot * 0.35 : opt.rot
        scale: opt.selected ? 1.18 : 1
        x: opt.selected ? 24 * opt.u : 0

        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale    { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        Behavior on x        { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        property real wW: opt.selected ? opt.width * 0.8 : 0
        property real pW: opt.selected ? opt.width * 1.0 : 0
        property real pulse: 1
        Behavior on wW { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on pW { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        SequentialAnimation on pulse {
            running: opt.selected
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 1.07; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 420; easing.type: Easing.InOutSine }
        }

        // pink block (pulses)
        Rectangle {
            id: pink
            x: 22 * opt.u; y: 12 * opt.u
            width: pop.pW
            height: opt.height * 0.92
            color: SharedTheme.Theme.p3Pink
            transformOrigin: Item.Left
            scale: pop.pulse
        }

        // white block
        Rectangle {
            id: white
            width: pop.wW
            height: opt.height * 0.92
            color: "white"
        }

        // base text: black when selected, tinted otherwise
        Text {
            id: txt
            x: 36 * opt.u
            y: (opt.height - implicitHeight) / 2
            text: opt.label
            color: opt.selected ? SharedTheme.Theme.p3Ink : opt.tint
            font.family: SharedTheme.Theme.p3Family
            font.weight: Font.Black
            font.italic: true
            font.pixelSize: opt.fs * 0.9
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        // red copy of the text, visible only where it overlaps the pink block
        Item {
            id: redClip
            visible: opt.selected
            x: pop.wW
            y: pink.y
            width: Math.max(0, pink.x + pink.width - pop.wW)
            height: pink.height
            clip: true

            Text {
                x: txt.x - redClip.x
                y: txt.y - redClip.y
                text: opt.label
                color: SharedTheme.Theme.p3Red
                font: txt.font
            }
        }
    }
}
