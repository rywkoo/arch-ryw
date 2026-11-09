import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../theme" as SharedTheme

PanelWindow {
    id: root

    visible: false
    implicitWidth: 300
    implicitHeight: contentColumn.implicitHeight + 24
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
    WlrLayershell.namespace: "bluetooth"
    WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool panelOpen: false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: adapter ? adapter.enabled : false
    readonly property var bluetoothDevices: adapter ? adapter.devices.values : []
    readonly property var namedDevices: bluetoothDevices.filter(function(device) {
        if (!device || !device.name)
            return false
        var deviceName = String(device.name).trim()
        if (deviceName.length === 0 || deviceName === String(device.address || ""))
            return false
        // Ignore anonymous numeric/address-like labels; keep human-readable device names.
        return !/^[0-9:._-]+$/.test(deviceName)
    })
    readonly property string statusText: scanning ? "Searching for nearby devices…" : ""
    readonly property bool scanning: adapter ? adapter.discovering : false

    property color walBackground: SharedTheme.Theme.deep
    property color walForeground: SharedTheme.Theme.ice
    property color walAccent: SharedTheme.Theme.cyan
    property color walHover: SharedTheme.Theme.red
    property color walMuted: SharedTheme.Theme.blue

    readonly property color walSurface: Qt.lighter(walBackground, 1.12)
    readonly property color walBorder: Qt.lighter(walBackground, 1.28)
    readonly property color walSoftSurface: Qt.rgba(
        walForeground.r, walForeground.g, walForeground.b, 0.055
    )
    readonly property string uiFont: SharedTheme.Theme.font

    function openPanel() {
        closeTimer.stop()
        visible = true
        panelOpen = true
        refreshAll()
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

    function refreshAll() {
        // Adapter and device state are updated reactively through BlueZ D-Bus.
    }

    function startScan() {
        if (adapter && adapter.enabled)
            adapter.discovering = true
    }

    function setBluetoothPower(enabled) {
        if (adapter)
            adapter.enabled = enabled
    }

    function toggleDevice(device, connected) {
        if (connected)
            device.disconnect()
        else if (device.paired)
            device.connect()
        else
            device.pair()
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
        name: "bluetooth-toggle"
        description: "Toggle Bluetooth panel"
        onPressed: root.togglePanel()
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { root.togglePanel() }
        function open(): void { root.openPanel() }
        function close(): void { root.closePanel() }
    }

    Item {
        id: drawer
        width: parent.width
        height: root.panelOpen ? root.implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Keys.onEscapePressed: root.closePanel()

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: root.walBackground
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: "bluetooth"
                        color: root.walForeground
                        font.family: root.uiFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "DEVICE CONTROLS"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: root.bluetoothEnabled ? root.walAccent : root.walHover
                }

                Button {
                    text: "×"
                    implicitWidth: 30
                    implicitHeight: 30
                    padding: 0
                    background: Rectangle {
                        radius: 15
                        color: parent.down ? root.walHover
                            : parent.hovered ? root.walSoftSurface : "transparent"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? root.walHover : root.walForeground
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

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: root.walSurface
                border.color: root.walBorder
                border.width: 1
                implicitHeight: bluetoothRow.implicitHeight + 20

                RowLayout {
                    id: bluetoothRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 9

                    Label {
                        text: "󰂯"
                        color: root.walAccent
                        font.family: root.uiFont
                        font.pixelSize: 23
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "Bluetooth"
                            color: root.walForeground
                            font.family: root.uiFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Label {
                            text: root.bluetoothEnabled ? "Bluetooth is powered on" : "Bluetooth is powered off"
                            color: root.walMuted
                            font.family: root.uiFont
                            font.pixelSize: 9
                        }
                    }

                    Button {
                        text: root.bluetoothEnabled ? "On" : "Off"
                        implicitWidth: 54
                        implicitHeight: 30
                        padding: 8
                        font.family: root.uiFont
                        font.pixelSize: 10
                        background: Rectangle {
                            radius: 15
                            color: root.bluetoothEnabled ? root.walAccent : root.walSoftSurface
                            border.color: root.bluetoothEnabled ? root.walAccent : root.walBorder
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: root.bluetoothEnabled ? root.walBackground : root.walMuted
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.setBluetoothPower(!root.bluetoothEnabled)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "DEVICES"
                    color: root.walMuted
                    font.family: root.uiFont
                    font.pixelSize: 10
                    font.bold: true
                    Layout.fillWidth: true
                }
                Button {
                    text: root.scanning ? "Scanning…" : "Scan"
                    enabled: root.bluetoothEnabled && !root.scanning
                    implicitHeight: 27
                    padding: 9
                    font.family: root.uiFont
                    font.pixelSize: 10
                    background: Rectangle {
                        radius: 14
                        color: parent.hovered ? root.walSoftSurface : "transparent"
                        border.color: root.walBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.walForeground
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { if (root.adapter) root.adapter.discovering = !root.adapter.discovering }
                }
            }

            Label {
                visible: !root.bluetoothEnabled
                Layout.fillWidth: true
                text: "Turn Bluetooth on to view known devices."
                color: root.walMuted
                font.family: root.uiFont
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.preferredHeight: root.bluetoothEnabled
                    ? Math.min(contentHeight, 160) : 0
                clip: true
                spacing: 5
                model: root.namedDevices

                delegate: Rectangle {
                    width: deviceList.width
                    height: deviceRow.implicitHeight + 14
                    radius: 10
                    color: root.walSoftSurface
                    border.color: root.walBorder
                    border.width: 1

                    RowLayout {
                        id: deviceRow
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: modelData.name || "Bluetooth device"
                                color: root.walForeground
                                font.family: root.uiFont
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: modelData.address + (modelData.connected ? " · Connected" : "")
                                color: root.walMuted
                                font.family: root.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            text: modelData.connected ? "Disconnect" : "Connect"
                            enabled: root.bluetoothEnabled
                            implicitHeight: 28
                            padding: 8
                            font.family: root.uiFont
                            font.pixelSize: 9
                            background: Rectangle {
                                radius: 14
                                color: parent.hovered ? root.walSoftSurface : "transparent"
                                border.color: root.walBorder
                                border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text
                                color: root.walForeground
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.toggleDevice(modelData, modelData.connected)
                        }
                    }
                }
            }

            Label {
                visible: root.bluetoothEnabled && root.namedDevices.length === 0
                Layout.fillWidth: true
                text: "No named devices detected yet. Press Scan and make sure nearby devices are discoverable."
                color: root.walMuted
                font.family: root.uiFont
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }

            Label {
                visible: root.statusText.length > 0
                Layout.fillWidth: true
                text: root.statusText
                color: root.walAccent
                font.family: root.uiFont
                font.pixelSize: 9
                wrapMode: Text.WordWrap
            }
        }
    }
}
