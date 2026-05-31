import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets

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
                        // Filter to workspaces 1-6 on THIS monitor and sort by id
                        model: {
                            let ws = [];
                            for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                                let w = Hyprland.workspaces.values[i];
                                if (w.id >= 1 && w.id <= 6 && w.monitor === bar.hyprMonitor) ws.push(w);
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

                    SystemClock {
                        id: sysClock
                        precision: SystemClock.Minutes
                    }

                    text: {
                        let d = sysClock.date;
                        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                        let h = String(d.getHours()).padStart(2, '0');
                        let m = String(d.getMinutes()).padStart(2, '0');
                        return days[d.getDay()] + " " + d.getDate() + " " +
                               months[d.getMonth()] + "  " + h + ":" + m;
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

                // Separator (only shown when wifi widget is visible)
                Rectangle {
                    visible: networkWidget.visible
                    width: 1; height: 16
                    color: Theme.surface1
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Network / WiFi (auto-hides on hosts without WiFi)
                Network {
                    id: networkWidget
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

                        IconImage {
                            id: trayIcon
                            required property SystemTrayItem modelData
                            source: modelData.icon
                            width: 18
                            height: 18
                            implicitWidth: 18
                            implicitHeight: 18

                            HoverHandler { id: trayHover }

                            // Tooltip showing app name on hover
                            Rectangle {
                                visible: trayHover.hovered
                                anchors.bottom: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 6
                                width: tipText.implicitWidth + 12
                                height: tipText.implicitHeight + 8
                                radius: 6
                                color: Theme.surface0
                                border.color: Theme.surface1
                                border.width: 1
                                z: 100

                                Text {
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: trayIcon.modelData.tooltip?.title || trayIcon.modelData.title || ""
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        trayIcon.modelData.activate();
                                    } else {
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
