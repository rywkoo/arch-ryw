
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

import "../../theme" as SharedTheme
PanelWindow {
    id: root

    visible: false
    implicitWidth: (showOutputs || showInputs) ? 620 : 360
    implicitHeight: 680
    color: "transparent"
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
    WlrLayershell.namespace: "audiomixer"

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    property bool panelOpen: false
    property bool showOutputs: false
    property bool showInputs: false

    property color walBackground: SharedTheme.Theme.deep
    property color walForeground: SharedTheme.Theme.ice
    property color walAccent: SharedTheme.Theme.cyan
    property color walHover: SharedTheme.Theme.red
    property color walMuted: SharedTheme.Theme.blue

    readonly property color walSurface:
        Qt.lighter(walBackground, 1.12)

    readonly property color walBorder:
        Qt.lighter(walBackground, 1.28)

    readonly property color walSoftSurface:
        Qt.rgba(
            walForeground.r,
            walForeground.g,
            walForeground.b,
            0.055
        )

    readonly property string uiFont: SharedTheme.Theme.font

    function openPanel() {
        closeTimer.stop()
        visible = true
        panelOpen = true
    }

    function closePanel() {
        if (!visible || !panelOpen)
            return

        panelOpen = false
        closeTimer.restart()
    }

    function togglePanel() {
        if (panelOpen)
            closePanel()
        else
            openPanel()
    }

    function streamCount() {
        let count = 0

        for (let i = 0; i < Pipewire.nodes.count; i++) {
            const node = Pipewire.nodes.get(i)

            if (node.isStream && node.audio !== null)
                count++
        }

        return count
    }

    Timer {
        id: closeTimer
        interval: 340
        repeat: false

        onTriggered: {
            if (!root.panelOpen)
                root.visible = false
        }
    }

    GlobalShortcut {
        name: "audiomixer-toggle"
        description: "Toggle the audio mixer"

        onPressed: root.togglePanel()
    }

    IpcHandler {
        target: "audiomixer"

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

    PwObjectTracker {
        objects: [
            Pipewire.defaultAudioSink,
            Pipewire.defaultAudioSource
        ]
    }

    // Main drawer
	Item {
	    id: drawer

	    width: parent.width
	    height: root.panelOpen ? root.implicitHeight : 0
	    x: 0
	    y: 0
	    clip: true

	    Behavior on height {
		NumberAnimation {
		    duration: 300
		    easing.type: Easing.OutCubic
		}
	    }

        Keys.onEscapePressed: root.closePanel()

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.walBackground
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 9

            // HEADER
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: "audiomixer"
                        color: root.walForeground
                        font.family: root.uiFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: "SYSTEM AUDIO"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: Pipewire.ready
                        ? root.walAccent
                        : root.walHover
                }

                Button {
                    text: "×"
                    implicitWidth: 30
                    implicitHeight: 30
                    padding: 0

                    background: Rectangle {
                        radius: 15
                        color: parent.down
                            ? root.walHover
                            : parent.hovered
                                ? root.walSoftSurface
                                : "transparent"
                    }

                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered
                            ? root.walHover
                            : root.walForeground
                        font.family: root.uiFont
                        font.pixelSize: 21
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

            // OUTPUT SECTION
            Label {
                text: "OUTPUT"
                color: root.walMuted
                font.family: root.uiFont
                font.pixelSize: 10
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: root.walSurface
                border.color: root.walBorder
                border.width: 1
                implicitHeight: outputColumn.implicitHeight + 20

                ColumnLayout {
                    id: outputColumn

                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Label {
                            text: "󰕾"
                            color: root.walAccent
                            font.family: root.uiFont
                            font.pixelSize: 23
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: "Master volume"
                                color: root.walForeground
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true

                                text: Pipewire.defaultAudioSink
                                    ? (
                                        Pipewire.defaultAudioSink.description
                                        || Pipewire.defaultAudioSink.name
                                    )
                                    : "No output device"

                                color: root.walMuted
                                font.family: root.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        Label {
                            text: Pipewire.defaultAudioSink?.audio
                                ? Math.round(
                                    Pipewire.defaultAudioSink.audio.volume * 100
                                  ) + "%"
                                : "--"

                            color: root.walForeground
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                    }

                    Slider {
                        id: masterSlider

                        Layout.fillWidth: true
                        implicitHeight: 24
                        from: 0
			to: 1

                        value: Pipewire.defaultAudioSink?.audio
                            ? Pipewire.defaultAudioSink.audio.volume
                            : 0

                        enabled: !!Pipewire.defaultAudioSink?.audio

                        onMoved: {
                            const audio = Pipewire.defaultAudioSink?.audio
                            if (audio)
                                audio.volume = value
                        }

                        background: Rectangle {
                            x: masterSlider.leftPadding
                            y: masterSlider.topPadding
                                + masterSlider.availableHeight / 2
                                - height / 2

                            width: masterSlider.availableWidth
                            height: 7
                            radius: 4
                            color: root.walSoftSurface

                            Rectangle {
                                width: masterSlider.visualPosition
                                    * parent.width
                                height: parent.height
                                radius: 4
                                color: root.walAccent
                            }
                        }

                        handle: Rectangle {
                            x: masterSlider.leftPadding
                                + masterSlider.visualPosition
                                * (
                                    masterSlider.availableWidth - width
                                  )

                            y: masterSlider.topPadding
                                + masterSlider.availableHeight / 2
                                - height / 2

                            width: 12
                            height: 12
                            radius: 6

                            color: masterSlider.pressed
                                ? root.walHover
                                : root.walForeground
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Button {
                            text: Pipewire.defaultAudioSink?.audio?.muted
                                ? "󰖁  Unmute"
                                : "󰕾  Mute"

                            implicitHeight: 30
                            padding: 9
                            font.family: root.uiFont
                            font.pixelSize: 10

                            background: Rectangle {
                                radius: 15
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
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                const audio = Pipewire.defaultAudioSink?.audio
                                if (audio)
                                    audio.muted = !audio.muted
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            text: root.showOutputs
                                ? "Hide ↑"
                                : "Devices ↓"

                            implicitHeight: 30
                            padding: 9
                            font.family: root.uiFont
                            font.pixelSize: 10

                            background: Rectangle {
                                radius: 15
                                color: parent.hovered
                                    ? root.walSoftSurface
                                    : "transparent"
                            }

                            contentItem: Text {
                                text: parent.text
                                color: root.walAccent
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                root.showOutputs = !root.showOutputs
                            }
                        }
                    }

                    // OUTPUT DEVICE LIST: INDEPENDENT SCROLL
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: root.showOutputs ? 126 : 0
                        clip: true

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }

                        ScrollView {
                            anchors.fill: parent
                            clip: true
                            contentWidth: availableWidth

                            ScrollBar.horizontal.policy:
                                ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: Pipewire.nodes

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: visible ? 34 : 0
                                        radius: 8

                                        visible: modelData.isSink
                                            && !modelData.isStream

                                        color: Pipewire.defaultAudioSink
                                            === modelData
                                            ? root.walSoftSurface
                                            : "transparent"

                                        PwObjectTracker {
                                            objects: [modelData]
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 6
                                            spacing: 6

                                            Label {
                                                Layout.fillWidth: true

                                                text: (
                                                    Pipewire.defaultAudioSink
                                                    === modelData ? "✓  " : ""
                                                ) + (
                                                    modelData.description
                                                    || modelData.name
                                                )

                                                color: Pipewire.defaultAudioSink
                                                    === modelData
                                                    ? root.walAccent
                                                    : root.walForeground

                                                font.family: root.uiFont
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: "›"
                                                color: root.walMuted
                                                font.family: root.uiFont
                                                font.pixelSize: 17
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent

                                            onClicked: {
                                                Pipewire.preferredDefaultAudioSink =
                                                    modelData

                                                root.showOutputs = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // INPUT SECTION
            Label {
                text: "INPUT"
                color: root.walMuted
                font.family: root.uiFont
                font.pixelSize: 10
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: root.walSurface
                border.color: root.walBorder
                border.width: 1
                implicitHeight: inputColumn.implicitHeight + 20

                ColumnLayout {
                    id: inputColumn

                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Label {
                            text: "󰍬"
                            color: root.walAccent
                            font.family: root.uiFont
                            font.pixelSize: 23
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Label {
                                text: "Microphone"
                                color: root.walForeground
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Label {
                                Layout.fillWidth: true

                                text: Pipewire.defaultAudioSource
                                    ? (
                                        Pipewire.defaultAudioSource.description
                                        || Pipewire.defaultAudioSource.name
                                    )
                                    : "No input device"

                                color: root.walMuted
                                font.family: root.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        Label {
                            text: Pipewire.defaultAudioSource?.audio
                                ? Math.round(
                                    Pipewire.defaultAudioSource.audio.volume * 100
                                  ) + "%"
                                : "--"

                            color: root.walForeground
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                    }

                    Slider {
                        id: micSlider

                        Layout.fillWidth: true
                        implicitHeight: 24
                        from: 0
                        to: 1

                        value: Pipewire.defaultAudioSource?.audio
                            ? Pipewire.defaultAudioSource.audio.volume
                            : 0

                        enabled: !!Pipewire.defaultAudioSource?.audio

                        onMoved: {
                            const audio = Pipewire.defaultAudioSource?.audio
                            if (audio)
                                audio.volume = value
                        }

                        background: Rectangle {
                            x: micSlider.leftPadding
                            y: micSlider.topPadding
                                + micSlider.availableHeight / 2
                                - height / 2

                            width: micSlider.availableWidth
                            height: 7
                            radius: 4
                            color: root.walSoftSurface

                            Rectangle {
                                width: micSlider.visualPosition
                                    * parent.width
                                height: parent.height
                                radius: 4
                                color: root.walAccent
                            }
                        }

                        handle: Rectangle {
                            x: micSlider.leftPadding
                                + micSlider.visualPosition
                                * (
                                    micSlider.availableWidth - width
                                  )

                            y: micSlider.topPadding
                                + micSlider.availableHeight / 2
                                - height / 2

                            width: 12
                            height: 12
                            radius: 6

                            color: micSlider.pressed
                                ? root.walHover
                                : root.walForeground
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Button {
                            text: Pipewire.defaultAudioSource?.audio?.muted
                                ? "󰍭  Unmute"
                                : "󰍬  Mute mic"

                            implicitHeight: 30
                            padding: 9
                            font.family: root.uiFont
                            font.pixelSize: 10

                            background: Rectangle {
                                radius: 15
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
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                const audio = Pipewire.defaultAudioSource?.audio
                                if (audio)
                                    audio.muted = !audio.muted
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            text: root.showInputs
                                ? "Hide ↑"
                                : "Devices ↓"

                            implicitHeight: 30
                            padding: 9
                            font.family: root.uiFont
                            font.pixelSize: 10

                            background: Rectangle {
                                radius: 15
                                color: parent.hovered
                                    ? root.walSoftSurface
                                    : "transparent"
                            }

                            contentItem: Text {
                                text: parent.text
                                color: root.walAccent
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                root.showInputs = !root.showInputs
                            }
                        }
                    }

                    // INPUT DEVICE LIST: INDEPENDENT SCROLL
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: root.showInputs ? 126 : 0
                        clip: true

                        Behavior on implicitHeight {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }

                        ScrollView {
                            anchors.fill: parent
                            clip: true
                            contentWidth: availableWidth

                            ScrollBar.horizontal.policy:
                                ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: Pipewire.nodes

                                    delegate: Rectangle {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: visible ? 34 : 0
                                        radius: 8

                                        visible: !modelData.isSink
                                            && !modelData.isStream

                                        color: Pipewire.defaultAudioSource
                                            === modelData
                                            ? root.walSoftSurface
                                            : "transparent"

                                        PwObjectTracker {
                                            objects: [modelData]
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 6
                                            spacing: 6

                                            Label {
                                                Layout.fillWidth: true

                                                text: (
                                                    Pipewire.defaultAudioSource
                                                    === modelData ? "✓  " : ""
                                                ) + (
                                                    modelData.description
                                                    || modelData.name
                                                )

                                                color: Pipewire.defaultAudioSource
                                                    === modelData
                                                    ? root.walAccent
                                                    : root.walForeground

                                                font.family: root.uiFont
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                text: "›"
                                                color: root.walMuted
                                                font.family: root.uiFont
                                                font.pixelSize: 17
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent

                                            onClicked: {
                                                Pipewire.preferredDefaultAudioSource =
                                                    modelData

                                                root.showInputs = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // APPLICATIONS HEADING
            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "APPLICATIONS"
                    color: root.walMuted
                    font.family: root.uiFont
                    font.pixelSize: 10
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Label {
                    text: root.streamCount() + " streams"
                    color: root.walAccent
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
            }

            // APPLICATIONS HAVE THEIR OWN SCROLL AREA
            ScrollView {
                id: applicationsScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 90
                clip: true

                contentWidth: availableWidth

                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: applicationsScroll.availableWidth
                    spacing: 8

                    Repeater {
                        model: Pipewire.nodes

                        delegate: Rectangle {
                            id: appRow

                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: visible
                                ? appColumn.implicitHeight + 18
                                : 0

                            radius: 12
                            color: root.walSurface
                            border.color: root.walBorder
                            border.width: 1

                            visible: modelData.isStream
                                && modelData.audio !== null

                            PwObjectTracker {
                                objects: [appRow.modelData]
                            }

                            ColumnLayout {
                                id: appColumn

                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Label {
                                        text: "󰎆"
                                        color: root.walAccent
                                        font.family: root.uiFont
                                        font.pixelSize: 18
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Label {
                                            Layout.fillWidth: true

                                            text: appRow.modelData.description
                                                || appRow.modelData.name

                                            color: root.walForeground
                                            font.family: root.uiFont
                                            font.pixelSize: 10
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: appRow.modelData.audio?.muted
                                                ? "MUTED"
                                                : "PLAYBACK"

                                            color: appRow.modelData.audio?.muted
                                                ? root.walHover
                                                : root.walMuted

                                            font.family: root.uiFont
                                            font.pixelSize: 8
                                        }
                                    }

                                    Label {
                                        text: appRow.modelData.audio
                                            ? Math.round(
                                                appRow.modelData.audio.volume * 100
                                              ) + "%"
                                            : "--"

                                        color: root.walForeground
                                        font.family: root.uiFont
                                        font.pixelSize: 10
                                    }

                                    Button {
                                        text: appRow.modelData.audio?.muted
                                            ? "󰝟"
                                            : "󰕾"

                                        implicitWidth: 30
                                        implicitHeight: 28
                                        padding: 0
                                        font.family: root.uiFont
                                        font.pixelSize: 15

                                        background: Rectangle {
                                            radius: 14
                                            color: parent.down
                                                ? root.walAccent
                                                : parent.hovered
                                                    ? root.walSoftSurface
                                                    : "transparent"
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

                                        onClicked: {
                                            const audio = appRow.modelData.audio
                                            if (audio)
                                                audio.muted = !audio.muted
                                        }
                                    }
                                }

                                Slider {
                                    id: appSlider

                                    Layout.fillWidth: true
                                    implicitHeight: 20
                                    from: 0
                                    to: 1

                                    value: appRow.modelData.audio
                                        ? appRow.modelData.audio.volume
                                        : 0

                                    enabled: !!appRow.modelData.audio

                                    onMoved: {
                                        const audio = appRow.modelData.audio
                                        if (audio)
                                            audio.volume = value
                                    }

                                    background: Rectangle {
                                        x: appSlider.leftPadding
                                        y: appSlider.topPadding
                                            + appSlider.availableHeight / 2
                                            - height / 2

                                        width: appSlider.availableWidth
                                        height: 6
                                        radius: 3
                                        color: root.walSoftSurface

                                        Rectangle {
                                            width: appSlider.visualPosition
                                                * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: root.walAccent
                                        }
                                    }

                                    handle: Rectangle {
                                        x: appSlider.leftPadding
                                            + appSlider.visualPosition
                                            * (
                                                appSlider.availableWidth - width
                                              )

                                        y: appSlider.topPadding
                                            + appSlider.availableHeight / 2
                                            - height / 2

                                        width: 10
                                        height: 10
                                        radius: 5

                                        color: appSlider.pressed
                                            ? root.walHover
                                            : root.walForeground
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true

                        visible: root.streamCount() === 0
                        text: "No audio streams detected."

                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 10

                        horizontalAlignment: Text.AlignHCenter
                        Layout.topMargin: 4
                        Layout.bottomMargin: 8
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.walBorder
            }

            // FOOTER
            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "AUDIO MIXER"
                    color: root.walMuted
                    font.family: root.uiFont
                    font.pixelSize: 9
                }

                Item {
                    Layout.fillWidth: true
                }

                Label {
                    text: Pipewire.ready
                        ? "CONNECTED"
                        : "CONNECTING"

                    color: Pipewire.ready
                        ? root.walAccent
                        : root.walMuted

                    font.family: root.uiFont
                    font.pixelSize: 9
                }
            }
        }
    }
}
