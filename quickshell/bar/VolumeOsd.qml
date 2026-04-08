import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    property bool shouldShow: false

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null

        function onVolumeChanged() {
            root.shouldShow = true;
            hideTimer.restart();
        }

        function onMutedChanged() {
            root.shouldShow = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shouldShow = false
    }

    LazyLoader {
        active: root.shouldShow

        PanelWindow {
            anchors {
                bottom: true
            }

            // Center horizontally, offset from bottom
            margins.bottom: 80
            exclusiveZone: 0
            implicitWidth: 300
            implicitHeight: 50
            color: "transparent"
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                radius: 25
                color: Theme.baseDim

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    // Volume icon
                    Text {
                        property real vol: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                        property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

                        color: muted ? Theme.red : Theme.mauve
                        font.family: Theme.fontMono
                        font.pixelSize: 20

                        text: {
                            if (muted) return "󰝟";
                            let pct = Math.round(vol * 100);
                            if (pct > 50) return "󰕾";
                            if (pct > 0)  return "󰖀";
                            return "󰕿";
                        }
                    }

                    // Progress bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.surface0

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * Math.min(1.0, Pipewire.defaultAudioSink?.audio?.volume ?? 0)
                            radius: parent.radius
                            color: Pipewire.defaultAudioSink?.audio?.muted ? Theme.red : Theme.mauve

                            Behavior on width {
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }

                    // Percentage
                    Text {
                        property real vol: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                        text: Math.round(vol * 100) + "%"
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeNormal
                        Layout.minimumWidth: 36
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
