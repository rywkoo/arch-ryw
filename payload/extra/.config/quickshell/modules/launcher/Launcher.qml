import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

import "." as LauncherTypes
import "../../theme" as SharedTheme
Item {
    id: root

    // App commands are intentionally easy to customize here.
    // ── Edit these ──
    readonly property var fileCmd:    ["sh", "-c", "xdg-open \"$HOME\""]
    readonly property var browserCmd: ["xdg-open", "https://example.com"]

    function openLauncher() {
        if (win.visible && !scene.closing)
            return
        closeAnim.stop()
        scene.closing = false
        scene.searching = false
        scene.query = ""
        scene.sel = 0
        scene.t = 0
        scene.listT = 0
        win.visible = true
        scene.forceActiveFocus()
        openAnim.restart()
        listAnim.restart()
    }

    function closeLauncher() {
        if (!win.visible || scene.closing)
            return
        openAnim.stop()
        scene.closing = true
        closeAnim.restart()
    }

    function toggleLauncher() {
        if (win.visible && !scene.closing)
            closeLauncher()
        else
            openLauncher()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggleLauncher() }
        function open(): void { root.openLauncher() }
        function close(): void { root.closeLauncher() }
    }

    PanelWindow {
        id: win
        visible: false
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "p3-launcher"

        Item {
            id: scene
            anchors.fill: parent
            focus: true

            readonly property real u: height / 1080
            readonly property real pitch: 64 * u * 0.8
            readonly property var rots: [-3, 2.2, -2, 3, -1.5, 2.6]
            readonly property var oxs:  [40, -10, 30, -30, 20, -20]

            property real t: 0
            property real listT: 0
            property bool closing: false
            property bool searching: false
            property bool cursorOn: true
            property string query: ""
            property int sel: 0

            readonly property bool videoOk: bg.status === Loader.Ready && (bg.item?.ok ?? false)

            function easeOutCubic(x) { return 1 - Math.pow(1 - x, 3) }
            function pad(n) { return n < 10 ? "0" + n : "" + n }

            // ── Data ──
            readonly property var mainItems: [
                { name: "SEARCH",        desc: "Search for an application", run: () => scene.enterSearch("") },
                { name: "FILE EXPLORER", desc: "Open the file explorer",    run: () => { Quickshell.execDetached(fileCmd);    scene.dismiss() } },
                { name: "BROWSER",       desc: "Open the web browser",      run: () => { Quickshell.execDetached(browserCmd); scene.dismiss() } },
            ]

            readonly property var results: {
                const q = query.trim().toLowerCase()
                if (q === "") return []
                const hits = []
                for (const a of DesktopEntries.applications.values) {
                    if (a.noDisplay) continue
                    const n = a.name.toLowerCase()
                    const g = (a.genericName ?? "").toLowerCase()
                    let score = -1
                    if (n.startsWith(q)) score = 0
                    else if (n.includes(q)) score = 1
                    else if (g.includes(q)) score = 2
                    if (score >= 0) hits.push({ a: a, score: score })
                }
                hits.sort((x, y) => x.score - y.score || x.a.name.localeCompare(y.a.name))
                return hits.slice(0, 6).map(h => ({
                    name: h.a.name.toUpperCase(),
                    desc: h.a.comment || h.a.genericName || "Launch application",
                    run: () => { h.a.execute(); scene.dismiss() }
                }))
            }

            readonly property var items: searching ? results : mainItems

            // ── Actions ──
            function enterSearch(q) { searching = true; query = q; sel = 0; listAnim.restart() }
            function leaveSearch()  { searching = false; query = ""; sel = 0; listAnim.restart() }
            function move(d) { const n = items.length; if (n > 0) sel = (sel + d + n) % n }
            function confirm() { const it = items[sel]; if (it) it.run() }
            function dismiss() { root.closeLauncher() }

            Component.onCompleted: { t = 0; listT = 0 }

            NumberAnimation { id: openAnim;  target: scene; property: "t"; from: 0; to: 1; duration: 700 }
            NumberAnimation {
                id: closeAnim
                target: scene
                property: "t"
                to: 0
                duration: 300
                onFinished: {
                    win.visible = false
                    scene.closing = false
                }
            }
            NumberAnimation { id: listAnim;  target: scene; property: "listT"; from: 0; to: 1; duration: 900 }
            Timer { interval: 500; running: true; repeat: true; onTriggered: scene.cursorOn = !scene.cursorOn }

            // ── Input ──
            Keys.onPressed: e => {
                e.accepted = true
                if (closing) return
                const ctrl = e.modifiers & Qt.ControlModifier
                if (e.key === Qt.Key_Escape) { searching ? leaveSearch() : root.closeLauncher() }
                else if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_N)) move(1)
                else if (e.key === Qt.Key_Up   || (ctrl && e.key === Qt.Key_P)) move(-1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) confirm()
                else if (e.key === Qt.Key_Backspace) {
                    if (searching) { if (query.length > 0) { query = query.slice(0, -1); sel = 0 } else leaveSearch() }
                }
                else if (!ctrl && e.text.length === 1 && e.text >= " ") {
                    if (!searching) enterSearch(e.text)
                    else { query += e.text; sel = 0 }
                }
            }

            // ── Background: gradient fallback + looping video on top ──
            Rectangle {
                anchors.fill: parent
                opacity: Math.min(1, scene.t * 3)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#f6feff" }
                    GradientStop { position: 1.0; color: "#a8ecff" }
                }
            }
            Loader {
                id: bg
                anchors.fill: parent
                source: "Background.qml"
                opacity: Math.min(1, scene.t * 3)
            }

            // ── Huge text (only when there's no video; the video has its own baked in) ──
            Text {
                id: huge
                visible: !scene.videoOk
                property real shift: 0
                anchors {
                    right: parent.right
                    rightMargin: 40 * scene.u - shift
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: -60 * scene.u
                }
                width: parent.width * 0.62
                horizontalAlignment: Text.AlignRight
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 60
                text: scene.items[scene.sel]?.name ?? ""
                color: SharedTheme.Theme.p3Ink
                opacity: 0.92 * scene.t
                font.family: SharedTheme.Theme.p3Family
                font.weight: Font.Black
                font.italic: true
                font.pixelSize: 420 * scene.u
                onTextChanged: hugeAnim.restart()
                NumberAnimation { id: hugeAnim; target: huge; property: "shift"; from: -140; to: 0; duration: 400; easing.type: Easing.OutCubic }
            }

            // ── Search line ──
            Text {
                visible: scene.searching
                x: scene.width * 0.26
                y: scene.height / 2 - (scene.items.length * scene.pitch) / 2 - 96 * scene.u
                opacity: scene.listT
                text: "SEARCH ▸ " + scene.query + (scene.cursorOn ? "▌" : " ")
                color: "white"
                style: Text.Outline
                styleColor: SharedTheme.Theme.p3Outline
                font.family: SharedTheme.Theme.p3Family
                font.weight: Font.Black
                font.italic: true
                font.pixelSize: 40 * scene.u
            }

            // ── Options ──
            Item {
                x: scene.width * 0.26
                y: scene.height / 2 - (scene.items.length * scene.pitch) / 2

                Repeater {
                    model: scene.items
                    LauncherTypes.MenuOption {
                        required property int index
                        required property var modelData
                        u: scene.u
                        idx: index
                        label: modelData.name
                        selected: index === scene.sel
                        tint: SharedTheme.Theme.p3Tints[index % 3]
                        rot: scene.rots[index % scene.rots.length]
                        ox: scene.oxs[index % scene.oxs.length] * scene.u
                        oy: index * scene.pitch
                        prog: Math.max(0, Math.min(1, (scene.listT * 1.5 - index * 0.1) / 0.6))
                        out: scene.closing ? scene.t : 1
                    }
                }

                Text {
                    visible: scene.searching && scene.results.length === 0
                    text: scene.query === "" ? "TYPE TO SEARCH" : "NO MATCH"
                    color: "white"
                    style: Text.Outline
                    styleColor: SharedTheme.Theme.p3Outline
                    font.family: SharedTheme.Theme.p3Family
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 40 * scene.u
                }
            }

            // ── Bottom-right: description, command, controls ──
            Column {
                id: panel
                width: 760 * scene.u
                spacing: 12 * scene.u
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 90 * scene.u
                    bottomMargin: 70 * scene.u - (1 - scene.easeOutCubic(scene.t)) * 120 * scene.u
                }
                opacity: scene.t

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: scene.items[scene.sel]?.desc ?? ""
                    elide: Text.ElideLeft
                    color: "white"
                    style: Text.Outline
                    styleColor: SharedTheme.Theme.p3Outline
                    font.family: SharedTheme.Theme.p3Family
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 44 * scene.u
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: "Command"
                    color: SharedTheme.Theme.p3Cyan
                    style: Text.Outline
                    styleColor: SharedTheme.Theme.p3Outline
                    font.family: SharedTheme.Theme.p3Family
                    font.weight: Font.Black
                    font.italic: true
                    font.pixelSize: 28 * scene.u
                }

                Rectangle { width: parent.width; height: 3 * scene.u; color: "white" }

                Row {
                    anchors.right: parent.right
                    spacing: 36 * scene.u

                    Row {
                        spacing: 10 * scene.u
                        Rectangle {
                            width: 40 * scene.u; height: width; radius: width / 2; color: "white"
                            Text { anchors.centerIn: parent; text: "B"; color: SharedTheme.Theme.p3Ink
                                   font.family: SharedTheme.Theme.p3Family; font.weight: Font.Black; font.pixelSize: 24 * scene.u }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Confirm"; color: "white"
                               style: Text.Outline; styleColor: SharedTheme.Theme.p3Outline
                               font.family: SharedTheme.Theme.p3Family; font.weight: Font.Black; font.italic: true; font.pixelSize: 28 * scene.u }
                    }

                    Row {
                        spacing: 10 * scene.u
                        Rectangle {
                            width: 40 * scene.u; height: width; radius: width / 2; color: "white"
                            Text { anchors.centerIn: parent; text: "A"; color: SharedTheme.Theme.p3Ink
                                   font.family: SharedTheme.Theme.p3Family; font.weight: Font.Black; font.pixelSize: 24 * scene.u }
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Close"; color: "white"
                               style: Text.Outline; styleColor: SharedTheme.Theme.p3Outline
                               font.family: SharedTheme.Theme.p3Family; font.weight: Font.Black; font.italic: true; font.pixelSize: 28 * scene.u }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: scene.pad(scene.items.length > 0 ? scene.sel + 1 : 0)
                        color: "white"
                        style: Text.Outline
                        styleColor: SharedTheme.Theme.p3Outline
                        font.family: SharedTheme.Theme.p3Family; font.weight: Font.Black; font.italic: true; font.pixelSize: 44 * scene.u
                    }
                }
            }
        }
    }
}
