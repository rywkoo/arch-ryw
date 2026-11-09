
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Fixed right-side wallpaper drawer. Uses Quickshell Process objects directly;
// SDDM is intentionally not modified.
PanelWindow {
    id: root

    // The panel exists only while opening, open, or closing.
    visible: false
    color: "transparent"
    implicitWidth: 360
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        right: true
    }

    margins {
        top: 5
        bottom: 5
        right: 4
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallchange"

    property bool panelOpen: false
    property string currentStdout: ""
    property string currentStderr: ""

    function openPanel() {
        closeTimer.stop()
        openTimer.stop()

        if (panelOpen && visible)
            return

        panelOpen = false
        visible = true
        openTimer.restart()
    }

    function closePanel() {
        openTimer.stop()

        if (!visible || !panelOpen)
            return

        panelOpen = false
        closeTimer.restart()
    }

    function togglePanel() {
        if (visible && panelOpen)
            closePanel()
        else
            openPanel()
    }

    Timer {
        id: openTimer
        interval: 16
        repeat: false
        onTriggered: if (root.visible) root.panelOpen = true
    }

    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!root.panelOpen)
                root.visible = false
        }
    }

    GlobalShortcut {
        name: "wallchange-toggle"
        description: "Open or close the wallchange wallpaper drawer"
        onPressed: root.togglePanel()
    }

    property color walBackground: "#202127"
    property color walForeground: "#e6e6e9"
    property color walAccent: "#8ab4f8"
    property color walHover: "#f38ba8"
    property color walMuted: "#a1a3ad"

    readonly property color walSurface: Qt.lighter(walBackground, 1.12)
    readonly property color walBorder: Qt.lighter(walBackground, 1.28)

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperDir: home + "/Pictures/wallpaper"
    readonly property string rofiImageDir: home + "/.config/rofi/image"
    readonly property string rofiBackground: rofiImageDir + "/background.jpg"
    readonly property string hyprlockConf: home + "/.config/hypr/hyprlock.conf"
    readonly property string hyprlockImage: home + "/.config/hypr/hyprlock/image/image.jpg"
    readonly property string cavaConfig: home + "/.config/cava/config"
    readonly property string walColorsPath: home + "/.cache/wal/colors.json"

    property var wallpaperFiles: []
    property var palette: []
    property string statusText: "Loading wallpapers…"
    property string errorText: ""
    property string selectedWallpaper: ""
    property bool applying: false
    property var jobs: []
    property int jobIndex: 0

    function notify(title, message) {
        notifyProcess.command = ["notify-send", title, message]
        notifyProcess.running = true
    }

    function refreshWallpapers() {
        listProcess.command = [
            "find", wallpaperDir, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")", "-print"
        ]

        listProcess.running = true
    }

    function refreshPalette() {
        paletteProcess.command = ["cat", walColorsPath]
        paletteProcess.running = true
    }

    function onPaletteLoaded(jsonText) {
        try {
            const data = JSON.parse(jsonText)
            const result = []

            for (let i = 0; i < 16; i++) {
                const key = "color" + i

                if (data.colors && data.colors[key])
                    result.push({ name: key, value: data.colors[key] })
            }

            palette = result

            if (data.special && data.special.background)
                walBackground = data.special.background

            if (data.special && data.special.foreground)
                walForeground = data.special.foreground

            if (data.colors && data.colors.color6)
                walAccent = data.colors.color6

            if (data.colors && data.colors.color1)
                walHover = data.colors.color1

            if (data.colors && data.colors.color4)
                walMuted = data.colors.color4

            // At Quickshell startup, restore the last Pywal border colors.
            // During wallpaper changes, the queued job below applies them.
            if (!applying) {
                hyprlandColorProcess.command = hyprlandColorCommand(data)
                hyprlandColorProcess.running = true
            }
        } catch (e) {
            console.warn("Could not parse Pywal palette:", e)
        }
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // Hyprland 0.57 uses Lua configuration. Apply border colors through
    // `hyprctl eval` instead of editing the removed appearance.conf file.
    function hyprlandColorCommand(data) {
        const colors = data.colors || ({})

        const hex = (value, fallback) => {
            const candidate = String(value || fallback)
            return /^#[0-9a-fA-F]{6}$/.test(candidate)
                ? candidate.slice(1)
                : fallback.slice(1)
        }

        const rgba = (index, alpha) =>
            "rgba(" + hex(colors["color" + index], "#000000") + alpha + ")"

        const active1 = rgba(1, "ee")
        const active3 = rgba(3, "ee")
        const inactive4 = rgba(4, "aa")
        const inactive2 = rgba(2, "aa")

        const lua = [
            "hl.config({",
            "    general = {",
            "        col = {",
            "            active_border = { colors = {" +
                JSON.stringify(active1) + ", " + JSON.stringify(active3) +
                "}, angle = 45 },",
            "            inactive_border = { colors = {" +
                JSON.stringify(inactive4) + ", " + JSON.stringify(inactive2) +
                "}, angle = 45 },",
            "        }",
            "    }",
            "})"
        ].join("\n")

        return ["hyprctl", "eval", lua]
    }

    function addJob(label, command, optional) {
        jobs.push({
            label: label,
            command: command,
            optional: optional === true
        })
    }

    function makeJobs(path) {
        jobs = []
        jobIndex = 0
        selectedWallpaper = path
        errorText = ""

        // Stop Waybar before changing desktop colors.
        addJob("Stop Waybar", ["pkill", "-x", "waybar"], true)

        // Set the wallpaper with a transition.
        addJob("Set wallpaper", [
            "awww", "img", path,
            "--transition-type", "grow",
            "--transition-pos", "0.5,0.99"
        ])

        // Generate Rofi background.
        addJob("Create Rofi image directory", [
            "mkdir", "-p", rofiImageDir
        ])

        addJob("Generate Rofi background", [
            "convert", path,
            "-resize", "1920x1080^",
            "-gravity", "center",
            "-crop", "1920x700+0-100",
            "+repage", rofiBackground
        ])

        // Generate Pywal colors.
        addJob("Generate Pywal colors", [
            "wal", "-i", path,
            "--saturate", "0.8",
            "-n"
        ])

        // Stop SwayNC before reloading.
        addJob("Stop SwayNC", ["pkill", "swaync"], true)
        addJob("Allow desktop reload to settle", ["sleep", "1"])

        // Generate Hyprlock wallpaper.
        addJob("Create Hyprlock image directory", [
            "mkdir", "-p",
            home + "/.config/hypr/hyprlock/image"
        ])

        addJob("Generate Hyprlock image", [
            "convert", path,
            "-resize", "1920x1080!",
            "-gravity", "center",
            "-crop", "1920x1080+0+0",
            "+repage", hyprlockImage
        ])

        // Read generated Pywal colors for configuration updates.
        addJob("Read generated Pywal colors", ["cat", walColorsPath])

        addJob("Allow Hyprland reload to settle", ["sleep", "2"])

        // Restart Waybar only if it is not already running.
        // Keep a log in case Waybar fails to start.
        addJob("Restart Waybar", [
            "sh", "-c",
            "pgrep -x waybar >/dev/null || (setsid waybar >/tmp/waybar-wallchange.log 2>&1 </dev/null &)"
        ])

        // Restart SwayNC.
        addJob("Restart SwayNC", [
            "sh", "-c",
            "swaync >/dev/null 2>&1 &"
        ], true)

        // Reload Cava colors.
        addJob("Reload Cava colors", [
            "pkill", "-SIGUSR1", "cava"
        ], true)

        addJob("Finish", ["true"])

        applying = true
        statusText = "Applying " + path.split("/").pop() + "…"
        runNext()
    }

    function appendColorJobs(jsonText) {
        let data

        try {
            data = JSON.parse(jsonText)
        } catch (e) {
            abortApply("Could not parse " + walColorsPath + ": " + e)
            return false
        }

        const colors = data.colors || ({})
        const special = data.special || ({})
        const c = []

        for (let i = 0; i < 8; i++)
            c.push(colors["color" + i] || "#000000")

        const fg = special.foreground || "#ffffff"
        const bg = special.background || "#000000"

        const cava = `[general]
framerate = 60
autosens = 1
sensitivity = 100
bars = 0
bar_width = 2
bar_spacing = 1
lower_cutoff_freq = 50
higher_cutoff_freq = 10000
sleep_timer = 0

[input]
method = pulse
source = auto

[output]
method = noncurses
channels = stereo
orientation = bottom
synchronized_sync = 1
xaxis = none
show_idle_bar_heads = 1

[color]
background = "${bg}"
foreground = "${fg}"
gradient = 1
gradient_color_1 = "${c[0]}"
gradient_color_2 = "${c[1]}"
gradient_color_3 = "${c[2]}"
gradient_color_4 = "${c[3]}"
gradient_color_5 = "${c[4]}"
gradient_color_6 = "${c[5]}"
gradient_color_7 = "${c[6]}"
gradient_color_8 = "${c[7]}"

[smoothing]
noise_reduction = 77
`

        const writeCava =
            "cat > " + shellQuote(cavaConfig) +
            " <<'WALLCHANGE_CAVA'\n" +
            cava +
            "WALLCHANGE_CAVA"

        addJob("Write Cava configuration", [
            "sh", "-c", writeCava
        ])

        const rgba = (hex, alpha) => {
            const h = hex.replace("#", "")

            return "rgba(" +
                parseInt(h.slice(0, 2), 16) + ", " +
                parseInt(h.slice(2, 4), 16) + ", " +
                parseInt(h.slice(4, 6), 16) + ", " +
                alpha + ")"
        }

        const edits = [
            ["outer_color", rgba(bg, "0.0")],
            ["inner_color", rgba(bg, "0.36")],
            ["font_color", rgba(fg, "0.9")],
            ["check_color", rgba(c[2], "1.0")]
        ]

        for (let i = 0; i < edits.length; i++) {
            addJob("Update Hyprlock " + edits[i][0], [
                "sed", "-i", "-E",
                "s|^[[:space:]]*" + edits[i][0] +
                "[[:space:]]*=.*|    " +
                edits[i][0] + " = " + edits[i][1] + "|",
                hyprlockConf
            ])
        }

        addJob("Save Hyprlock background path", [
            "sh", "-c",
            "tmp=" + shellQuote(hyprlockConf + ".tmp") +
            " && awk -v newpath=" + shellQuote(hyprlockImage) +
            " 'BEGIN { in_block=0 } /^background[[:space:]]*[{]/ { in_block=1 } /^[[:space:]]*[}]/ { if (in_block) in_block=0 } { if (in_block && $1==\"path\" && $2==\"=\") print \"    path = \" newpath; else print $0 }' " +
            shellQuote(hyprlockConf) +
            " > \"$tmp\" && cat \"$tmp\" > " +
            shellQuote(hyprlockConf) +
            " && rm -f \"$tmp\""
        ])

        addJob("Update Hyprlock placeholder", [
            "sed", "-i", "-E",
            "s|^[[:space:]]*placeholder_text[[:space:]]*=.*|    placeholder_text = <b><span foreground=\"" +
            fg + "\">password...</span></b>|",
            hyprlockConf
        ])

        // Update active/inactive borders through Hyprland's Lua evaluator.
        // This replaces the obsolete appearance.conf sed edits.
        addJob("Update Hyprland borders", hyprlandColorCommand(data))

        return true
    }

    function runNext() {
        if (!applying)
            return

        if (jobIndex >= jobs.length) {
            applying = false
            statusText = "Wallpaper applied: " + selectedWallpaper.split("/").pop()

            notify(
                "Wallpaper Applied",
                selectedWallpaper.split("/").pop() +
                " - desktop components synchronized."
            )

            return
        }

        const job = jobs[jobIndex]

        statusText = job.label + "…"
        currentStdout = ""
        currentStderr = ""

        runner.command = job.command
        runner.running = true
    }

    function handleExit(code) {
        const job = jobs[jobIndex]

        if (!job)
            return

        if (job.label === "Generate Pywal colors" && code === 0)
            refreshPalette()

        if (job.label === "Read generated Pywal colors" && code === 0) {
            if (!appendColorJobs(currentStdout))
                return

            jobs.splice(jobIndex, 1, {
                label: "Palette loaded",
                command: ["true"],
                optional: false
            })

            const start = jobIndex + 1
            const inserted = jobs.splice(start, jobs.length - start)

            const colorJobs = inserted.filter(j =>
                j.label.startsWith("Write Cava") ||
                j.label.startsWith("Update Hyprlock") ||
                j.label === "Save Hyprlock background path" ||
                j.label === "Update Hyprland borders"
            )

            const otherJobs = inserted.filter(j => !colorJobs.includes(j))

            jobs.splice(start, 0, ...colorJobs, ...otherJobs)
        } else if (code !== 0 && !job.optional) {
            abortApply(
                job.label + " failed (exit code " + code + ").\n" +
                currentStderr
            )

            return
        }

        jobIndex++
        runNext()
    }

    function abortApply(message) {
        applying = false
        errorText = message || "A command failed."
        statusText = "Wallpaper update failed."

        notify("Wallpaper Error", errorText)
    }

    function applyWallpaper(path) {
        if (applying || !path)
            return

        wallpaperFiles = [
            path,
            ...wallpaperFiles.filter(item => item !== path)
        ]

        selectedWallpaper = path
        makeJobs(path)
    }

    Process {
        id: listProcess
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                let files = raw.length ? raw.split("\n").sort() : []

                if (root.selectedWallpaper &&
                    files.includes(root.selectedWallpaper)) {
                    files = [
                        root.selectedWallpaper,
                        ...files.filter(item => item !== root.selectedWallpaper)
                    ]
                }

                root.wallpaperFiles = files

                root.statusText = files.length
                    ? files.length + " wallpapers found."
                    : "No wallpapers found in " + root.wallpaperDir
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn(text)
        }
    }

    Process {
        id: paletteProcess
        command: ["cat", root.walColorsPath]

        stdout: StdioCollector {
            onStreamFinished: root.onPaletteLoaded(text)
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn(text)
        }
    }

    StdioCollector {
        id: runnerOutput
        onStreamFinished: root.currentStdout = text
    }

    StdioCollector {
        id: runnerError
        onStreamFinished: root.currentStderr = text
    }

    Process {
        id: runner
        command: []
        stdout: runnerOutput
        stderr: runnerError
        onExited: (exitCode, exitStatus) => root.handleExit(exitCode)
    }

    Process {
        id: hyprlandColorProcess
        command: []

        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) console.log("Hyprland color update:", text.trim())
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Hyprland color update:", text.trim())
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("Hyprland border color update failed with exit code", exitCode)
        }
    }

    Process {
        id: notifyProcess
        command: []
    }

    Component.onCompleted: {
        refreshWallpapers()
        refreshPalette()
    }

    Item {
        id: panelContent

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        width: root.panelOpen ? 360 : 0
        clip: true

        focus: root.panelOpen
        Keys.onEscapePressed: root.closePanel()

        Behavior on width {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.walBackground
            radius: 18
            border.width: 0
        }

        // This handle is visible only while the drawer is open and closes it.
        Button {
            id: drawerHandle

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: 28
            height: 76
            z: 10

            text: "›"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 30
            padding: 0

            background: Rectangle {
                radius: 10

                color: drawerHandle.down
                    ? root.walAccent
                    : (drawerHandle.hovered
                        ? root.walSurface
                        : Qt.darker(root.walBackground, 1.12))

                border.color: root.walBorder
                border.width: 1
            }

            contentItem: Text {
                text: drawerHandle.text
                color: drawerHandle.down
                    ? root.walBackground
                    : root.walForeground

                font: drawerHandle.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: root.closePanel()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: "wallchange"
                        color: root.walForeground
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: "Select a wallpaper"
                        color: root.walMuted
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                }

                Button {
                    text: "↻"
                    enabled: !root.applying

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    implicitWidth: 34
                    implicitHeight: 32

                    background: Rectangle {
                        radius: 16

                        color: parent.down
                            ? root.walAccent
                            : (parent.hovered
                                ? root.walSurface
                                : "transparent")

                        border.color: root.walBorder
                        border.width: 1
                    }

                    contentItem: Text {
                        text: parent.text
                        color: parent.down
                            ? root.walBackground
                            : root.walForeground

                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.refreshWallpapers()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 20
                color: root.walSurface
                border.color: root.walBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    BusyIndicator {
                        running: root.applying
                        visible: root.applying
                        implicitWidth: 17
                        implicitHeight: 17
                    }

                    Rectangle {
                        visible: !root.applying
                        width: 7
                        height: 7
                        radius: 4

                        color: root.errorText.length
                            ? root.walHover
                            : root.walAccent
                    }

                    Label {
                        Layout.fillWidth: true

                        text: root.statusText
                        color: root.errorText.length
                            ? root.walHover
                            : root.walForeground

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Button {
                        visible: root.errorText.length > 0
                        text: "!"
                        flat: true
                        onClicked: errorDialog.open()
                    }
                }
            }

            Label {
                text: "WALLPAPERS"
                color: root.walMuted

                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.bold: true

                Layout.topMargin: 2
            }

            ListView {
                id: galleryList

                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                spacing: 10
                model: root.wallpaperFiles

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    required property string modelData

                    width: galleryList.width
                    height: 186
                    radius: 12

                    color: root.walSurface

                    border.width: root.selectedWallpaper === modelData ? 2 : 1
                    border.color: root.selectedWallpaper === modelData
                        ? root.walAccent
                        : root.walBorder

                    clip: true

                    Image {
                        anchors.fill: parent
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        height: 40

                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: "#00101014"
                            }

                            GradientStop {
                                position: 1.0
                                color: "#d9101117"
                            }
                        }
                    }

                    Label {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.bottomMargin: 7

                        text: modelData.split("/").pop()
                        color: "#f3f3f5"
                        elide: Text.ElideMiddle

                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.applying

                        onClicked: root.applyWallpaper(modelData)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    text: "PYWAL"
                    color: root.walAccent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                }

                Rectangle {
                    width: 1
                    height: 12
                    color: root.walBorder
                }

                Label {
                    text: root.palette.length + " / 16"
                    color: root.walMuted
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }

                Item {
                    Layout.fillWidth: true
                }

                Label {
                    text: root.applying ? "APPLYING" : "READY"
                    color: root.applying
                        ? root.walHover
                        : root.walForeground

                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: root.palette

                    delegate: Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 20

                        radius: 10
                        color: modelData.value

                        border.color: "#44ffffff"
                        border.width: 1

                        ToolTip.visible: swatchMouse.containsMouse
                        ToolTip.text: modelData.name + "  " + modelData.value

                        MouseArea {
                            id: swatchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: errorDialog

        title: "Wallpaper update error"
        modal: true
        width: Math.min(400, root.implicitWidth - 30)
        standardButtons: Dialog.Ok

        background: Rectangle {
            color: root.walBackground
            radius: 12
            border.width: 0
        }

        contentItem: ScrollView {
            implicitHeight: Math.min(errorLabel.implicitHeight + 12, 300)

            Label {
                id: errorLabel

                width: errorDialog.width - 40
                text: root.errorText
                color: root.walForeground

                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
        }
    }
}
