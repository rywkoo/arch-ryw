
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications

import "../../theme" as SharedTheme
PanelWindow {
    id: root

    visible: false
    color: "transparent"
    implicitWidth: 380
    implicitHeight: 760
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: 5
        right: 4
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    // ---------------------------------------------------------
    // STATE
    // ---------------------------------------------------------

    property bool panelOpen: false
    property bool doNotDisturb: false
    property string statusText: "Notifications ready"

    property color walBackground: SharedTheme.Theme.deep
    property color walForeground: SharedTheme.Theme.ice
    property color walAccent: SharedTheme.Theme.cyan
    property color walHover: SharedTheme.Theme.red
    property color walSelected: SharedTheme.Theme.cyan
    property color walUrgent: SharedTheme.Theme.green
    property color walMuted: SharedTheme.Theme.blue

    readonly property color walSurface:
        Qt.lighter(walBackground, 1.12)

    readonly property color walSoftSurface:
        Qt.rgba(
            walForeground.r,
            walForeground.g,
            walForeground.b,
            0.055
        )

    readonly property color walBorder:
        Qt.lighter(walBackground, 1.28)

    readonly property string uiFont: SharedTheme.Theme.font

    property int brightnessValue: 70

    // Contains only players whose status is Playing.
    property var activePlayers: []

    // ---------------------------------------------------------
    // PANEL ANIMATION
    // ---------------------------------------------------------

    function openPanel() {
        closeTimer.stop()
        openAnimationTimer.stop()

        panelOpen = false
        visible = true

        openAnimationTimer.start()
    }

    function closePanel() {
        openAnimationTimer.stop()
        panelOpen = false
        closeTimer.restart()
    }

    function togglePanel() {
        if (visible && panelOpen)
            closePanel()
        else
            openPanel()
    }

    // ---------------------------------------------------------
    // NOTIFICATIONS
    // ---------------------------------------------------------

    function clearNotifications() {
        for (
            let i = notificationServer.trackedNotifications.count - 1;
            i >= 0;
            i--
        ) {
            const item =
                notificationServer.trackedNotifications.get(i)

            if (item)
                item.dismiss()
        }
    }

    // ---------------------------------------------------------
    // COMMAND RUNNER
    // ---------------------------------------------------------

    function runCommand(command) {
        if (!command || actionProcess.running)
            return

        actionProcess.command = ["sh", "-lc", command]
        actionProcess.running = true
    }

    function setBrightness(value) {
        brightnessValue = Math.round(value)
        runCommand("brightnessctl set " + brightnessValue + "%")
    }

    // Safely target an individual media player.
    function mediaControlCommand(player, action) {
        if (!player)
            return ""

        const safePlayer =
            "'" + player.replace(/'/g, "'\\''") + "'"

        return "playerctl --player=" + safePlayer + " " + action
    }

    function refreshMedia() {
        if (!mediaProcess.running)
            mediaProcess.running = true
    }

    // ---------------------------------------------------------
    // TIMERS
    // ---------------------------------------------------------

    Timer {
        id: openAnimationTimer
        interval: 16
        repeat: false

        onTriggered: root.panelOpen = true
    }

    Timer {
        id: closeTimer
        interval: 320
        repeat: false

        onTriggered: {
            if (!root.panelOpen)
                root.visible = false
        }
    }

    Timer {
        id: refreshTimer
        interval: 2000
        repeat: true
        running: true

        onTriggered: {
            root.refreshMedia()

            if (!brightnessReadProcess.running)
                brightnessReadProcess.running = true
        }
    }

    // ---------------------------------------------------------
    // IPC
    // ---------------------------------------------------------

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.togglePanel()
        }

        function open(): void {
            root.openPanel()
        }

        function close(): void {
            root.closePanel()
        }
    }

    // ---------------------------------------------------------
    // NOTIFICATION SERVER
    // Disable SwayNC before using this notification center.
    // ---------------------------------------------------------

    NotificationServer {
        id: notificationServer

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            if (root.doNotDisturb) {
                notification.tracked = false
            } else {
                notification.tracked = true

                if (!root.visible)
                    root.statusText = "New notification"
            }
        }
    }

    // ---------------------------------------------------------
    // GENERAL COMMAND PROCESS
    // ---------------------------------------------------------

    Process {
        id: actionProcess
        command: []

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn(
                    "Notification center command failed:",
                    exitCode
                )
        }
    }

    // ---------------------------------------------------------
    // BRIGHTNESS READER
    // ---------------------------------------------------------

    Process {
        id: brightnessReadProcess

        command: [
            "sh",
            "-lc",
            "brightnessctl -m | cut -d, -f4 | tr -d '%'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())

                if (!Number.isNaN(n)) {
                    root.brightnessValue = Math.max(
                        0,
                        Math.min(100, n)
                    )
                }
            }
        }
    }

    // ---------------------------------------------------------
    // DYNAMIC MEDIA SCANNER
    //
    // Discover every MPRIS player.
    // Include only players currently Playing.
    // Each player becomes its own card.
    // ---------------------------------------------------------


Process {
    id: mediaProcess

    command: [
        "bash",
        "-lc",
        `
        while IFS= read -r player; do
            [ -n "$player" ] || continue

            status=$(playerctl --player="$player" status 2>/dev/null) || continue

            case "$status" in
                Playing|Paused) ;;
                *) continue ;;
            esac

            title=$(playerctl --player="$player" metadata title 2>/dev/null)
            artist=$(playerctl --player="$player" metadata artist 2>/dev/null)
            art=$(playerctl --player="$player" metadata mpris:artUrl 2>/dev/null)

            printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \
                "$player" "$title" "$artist" "$art" "$status"
        done < <(playerctl -l 2>/dev/null)
        `
    ]

    stdout: StdioCollector {
        onStreamFinished: {
            const result = []
            const output = text.trim()

            if (output.length > 0) {
                for (const line of output.split("\n")) {
                    const fields = line.split("\t")

                    if (!fields[0])
                        continue

                    result.push({
                        player: fields[0],
                        title: fields[1] || "Unknown title",
                        artist: fields[2] || "Unknown artist",
                        artUrl: fields[3] || "",
                        status: fields[4] || "Playing"
                    })
                }
            }

            root.activePlayers = result
        }
    }

    stderr: StdioCollector {
        onStreamFinished: {
            if (text.trim())
                console.warn("Media scanner:", text)
        }
    }
}


    Component.onCompleted: {
        refreshMedia()
        brightnessReadProcess.running = true
    }

    // ---------------------------------------------------------
    // DRAWER
    // ---------------------------------------------------------

    Item {
        id: panelContent

        width: parent.width
        height: root.panelOpen ? root.implicitHeight : 0
        clip: true
        focus: root.panelOpen

        Behavior on height {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        Keys.onEscapePressed: root.closePanel()

        Rectangle {
            anchors.fill: parent
            color: root.walBackground
            radius: 18
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // -------------------------------------------------
            // HEADER
            // -------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Label {
                        text: "notifications"
                        color: root.walForeground
                        font.family: root.uiFont
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text:
                            notificationServer.trackedNotifications.count
                            + " saved  ·  "
                            + (
                                root.doNotDisturb
                                ? "Do not disturb"
                                : "Notifications enabled"
                              )

                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Button {
                    id: dndButton

                    text: root.doNotDisturb ? "󰂛" : "󰂚"
                    implicitWidth: 36
                    implicitHeight: 36
                    padding: 0

                    background: Rectangle {
                        radius: 18

                        color: root.doNotDisturb
                            ? root.walSelected
                            : dndButton.hovered
                                ? root.walSoftSurface
                                : "transparent"

                        border.color: root.walBorder
                        border.width: 1
                    }

                    contentItem: Text {
                        text: dndButton.text

                        color: root.doNotDisturb
                            ? root.walBackground
                            : root.walForeground

                        font.family: root.uiFont
                        font.pixelSize: 16

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: "Toggle Do Not Disturb"

                    onClicked: root.doNotDisturb = !root.doNotDisturb
                }

                Button {
                    id: closeButton

                    text: "󰅖"
                    implicitWidth: 36
                    implicitHeight: 36
                    padding: 0

                    background: Rectangle {
                        radius: 18
                        color: closeButton.hovered
                            ? root.walHover
                            : "transparent"
                    }

                    contentItem: Text {
                        text: closeButton.text

                        color: closeButton.hovered
                            ? root.walBackground
                            : root.walForeground

                        font.family: root.uiFont
                        font.pixelSize: 17

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.closePanel()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.walBorder
            }

            // -------------------------------------------------
            // BRIGHTNESS CARD
            // -------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                radius: 16
                color: root.walSurface
                border.color: root.walBorder
                border.width: 1

                implicitHeight: brightnessColumn.implicitHeight + 20

                ColumnLayout {
                    id: brightnessColumn

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Label {
                            text: "󰃠"
                            color: root.walAccent
                            font.family: root.uiFont
                            font.pixelSize: 20
                        }

                        Label {
                            text: "Brightness"
                            color: root.walForeground
                            font.family: root.uiFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Label {
                            text: root.brightnessValue + "%"
                            color: root.walMuted
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                    }

                    Slider {
                        id: brightnessSlider

                        Layout.fillWidth: true
                        implicitHeight: 24

                        from: 0
                        to: 100
                        value: root.brightnessValue

                        onMoved: root.setBrightness(value)

                        background: Rectangle {
                            x: brightnessSlider.leftPadding

                            y: brightnessSlider.topPadding
                                + brightnessSlider.availableHeight / 2
                                - height / 2

                            width: brightnessSlider.availableWidth
                            height: 8
                            radius: 4
                            color: root.walSoftSurface

                            Rectangle {
                                width: brightnessSlider.visualPosition
                                    * parent.width

                                height: parent.height
                                radius: 4
                                color: root.walAccent
                            }
                        }

                        handle: Rectangle {
                            x: brightnessSlider.leftPadding
                                + brightnessSlider.visualPosition
                                * (
                                    brightnessSlider.availableWidth - width
                                  )

                            y: brightnessSlider.topPadding
                                + brightnessSlider.availableHeight / 2
                                - height / 2

                            width: 13
                            height: 13
                            radius: 7

                            color: brightnessSlider.pressed
                                ? root.walHover
                                : root.walForeground
                        }
                    }
                }
            }

            // -------------------------------------------------
            // NOW PLAYING
            //
            // Hidden completely when no media is playing.
            // Scrolls vertically when many players are active.
            // -------------------------------------------------

            ColumnLayout {
                id: mediaSection

                Layout.fillWidth: true
                spacing: 8

                visible: root.activePlayers.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Label {
                        text: "NOW PLAYING"
                        color: root.walAccent
                        font.family: root.uiFont
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: root.activePlayers.length + " active"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 9
                    }
                }

                Flickable {
                    id: mediaFlickable

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(
                        mediaCards.implicitHeight,
                        230
                    )

                    clip: true
                    contentWidth: width
                    contentHeight: mediaCards.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    ColumnLayout {
                        id: mediaCards

                        width: mediaFlickable.width
                        spacing: 8

                        Repeater {
                            model: root.activePlayers

                            delegate: Rectangle {
                                id: mediaCard

                                required property var modelData

                                Layout.fillWidth: true

                                implicitHeight:
                                    mediaCardContent.implicitHeight + 20

                                radius: 15
                                color: root.walSurface
                                border.color: root.walBorder
                                border.width: 1

                                RowLayout {
                                    id: mediaCardContent

                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 66
                                        Layout.preferredHeight: 66

                                        radius: 10
                                        color: root.walSoftSurface
                                        clip: true

                                        Image {
                                            id: coverImage

                                            anchors.fill: parent

                                            source: mediaCard.modelData.artUrl

                                            asynchronous: true
                                            cache: true
                                            fillMode: Image.PreserveAspectCrop

                                            visible: status === Image.Ready
                                        }

                                        Label {
                                            anchors.centerIn: parent

                                            visible:
                                                coverImage.status !== Image.Ready

                                            text: "󰎆"
                                            color: root.walAccent
                                            font.family: root.uiFont
                                            font.pixelSize: 26
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4


Label {
    Layout.fillWidth: true

    text: mediaCard.modelData.status

    color: mediaCard.modelData.status === "Playing"
        ? root.walAccent
        : root.walMuted

    font.family: root.uiFont
    font.pixelSize: 9
}


                                        Label {
                                            Layout.fillWidth: true

                                            text: mediaCard.modelData.title

                                            color: root.walForeground
                                            font.family: root.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold

                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            Layout.fillWidth: true

                                            text: mediaCard.modelData.artist

                                            color: root.walMuted
                                            font.family: root.uiFont
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            Button {
                                                id: previousButton

                                                text: "󰒮"
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                padding: 0

                                                background: Rectangle {
                                                    radius: 13

                                                    color: previousButton.hovered
                                                        ? root.walSoftSurface
                                                        : "transparent"
                                                }

                                                contentItem: Text {
                                                    text: previousButton.text
                                                    color: root.walForeground
                                                    font.family: root.uiFont
                                                    font.pixelSize: 14

                                                    horizontalAlignment:
                                                        Text.AlignHCenter

                                                    verticalAlignment:
                                                        Text.AlignVCenter
                                                }

                                                onClicked: root.runCommand(
                                                    root.mediaControlCommand(
                                                        mediaCard.modelData.player,
                                                        "previous"
                                                    )
                                                )
                                            }


Button {
    id: pauseButton

    text: mediaCard.modelData.status === "Playing"
        ? "󰏤"
        : "󰐊"

    implicitWidth: 30
    implicitHeight: 30
    padding: 0

    background: Rectangle {
        radius: 15
        color: pauseButton.hovered
            ? root.walHover
            : root.walAccent
    }

    contentItem: Text {
        text: pauseButton.text
        color: root.walBackground
        font.family: root.uiFont
        font.pixelSize: 15

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    onClicked: root.runCommand(
        root.mediaControlCommand(
            mediaCard.modelData.player,
            "play-pause"
        )
    )
}


                                            Button {
                                                id: nextButton

                                                text: "󰒭"
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                padding: 0

                                                background: Rectangle {
                                                    radius: 13

                                                    color: nextButton.hovered
                                                        ? root.walSoftSurface
                                                        : "transparent"
                                                }

                                                contentItem: Text {
                                                    text: nextButton.text
                                                    color: root.walForeground
                                                    font.family: root.uiFont
                                                    font.pixelSize: 14

                                                    horizontalAlignment:
                                                        Text.AlignHCenter

                                                    verticalAlignment:
                                                        Text.AlignVCenter
                                                }

                                                onClicked: root.runCommand(
                                                    root.mediaControlCommand(
                                                        mediaCard.modelData.player,
                                                        "next"
                                                    )
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------
            // NOTIFICATIONS HEADER
            // -------------------------------------------------

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    text: "NOTIFICATIONS"
                    color: root.walMuted
                    font.family: root.uiFont
                    font.pixelSize: 9
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    id: clearButton

                    text: "Clear all"

                    enabled:
                        notificationServer.trackedNotifications.count > 0

                    padding: 5

                    background: Rectangle {
                        radius: 8
                        color: clearButton.hovered
                            ? root.walSoftSurface
                            : "transparent"
                    }

                    contentItem: Text {
                        text: clearButton.text

                        color: clearButton.enabled
                            ? root.walAccent
                            : root.walMuted

                        font.family: root.uiFont
                        font.pixelSize: 10

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.clearNotifications()
                }
            }

            // -------------------------------------------------
            // NOTIFICATION LIST
            // -------------------------------------------------

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 70
                clip: true

                ListView {
                    id: notificationList

                    anchors.fill: parent

                    clip: true
                    spacing: 8
                    model: notificationServer.trackedNotifications
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    delegate: Rectangle {
                        id: notificationCard

                        required property var modelData

                        width: notificationList.width
                        radius: 13

                        color: root.walSurface
                        border.color: root.walBorder
                        border.width: 1

                        implicitHeight:
                            notificationContent.implicitHeight + 22

                        ColumnLayout {
                            id: notificationContent

                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 7

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9

                                Rectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36

                                    radius: 10
                                    color: root.walSoftSurface
                                    clip: true

                                    Image {
                                        id: notificationIcon

                                        anchors.fill: parent
                                        anchors.margins: 3

                                        source: {
                                            const n =
                                                notificationCard.modelData

                                            if (n.image && n.image !== "")
                                                return n.image

                                            if (n.appIcon && n.appIcon !== "")
                                                return n.appIcon

                                            return ""
                                        }

                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    Label {
                                        anchors.centerIn: parent

                                        visible:
                                            notificationIcon.status
                                            !== Image.Ready

                                        text: "󰂚"
                                        color: root.walAccent
                                        font.family: root.uiFont
                                        font.pixelSize: 18
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Label {
                                        Layout.fillWidth: true

                                        text:
                                            notificationCard.modelData.appName
                                            || "Notification"

                                        color: root.walAccent
                                        font.family: root.uiFont
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        Layout.fillWidth: true

                                        text:
                                            notificationCard.modelData.summary
                                            || "Notification"

                                        color: root.walForeground
                                        font.family: root.uiFont
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold

                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }
                                }

                                Button {
                                    id: dismissButton

                                    text: "󰅖"
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    padding: 0

                                    background: Rectangle {
                                        radius: 13

                                        color: dismissButton.hovered
                                            ? root.walHover
                                            : "transparent"
                                    }

                                    contentItem: Text {
                                        text: dismissButton.text

                                        color: dismissButton.hovered
                                            ? root.walBackground
                                            : root.walMuted

                                        font.family: root.uiFont
                                        font.pixelSize: 13

                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onClicked:
                                        notificationCard.modelData.dismiss()
                                }
                            }

                            Label {
                                Layout.fillWidth: true

                                visible:
                                    notificationCard.modelData.body
                                    && notificationCard.modelData.body !== ""

                                text:
                                    notificationCard.modelData.body || ""

                                color: root.walForeground
                                font.family: root.uiFont
                                font.pixelSize: 10

                                wrapMode: Text.Wrap
                                maximumLineCount: 6
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: notificationCard.modelData.actions

                                delegate: Button {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: 30

                                    text: modelData.text

                                    background: Rectangle {
                                        radius: 9

                                        color: parent.down
                                            ? root.walAccent
                                            : parent.hovered
                                                ? root.walSoftSurface
                                                : "transparent"

                                        border.color: root.walBorder
                                        border.width: 1
                                    }

                                    contentItem: Text {
                                        text: parent.text

                                        color: parent.down
                                            ? root.walBackground
                                            : root.walForeground

                                        font.family: root.uiFont
                                        font.pixelSize: 10

                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter

                                        elide: Text.ElideRight
                                    }

                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        width: parent.width - 24

                        visible: notificationList.count === 0

                        text: root.doNotDisturb
                            ? "Do Not Disturb is enabled"
                            : "You're all caught up"

                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 11

                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }

            // -------------------------------------------------
            // FOOTER
            // -------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.walBorder
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Label {
                    text: "QS NOTIFICATIONS"
                    color: root.walMuted
                    font.family: root.uiFont
                    font.pixelSize: 9
                }

                Item {
                    Layout.fillWidth: true
                }

                Label {
                    text: root.doNotDisturb
                        ? "󰂛 DND"
                        : "󰂚 ACTIVE"

                    color: root.doNotDisturb
                        ? root.walHover
                        : root.walAccent

                    font.family: root.uiFont
                    font.pixelSize: 9
                }
            }
        }
    }
}
