import Quickshell
import QtQuick

//import "modules/bar" as BarModule
import "modules/launcher" as LauncherModule
import "modules/notifications" as NotificationModule
import "modules/audio" as AudioModule
import "modules/wallchange" as WallchangeModule
import "modules/connectivity" as ConnectivityModule
import "modules/bluetooth" as BluetoothModule

// Main shell entry point. Disable any module by setting its flag to false.
ShellRoot {
    id: root

    // Feature switches: set false to omit a module entirely.
    readonly property bool enableBar: true
    readonly property bool enableLauncher: true
    readonly property bool enableNotifications: true
    readonly property bool enableAudioMixer: true
    readonly property bool enableWallchange: true
    readonly property bool enableBluetooth: true

//    Loader {
//        active: root.enableBar
 //       sourceComponent: Component { BarModule.Bar {} }
 //   }

    Loader {
        active: root.enableLauncher
        sourceComponent: Component { LauncherModule.Launcher {} }
    }

    Loader {
        active: root.enableNotifications
        sourceComponent: Component { NotificationModule.NotificationCenter {} }
    }

    Loader {
        active: root.enableAudioMixer
        sourceComponent: Component { AudioModule.AudioMixer {} }
    }

    Loader {
        active: root.enableWallchange
        sourceComponent: Component { WallchangeModule.Wallchange {} }
    }
    Loader {
        active: root.enableBluetooth
        sourceComponent: Component { BluetoothModule.Bluetooth {} }
    }
	Loader {
	    active: true
	    sourceComponent: Component {
		ConnectivityModule.Connectivity {}
	    }
}
}
