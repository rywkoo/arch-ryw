pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    readonly property color deep: wal.adapter.special.background
    readonly property color ice:  wal.adapter.special.foreground
    readonly property color navy: wal.adapter.colors.color0
    readonly property color red:   wal.adapter.colors.color1
    readonly property color green: wal.adapter.colors.color2
    readonly property color warn:  wal.adapter.colors.color3
    readonly property color blue:  wal.adapter.colors.color4
    readonly property color cyan:  wal.adapter.colors.color6
    readonly property string font: "JetBrainsMono Nerd Font"

    // Launcher (P3) palette and font live here as well, so style tokens have
    // one source while the launcher keeps its distinct visual identity.
    readonly property var p3Tints: ["#16cffb", "#7de6fd", "#77fefc"]
    readonly property color p3Pink: "#ff5c9a"
    readonly property color p3Red: "#e8103f"
    readonly property color p3Ink: "#0a0a0a"
    readonly property color p3Outline: "#5f6c78"
    readonly property color p3Cyan: "#16cffb"
    readonly property string p3Family: p3FontLoader.status === FontLoader.Ready ? p3FontLoader.name : "Sans"

    FontLoader {
        id: p3FontLoader
        source: Qt.resolvedUrl("../modules/launcher/fonts/p3.ttf")
    }

    FileView {
        id: wal
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            property JsonObject special: JsonObject {
                property string background: "#040b26"
                property string foreground: "#eafcff"
            }
            property JsonObject colors: JsonObject {
                property string color0: "#0b1f6b"
                property string color1: "#ff2a4d"
                property string color2: "#8bd450"
                property string color3: "#ffd84f"
                property string color4: "#6096ff"
                property string color6: "#4ff1ff"
            }
        }
    }
}