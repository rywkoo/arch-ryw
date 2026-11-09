import QtQuick
import QtMultimedia

Item {
    property bool ok: v.playbackState === MediaPlayer.PlayingState

    Video {
        id: v
        anchors.fill: parent
        source: Qt.resolvedUrl("background.mp4")
        fillMode: VideoOutput.PreserveAspectCrop
        loops: MediaPlayer.Infinite
        muted: true
        Component.onCompleted: play()
    }
}