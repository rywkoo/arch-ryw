import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import QtQuick

import "../../theme" as SharedTheme
import "." as BarTypes
Item {
    id: root

    property string netType: ""
    readonly property var wsNames: ["SKILL", "ITEM", "EQUIP", "PERSONA", "STATS"]

    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Network type poll (wifi / ethernet / empty)
    Process {
        id: net
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE device | awk -F: '$2==\"connected\"{print $1; exit}'"]
        stdout: StdioCollector { onStreamFinished: root.netType = text.trim() }
    }
    Timer {
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: net.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            margins { top: 4; left: 8; right: 8 }
            implicitHeight: 32
            color: "transparent"

            // ───────── LEFT: MENU + workspace list ─────────
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: -6

                BarTypes.Slab {
                    fill: SharedTheme.Theme.cyan
                    onClicked: root.run("qs -c launcher --no-duplicate")   // <- opens the P3 launcher
                    BarTypes.P3Text { text: "  MENU"; color: SharedTheme.Theme.deep }
                }

                BarTypes.Slab {
                    underline: true
                    pad: 6
                    spacing: -4

                    Repeater {
                        model: root.wsNames.length

                        delegate: BarTypes.Slab {
                            id: tab
                            required property int index
                            readonly property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                            readonly property bool active: Hyprland.focusedWorkspace?.id === index + 1
                            readonly property bool urgent: ws?.urgent ?? false

                            skew: 8
                            pad: 12
                            fill: urgent ? SharedTheme.Theme.red : active ? SharedTheme.Theme.ice : "transparent"
                            onClicked: Hyprland.dispatch("workspace " + (index + 1))

                            BarTypes.P3Text {
                                text: root.wsNames[tab.index]
                                color: (tab.active || tab.urgent) ? SharedTheme.Theme.deep : Qt.alpha(SharedTheme.Theme.ice, 0.45)
                            }
                        }
                    }
                }
            }

            // ───────── CENTER: calendar-style clock ─────────
            BarTypes.Slab {
                anchors.centerIn: parent
                underline: true
                pad: 22
                BarTypes.P3Text {
                    text: "󰽥  " + Qt.formatDateTime(clock.date, "MM/dd  ddd  HH:mm").toUpperCase()
                    color: SharedTheme.Theme.cyan
                }
            }

            // ───────── RIGHT: status + QUIT ─────────
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: -6

                BarTypes.Slab {
                    underline: true
                    spacing: 14

                    // Tray (left click = activate, right click = secondary)
                    Row {
                        spacing: 8
                        visible: SystemTray.items.values.length > 0
                        Repeater {
                            model: SystemTray.items
                            delegate: IconImage {
                                required property var modelData
                                source: modelData.icon
                                implicitSize: 16
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: m => m.button === Qt.LeftButton
                                        ? modelData.activate()
                                        : modelData.secondaryActivate()
                                }
                            }
                        }
                    }

                    // Network
                    BarTypes.P3Text {
                        text: root.netType === "wifi" ? "󰤨" : root.netType === "ethernet" ? "󰟀" : "󱘖"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.run("~/.config/rofi/network/network.sh")
                        }
                    }

                    // Bluetooth
                    BarTypes.P3Text {
                        readonly property var adapter: Bluetooth.defaultAdapter
                        text: !adapter || !adapter.enabled ? "󰂲"
                            : adapter.devices.values.some(d => d.connected) ? "󰂱" : "󰂯"
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.run("~/.config/rofi/bluetooth/bluetooth.sh")
                        }
                    }

                    // Volume (scroll to change)
                    BarTypes.P3Text {
                        readonly property var audio: Pipewire.defaultAudioSink?.audio
                        text: !audio ? "" : audio.muted ? "󰝟 MUTE" : "󰕾 " + Math.round(audio.volume * 100) + "%"
                        color: audio?.muted ? SharedTheme.Theme.red : SharedTheme.Theme.ice
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.run("pavucontrol")
                            onWheel: w => {
                                const a = parent.audio
                                if (a) a.volume = Math.max(0, Math.min(1, a.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)))
                            }
                        }
                    }

                    // Battery as HP
                    BarTypes.P3Text {
                        readonly property var bat: UPower.displayDevice
                        readonly property int pct: Math.round(bat.percentage * 100)
                        readonly property bool charging: bat.state === UPowerDeviceState.Charging
                        visible: bat.isPresent
                        text: "HP " + pct + (charging ? " 󱐋" : "")
                        color: charging ? SharedTheme.Theme.ice : pct <= 15 ? SharedTheme.Theme.red : pct <= 30 ? SharedTheme.Theme.warn : SharedTheme.Theme.cyan

                        SequentialAnimation on opacity {
                            running: parent.pct <= 15 && !parent.charging
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.3; duration: 250 }
                            NumberAnimation { to: 1.0; duration: 250 }
                        }
                    }

                    // Notifications
                    BarTypes.P3Text {
                        text: ""
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.run("swaync-client -t")
                        }
                    }
                }

                BarTypes.Slab {
                    fill: SharedTheme.Theme.red
                    onClicked: root.run("~/.config/rofi/power/powermenu.sh")
                    BarTypes.P3Text { text: "⏻  QUIT"; color: SharedTheme.Theme.deep }
                }
            }
        }
    }
}
