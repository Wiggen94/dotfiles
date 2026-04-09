import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Services.SystemTray

PanelWindow {
    id: bar

    property bool barHidden: false
    property var hyprMonitor: Hyprland.monitorFor(screen)

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: barHidden ? 0 : Theme.barHeight
    color: Theme.base
    exclusiveZone: barHidden ? 0 : Theme.barHeight

    // Three-section layout: left, center, right - each gets equal space
    // This ensures the clock is truly centered regardless of left/right content
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==================== LEFT SECTION ====================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: Theme.spacing

                // Workspaces (sorted by ID, only show 1-6)
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        // Filter to workspaces 1-6 and sort by id
                        model: {
                            let ws = [];
                            for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                                let w = Hyprland.workspaces.values[i];
                                if (w.id >= 1 && w.id <= 6) ws.push(w);
                            }
                            ws.sort((a, b) => a.id - b.id);
                            return ws;
                        }

                        Rectangle {
                            required property var modelData
                            property bool isActive: bar.hyprMonitor?.activeWorkspace === modelData
                            width: isActive ? 28 : 22
                            height: 22
                            radius: 6
                            color: isActive ? Theme.mauve : Theme.surface0

                            Behavior on width {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.id
                                color: parent.isActive ? Theme.crust : Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                font.bold: parent.isActive
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Hyprland.dispatch("workspace " + parent.modelData.id)
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: 1; height: 16
                    color: Theme.surface1
                    Layout.alignment: Qt.AlignVCenter
                }

                // Active window title
                Text {
                    text: bar.hyprMonitor?.activeWorkspace?.lastWindow?.title ?? ""
                    color: Theme.subtext0
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeNormal
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

            }
        }

        // ==================== CENTER SECTION ====================
        Item {
            Layout.preferredWidth: 280
            Layout.fillHeight: true

            Row {
                anchors.centerIn: parent
                spacing: 12

                Text {
                    id: clock
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    font.bold: true

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: {
                            let now = new Date();
                            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                            let h = String(now.getHours()).padStart(2, '0');
                            let m = String(now.getMinutes()).padStart(2, '0');
                            clock.text = days[now.getDay()] + " " + now.getDate() + " " +
                                         months[now.getMonth()] + "  " + h + ":" + m;
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarPopup.visible = !calendarPopup.visible
                    }
                }

                // Notifications (swaync)
                Notifications {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ==================== RIGHT SECTION ====================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing

                // System stats (CPU, RAM, GPU)
                SystemStats {
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Separator
                Rectangle {
                    width: 1; height: 16
                    color: Theme.surface1
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Weather
                Weather {
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Separator
                Rectangle {
                    width: 1; height: 16
                    color: Theme.surface1
                    anchors.verticalCenter: parent.verticalCenter
                }

                // System tray
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: SystemTray.items

                        Image {
                            id: trayIcon
                            required property var modelData
                            source: modelData.icon
                            width: 18
                            height: 18
                            sourceSize.width: 18
                            sourceSize.height: 18

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        trayIcon.modelData.activate();
                                    } else {
                                        // Map local coords to bar window coords
                                        let mapped = mapToItem(bar.contentItem, mouse.x, mouse.y);
                                        trayIcon.modelData.display(bar, mapped.x, mapped.y);
                                    }
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: 1; height: 16
                    color: Theme.surface1
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Volume
                Text {
                    id: volumeText
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.blue
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeNormal

                    property real vol: Pipewire.defaultAudioSink?.audio?.volume ?? 0
                    property bool muted: Pipewire.defaultAudioSink?.audio?.muted ?? false

                    text: {
                        if (muted) return "󰝟 muted";
                        let pct = Math.round(vol * 100);
                        if (pct > 50) return "󰕾 " + pct + "%";
                        if (pct > 0)  return "󰖀 " + pct + "%";
                        return "󰕿 " + pct + "%";
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                if (Pipewire.defaultAudioSink?.audio)
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                            } else {
                                volControl.startDetached();
                            }
                        }
                    }

                    Process {
                        id: volControl
                        command: ["pavucontrol"]
                    }
                }

                // Battery (only visible on laptops)
                Battery {
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Separator
                Rectangle {
                    width: 1; height: 16
                    color: Theme.surface1
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Power button
                Text {
                    text: "⏻"
                    color: Theme.red
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch("global qs:powermenu")
                    }
                }
            }
        }
    }

    // ==================== CALENDAR POPUP ====================
    CalendarPopup {
        id: calendarPopup
    }
}
