import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../theme" as SharedTheme

PanelWindow {
    id: root

    visible: false
    implicitWidth: 310
    implicitHeight: contentColumn.implicitHeight + 32
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
    WlrLayershell.namespace: "connectivity"
    WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool panelOpen: false
    property bool wifiEnabled: false
    property bool ethernetConnected: false
    property bool confirmingEthernetDisconnect: false
    property string ethernetName: ""
    property string ethernetDevice: ""
    property string activeConnectionName: ""
    property string activeConnectionDevice: ""
    property string dnsMode: "auto"
    property string dnsIpv4Primary: ""
    property string dnsIpv4Alternative: ""
    property string dnsIpv6Primary: ""
    property string dnsIpv6Alternative: ""
    property bool dnsTouched: false
    property string connectedWifi: "Not connected"
    property var wifiNetworks: []
    property string selectedSSID: ""
    property string selectedSecurity: ""
    property string password: ""
    property string statusText: ""
    property bool connecting: false

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

    function splitNmcliLine(line) {
        let fields = []
        let field = ""
        let escaped = false
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escaped) {
                field += ch
                escaped = false
            } else if (ch === "\\") {
                escaped = true
            } else if (ch === ":") {
                fields.push(field)
                field = ""
            } else {
                field += ch
            }
        }
        if (escaped)
            field += "\\"
        fields.push(field)
        return fields
    }

    function refreshAll() {
        ethernetProcess.command = [
            "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"
        ]
        ethernetProcess.running = true

        wifiStatusProcess.command = ["nmcli", "radio", "wifi"]
        wifiStatusProcess.running = true

        wifiConnectionProcess.command = [
            "nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"
        ]
        wifiConnectionProcess.running = true


        refreshNetworks()
    }

    function refreshNetworks() {
        if (!wifiEnabled)
            return
        wifiListProcess.command = [
            "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "--rescan", "yes"
        ]
        wifiListProcess.running = true
    }

    function connectWifi(ssid, security, pass) {
        if (!ssid)
            return
        let command = ["nmcli", "--wait", "30", "device", "wifi", "connect", ssid]
        if (security && security !== "--") {
            if (!pass) {
                selectedSSID = ssid
                selectedSecurity = security
                password = ""
                passwordDialog.open()
                return
            }
            command.push("password", pass)
        }
        connecting = true
        statusText = "Connecting to " + ssid + "…"
        wifiActionProcess.command = command
        wifiActionProcess.running = true
    }

    function setWifiPower(enabled) {
        wifiActionProcess.command = ["nmcli", "radio", "wifi", enabled ? "on" : "off"]
        wifiActionProcess.running = true
    }

    function disconnectEthernet() {
        if (!ethernetConnected || !ethernetDevice)
            return
        confirmingEthernetDisconnect = false
        ethernetActionProcess.command = ["nmcli", "device", "disconnect", ethernetDevice]
        ethernetActionProcess.running = true
        statusText = "Disconnecting Ethernet…"
    }

    function applyDnsSettings() {
        if (!activeConnectionName || !dnsTouched)
            return
        const ipv4 = [dnsIpv4Primary.trim(), dnsIpv4Alternative.trim()]
            .filter(value => value.length > 0).join(",")
        const ipv6 = [dnsIpv6Primary.trim(), dnsIpv6Alternative.trim()]
            .filter(value => value.length > 0).join(",")
        dnsActionProcess.command = [
            "nmcli", "connection", "modify", activeConnectionName,
            "ipv4.ignore-auto-dns", "yes", "ipv4.dns", ipv4,
            "ipv6.ignore-auto-dns", "yes", "ipv6.dns", ipv6
        ]
        dnsActionProcess.running = true
        statusText = "Applying custom DNS…"
    }

    function setDnsMode(mode) {
        dnsMode = mode
        if (mode === "auto") {
            dnsTouched = false
            if (activeConnectionName) {
                dnsActionProcess.command = [
                    "nmcli", "connection", "modify", activeConnectionName,
                    "ipv4.ignore-auto-dns", "no", "ipv4.dns", "",
                    "ipv6.ignore-auto-dns", "no", "ipv6.dns", ""
                ]
                dnsActionProcess.running = true
                statusText = "Restoring automatic DNS…"
            }
        } else {
            dnsTouched = false
        }
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
        name: "connectivity-toggle"
        description: "Toggle network panel"
        onPressed: root.togglePanel()
    }

    IpcHandler {
        target: "connectivity"
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
                        text: "connectivity"
                        color: root.walForeground
                        font.family: root.uiFont
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: "NETWORK CONTROLS"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: root.wifiEnabled ? root.walAccent : root.walHover
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

            // Ethernet is intentionally shown only when a wired connection is active.
            Rectangle {
                Layout.fillWidth: true
                visible: true
                radius: 14
                color: root.walSurface
                border.color: root.walBorder
                border.width: 1
                implicitHeight: ethernetRow.implicitHeight + 16

                RowLayout {
                    id: ethernetRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 7

                    Label {
                        text: "󰈀"
                        color: root.walAccent
                        font.family: root.uiFont
                        font.pixelSize: 23
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: root.ethernetConnected ? "Ethernet" : "Ethernet · Disconnected"
                            color: root.walForeground
                            font.family: root.uiFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Label {
                            text: root.ethernetConnected ? (root.ethernetName || root.ethernetDevice || "Wired connection") : "No active wired connection"
                            color: root.walMuted
                            font.family: root.uiFont
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    Button {
                        text: root.confirmingEthernetDisconnect ? "Cancel" : "Disconnect"
                        implicitHeight: 30
                        padding: 9
                        font.family: root.uiFont
                        font.pixelSize: 10
                        background: Rectangle {
                            radius: 15
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
                        onClicked: { if (root.confirmingEthernetDisconnect) root.confirmingEthernetDisconnect = false; else root.confirmingEthernetDisconnect = true }
                    }

                    Button {
                        visible: root.ethernetConnected && root.confirmingEthernetDisconnect
                        text: "Okay"
                        implicitHeight: 30
                        padding: 9
                        font.family: root.uiFont
                        font.pixelSize: 10
                        background: Rectangle {
                            radius: 15
                            color: root.walAccent
                        }
                        contentItem: Text {
                            text: parent.text
                            color: root.walBackground
                            font: parent.font
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: root.disconnectEthernet()
                    }
                }
            }

            Label {
                text: "NETWORK"
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
                implicitHeight: wifiColumn.implicitHeight + 16

                ColumnLayout {
                    id: wifiColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 9

                        Label {
                            text: "󰤨"
                            color: root.walAccent
                            font.family: root.uiFont
                            font.pixelSize: 23
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: "Wi-Fi"
                                color: root.walForeground
                                font.family: root.uiFont
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Label {
                                text: root.connectedWifi
                                color: root.walMuted
                                font.family: root.uiFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }

                        Button {
                            text: "↻"
                            enabled: root.wifiEnabled
                            implicitWidth: 30
                            implicitHeight: 30
                            padding: 0
                            background: Rectangle {
                                radius: 15
                                color: parent.hovered ? root.walSoftSurface : "transparent"
                            }
                            contentItem: Text {
                                text: parent.text
                                color: root.walAccent
                                font.family: root.uiFont
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.refreshNetworks()
                        }

                        Button {
                            text: root.wifiEnabled ? "On" : "Off"
                            implicitWidth: 54
                            implicitHeight: 29
                            padding: 0
                            font.family: root.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            background: Rectangle {
                                radius: 15
                                color: root.wifiEnabled ? root.walAccent : root.walSoftSurface
                                border.color: root.wifiEnabled ? root.walAccent : root.walBorder
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 140 } }
                            }
                            contentItem: Text {
                                text: parent.text
                                color: root.wifiEnabled ? root.walBackground : root.walMuted
                                font: parent.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: root.setWifiPower(!root.wifiEnabled)
                            Accessible.name: root.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
                        }
                    }

                    Label {
                        visible: !root.wifiEnabled
                        text: "Wi-Fi is turned off"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 10
                    }

                    Label {
                        visible: root.wifiEnabled
                        text: "AVAILABLE NETWORKS"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 9
                        font.bold: true
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: root.wifiEnabled
                            ? Math.min(wifiListView.contentHeight, 84) : 0
                        clip: true

                        ListView {
                            id: wifiListView
                            anchors.fill: parent
                            clip: true
                            spacing: 3
                            model: root.wifiNetworks

                            delegate: Rectangle {
                                required property var modelData
                                width: ListView.view.width

                                height: 38
                                radius: 8
                                color: wifiMouse.containsMouse
                                    ? root.walSoftSurface : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 7
                                    spacing: 7
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Label {
                                            text: modelData.ssid
                                            color: root.walForeground
                                            font.family: root.uiFont
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            text: modelData.security || "Open network"
                                            color: root.walMuted
                                            font.family: root.uiFont
                                            font.pixelSize: 8
                                        }
                                    }
                                    RowLayout {
                                        Layout.preferredWidth: 58
                                        Layout.alignment: Qt.AlignRight
                                        spacing: 5
                                        Label {
                                            Layout.preferredWidth: 30
                                            text: modelData.signal + "%"
                                            color: root.walMuted
                                            font.family: root.uiFont
                                            font.pixelSize: 9
                                            horizontalAlignment: Text.AlignRight
                                        }
                                        Label {
                                            Layout.preferredWidth: 16
                                            text: modelData.active ? "✓" : "›"
                                            color: modelData.active ? root.walAccent : root.walForeground
                                            font.family: root.uiFont
                                            font.pixelSize: 15
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }
                                MouseArea {
                                    id: wifiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!modelData.active)
                                            root.connectWifi(modelData.ssid, modelData.security, "")
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        visible: root.wifiEnabled && root.wifiNetworks.length === 0
                        text: "No networks found. Refresh to scan."
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 9
                    }
                }
            }

            Label {
                text: "DNS"
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
                implicitHeight: dnsColumn.implicitHeight + 16

                ColumnLayout {
                    id: dnsColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: "DNS configuration"
                            color: root.walForeground
                            font.family: root.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        ComboBox {
                            id: dnsModeBox
                            model: ["Auto", "Custom"]
                            currentIndex: root.dnsMode === "custom" ? 1 : 0
                            implicitWidth: 112
                            implicitHeight: 30
                            font.family: root.uiFont
                            font.pixelSize: 10
                            onActivated: root.setDnsMode(currentIndex === 0 ? "auto" : "custom")
                            background: Rectangle {
                                radius: 9
                                color: root.walSoftSurface
                                border.color: root.walBorder
                            }
                            contentItem: Text {
                                leftPadding: 9
                                rightPadding: 22
                                text: dnsModeBox.displayText
                                color: root.walForeground
                                font: dnsModeBox.font
                                verticalAlignment: Text.AlignVCenter
                            }
                            indicator: Text {
                                x: dnsModeBox.width - width - 9
                                y: (dnsModeBox.height - height) / 2
                                text: "⌄"
                                color: root.walAccent
                                font.family: root.uiFont
                                font.pixelSize: 16
                            }
                            delegate: ItemDelegate {
                                width: dnsModeBox.width
                                height: 34
                                highlighted: dnsModeBox.highlightedIndex === index
                                contentItem: Text {
                                    text: modelData
                                    color: highlighted ? root.walAccent : root.walForeground
                                    font.family: root.uiFont
                                    font.pixelSize: 10
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 10
                                }
                                background: Rectangle {
                                    radius: 7
                                    color: parent.highlighted ? root.walSoftSurface : "transparent"
                                }
                            }
                            popup: Popup {
                                y: dnsModeBox.height + 4
                                width: dnsModeBox.width
                                padding: 5
                                background: Rectangle {
                                    color: root.walBackground
                                    radius: 10
                                    border.color: root.walBorder
                                }
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: dnsModeBox.popup.visible ? dnsModeBox.delegateModel : null
                                    currentIndex: dnsModeBox.highlightedIndex
                                }
                            }
                        }
                    }

                    Label {
                        visible: root.dnsMode === "auto"
                        text: root.activeConnectionName
                            ? "Using automatic DNS for " + root.activeConnectionName
                            : "Connect to a network to configure DNS"
                        color: root.walMuted
                        font.family: root.uiFont
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    GridLayout {
                        visible: root.dnsMode === "custom"
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 7
                        rowSpacing: 6

                        Label { text: "IPv4 · Primary"; color: root.walMuted; font.family: root.uiFont; font.pixelSize: 9 }
                        Label { text: "IPv4 · Alternative"; color: root.walMuted; font.family: root.uiFont; font.pixelSize: 9 }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Primary IPv4 DNS"
                            text: root.dnsIpv4Primary
                            focusPolicy: Qt.StrongFocus
                            activeFocusOnTab: true
                            selectByMouse: true
                            font.family: root.uiFont; font.pixelSize: 10
                            color: root.walForeground
                            placeholderTextColor: root.walMuted
                            onTextEdited: { root.dnsIpv4Primary = text; root.dnsTouched = true; dnsApplyTimer.restart() }
                            background: Rectangle { radius: 8; color: root.walSoftSurface; border.color: parent.activeFocus ? root.walAccent : root.walBorder; border.width: parent.activeFocus ? 1.5 : 1 }
                        }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Alternative IPv4 DNS"
                            text: root.dnsIpv4Alternative
                            focusPolicy: Qt.StrongFocus
                            activeFocusOnTab: true
                            selectByMouse: true
                            font.family: root.uiFont; font.pixelSize: 10
                            color: root.walForeground
                            placeholderTextColor: root.walMuted
                            onTextEdited: { root.dnsIpv4Alternative = text; root.dnsTouched = true; dnsApplyTimer.restart() }
                            background: Rectangle { radius: 8; color: root.walSoftSurface; border.color: parent.activeFocus ? root.walAccent : root.walBorder; border.width: parent.activeFocus ? 1.5 : 1 }
                        }
                        Label { text: "IPv6 · Primary"; color: root.walMuted; font.family: root.uiFont; font.pixelSize: 9 }
                        Label { text: "IPv6 · Alternative"; color: root.walMuted; font.family: root.uiFont; font.pixelSize: 9 }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Primary IPv6 DNS"
                            text: root.dnsIpv6Primary
                            focusPolicy: Qt.StrongFocus
                            activeFocusOnTab: true
                            selectByMouse: true
                            font.family: root.uiFont; font.pixelSize: 10
                            color: root.walForeground
                            placeholderTextColor: root.walMuted
                            onTextEdited: { root.dnsIpv6Primary = text; root.dnsTouched = true; dnsApplyTimer.restart() }
                            background: Rectangle { radius: 8; color: root.walSoftSurface; border.color: parent.activeFocus ? root.walAccent : root.walBorder; border.width: parent.activeFocus ? 1.5 : 1 }
                        }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: "Alternative IPv6 DNS"
                            text: root.dnsIpv6Alternative
                            focusPolicy: Qt.StrongFocus
                            activeFocusOnTab: true
                            selectByMouse: true
                            font.family: root.uiFont; font.pixelSize: 10
                            color: root.walForeground
                            placeholderTextColor: root.walMuted
                            onTextEdited: { root.dnsIpv6Alternative = text; root.dnsTouched = true; dnsApplyTimer.restart() }
                            background: Rectangle { radius: 8; color: root.walSoftSurface; border.color: parent.activeFocus ? root.walAccent : root.walBorder; border.width: parent.activeFocus ? 1.5 : 1 }
                        }
                    }
                }
            }

        }
    }

    Dialog {
        id: passwordDialog
        title: "Connect to " + root.selectedSSID
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        width: 320
        padding: 16

        header: Label {
            text: passwordDialog.title
            color: root.walForeground
            font.family: root.uiFont
            font.pixelSize: 14
            font.weight: Font.DemiBold
            padding: 14
        }

        background: Rectangle {
            color: root.walBackground
            radius: 18
            border.color: root.walBorder
        }

        contentItem: ColumnLayout {
            spacing: 8
            Label {
                text: "Network password"
                color: root.walForeground
                font.family: root.uiFont
                font.pixelSize: 10
            }
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Enter password"
                echoMode: TextInput.Password
                text: root.password
                onTextChanged: root.password = text
            }
        }

        onAccepted: root.connectWifi(root.selectedSSID, root.selectedSecurity, root.password)
    }

    Timer {
        id: dnsApplyTimer
        interval: 550
        repeat: false
        onTriggered: root.applyDnsSettings()
    }

    Process {
        id: dnsProfileReadProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split("\n")
                if (values.length >= 4) {
                    root.dnsIpv4Primary = values[0].split(",").filter(v => v.trim().length > 0)[0] || ""
                    const ipv4 = values[0].split(",").filter(v => v.trim().length > 0)
                    root.dnsIpv4Primary = ipv4[0] || ""
                    root.dnsIpv4Alternative = ipv4[1] || ""
                    const ipv6 = values[2].split(",").filter(v => v.trim().length > 0)
                    root.dnsIpv6Primary = ipv6[0] || ""
                    root.dnsIpv6Alternative = ipv6[1] || ""
                    root.dnsMode = (values[1].trim() === "yes" || values[3].trim() === "yes") ? "custom" : "auto"
                    root.dnsTouched = false
                }
            }
        }
    }

    Process {
        id: dnsActionProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.statusText = text.trim() || "DNS updated"
        }
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) root.statusText = text.trim() }
        }
        onExited: {
            if (root.activeConnectionDevice) {
                dnsReapplyProcess.command = ["nmcli", "device", "reapply", root.activeConnectionDevice]
                dnsReapplyProcess.running = true
            } else {
                root.refreshAll()
            }
        }
    }

    Process {
        id: dnsReapplyProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.statusText = text.trim()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.statusText = text.trim()
            }
        }
        onExited: root.refreshAll()
    }

    Process {
        id: ethernetProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                let isConnected = false
                let connectionName = ""
                let deviceName = ""
                const lines = text.trim().split("\n")
                for (const line of lines) {
                    const fields = root.splitNmcliLine(line)
                    // NetworkManager may report "connected (externally)" too.
                    if (fields.length >= 4 && fields[1].toLowerCase() === "ethernet"
                            && fields[2].toLowerCase().startsWith("connected")) {
                        isConnected = true
                        deviceName = fields[0]
                        connectionName = fields[3] || fields[0]
                        break
                    }
                }
                root.ethernetConnected = isConnected
                root.ethernetName = connectionName
                root.ethernetDevice = deviceName
                if (isConnected) {
                    root.activeConnectionName = connectionName
                    root.activeConnectionDevice = deviceName
                    dnsProfileReadProcess.command = ["nmcli", "-g", "ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns,ipv6.ignore-auto-dns", "connection", "show", connectionName]
                    dnsProfileReadProcess.running = true
                } else {
                    // Re-read active profiles so an active Wi-Fi profile replaces stale Ethernet state.
                    wifiConnectionProcess.command = [
                        "nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"
                    ]
                    wifiConnectionProcess.running = true
                }
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: wifiConnectionProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                let active = "Not connected"
                let profile = ""
                const lines = text.trim().split("\n")
                for (const line of lines) {
                    const fields = root.splitNmcliLine(line)
                    if (fields.length >= 3 && fields[1] === "802-11-wireless") {
                        active = fields[0] || "Connected"
                        profile = fields[0]
                        break
                    }
                }
                root.connectedWifi = active
                if (profile) {
                    dnsProfileReadProcess.command = ["nmcli", "-g", "ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns,ipv6.ignore-auto-dns", "connection", "show", profile]
                    dnsProfileReadProcess.running = true
                }
                if (!root.ethernetConnected) {
                    root.activeConnectionName = profile
                    let device = ""
                    for (const line of lines) {
                        const fields = root.splitNmcliLine(line)
                        if (fields.length >= 3 && fields[1] === "802-11-wireless") {
                            device = fields[2]
                            break
                        }
                    }
                    root.activeConnectionDevice = device
                }
            }
        }
    }

    Process {
        id: wifiListProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const result = []
                const seen = {}
                for (const line of lines) {
                    if (!line.length)
                        continue
                    const fields = root.splitNmcliLine(line)
                    if (fields.length < 4)
                        continue
                    const ssid = fields[1]
                    if (!ssid || seen[ssid])
                        continue
                    seen[ssid] = true
                    result.push({
                        active: fields[0] === "*",
                        ssid: ssid,
                        signal: fields[2] || "0",
                        security: fields[3] === "--" ? "" : fields[3]
                    })
                }
                result.sort((a, b) => {
                    if (a.active) return -1
                    if (b.active) return 1
                    return Number(b.signal) - Number(a.signal)
                })
                root.wifiNetworks = result
            }
        }
    }

    Process {
        id: wifiActionProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.statusText = text.trim()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.statusText = text.trim()
            }
        }
        onExited: {
            root.connecting = false
            root.refreshAll()
        }
    }

    Process {
        id: ethernetActionProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.statusText = text.trim()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.statusText = text.trim()
            }
        }
        onExited: root.refreshAll()
    }

}
