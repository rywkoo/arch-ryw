import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

FloatingWindow {
    id: window
    title: "RyW Desktop Setup"
    width: 700
    height: 600
    color: "#171a22"
    visible: true

    readonly property var browserIds: ["org.mozilla.firefox", "com.brave.Browser", "org.chromium.Chromium", "none"]
    readonly property var fileManagerIds: ["org.kde.dolphin", "none"]
    readonly property var managerIds: ["io.github.kolunmi.Bazaar", "none"]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 34
        spacing: 18

        Label {
            text: "RYW  /  FIRST-RUN SETUP"
            color: "#f4e7bb"
            font.pixelSize: 13
            font.bold: true
            Layout.fillWidth: true
        }
        Label {
            text: "Choose your desktop apps"
            color: "#ffffff"
            font.pixelSize: 29
            font.bold: true
            Layout.fillWidth: true
        }
        Label {
            text: "The core Hyprland session is ready. Pick one app in each category; the installer will open in Kitty and finish the full setup."
            color: "#c4c8d4"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#3a4050" }

        GridLayout {
            columns: 2
            columnSpacing: 22
            rowSpacing: 16
            Layout.fillWidth: true

            Label { text: "WEB BROWSER"; color: "#f4e7bb"; font.bold: true }
            ComboBox { id: browser; Layout.fillWidth: true; model: ["Firefox", "Brave", "Chromium", "Skip"] }

            Label { text: "FILE MANAGER"; color: "#f4e7bb"; font.bold: true }
            ComboBox { id: fileManager; Layout.fillWidth: true; model: ["Dolphin", "Skip"] }

            Label { text: "FLATPAK MANAGER"; color: "#f4e7bb"; font.bold: true }
            ComboBox { id: manager; Layout.fillWidth: true; model: ["Bazaar (recommended)", "Skip"] }
        }

        Item { Layout.fillHeight: true }

        Label {
            text: "The installer also adds Smile for the configured Super + Period shortcut."
            color: "#aeb4c2"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Button {
                text: "Install selected apps and apply RyW config"
                highlighted: true
                onClicked: {
                    const script = Quickshell.env("HOME") + "/.local/share/ryw-installer/installer/setup-apps.sh"
                    Quickshell.execDetached([
                        "kitty", "--title", "RyW Setup", "bash", script,
                        window.browserIds[browser.currentIndex],
                        window.fileManagerIds[fileManager.currentIndex],
                        window.managerIds[manager.currentIndex]
                    ])
                    window.visible = false
                }
            }
        }
    }
}
