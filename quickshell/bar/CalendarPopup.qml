import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: popup

    anchors {
        top: true
    }

    visible: false
    margins.top: 0
    margins.left: (screen.width - 280) / 2
    exclusiveZone: 0
    implicitWidth: 280
    implicitHeight: contentCol.implicitHeight + 32
    color: "transparent"

    property date currentMonth: new Date()

    // Helper functions
    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstDayOfWeek(year, month) {
        // Monday = 0, Sunday = 6
        let d = new Date(year, month, 1).getDay();
        return (d + 6) % 7;
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.base
        border.color: Theme.surface1
        border.width: 1

        Column {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // Month/Year header with navigation
            RowLayout {
                width: parent.width

                Text {
                    text: "◀"
                    color: Theme.subtext0
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let d = popup.currentMonth;
                            popup.currentMonth = new Date(d.getFullYear(), d.getMonth() - 1, 1);
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        let months = ["January", "February", "March", "April", "May", "June",
                                      "July", "August", "September", "October", "November", "December"];
                        return months[popup.currentMonth.getMonth()] + " " + popup.currentMonth.getFullYear();
                    }
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }

                Text {
                    text: "▶"
                    color: Theme.subtext0
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let d = popup.currentMonth;
                            popup.currentMonth = new Date(d.getFullYear(), d.getMonth() + 1, 1);
                        }
                    }
                }
            }

            // Day-of-week headers
            Row {
                spacing: 0
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                        width: 36
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.overlay0
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            // Calendar grid
            Grid {
                columns: 7
                spacing: 0

                Repeater {
                    model: {
                        let year = popup.currentMonth.getFullYear();
                        let month = popup.currentMonth.getMonth();
                        let days = popup.daysInMonth(year, month);
                        let offset = popup.firstDayOfWeek(year, month);
                        let today = new Date();

                        let cells = [];
                        // Empty cells before first day
                        for (let i = 0; i < offset; i++)
                            cells.push({ day: 0, isToday: false });
                        // Day cells
                        for (let d = 1; d <= days; d++) {
                            cells.push({
                                day: d,
                                isToday: d === today.getDate() &&
                                         month === today.getMonth() &&
                                         year === today.getFullYear()
                            });
                        }
                        return cells;
                    }

                    Rectangle {
                        required property var modelData
                        width: 36
                        height: 32
                        radius: 8
                        color: modelData.isToday ? Theme.mauve : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day > 0 ? modelData.day : ""
                            color: modelData.isToday ? Theme.crust : Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeNormal
                            font.bold: modelData.isToday
                        }
                    }
                }
            }

            // "Today" button
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Today"
                color: Theme.mauve
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeSmall

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popup.currentMonth = new Date()
                }
            }
        }
    }
}
