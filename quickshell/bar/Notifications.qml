import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property int count: 0
    property bool dnd: false

    // Poll notification count every 3 seconds
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            countProc.running = true;
            dndProc.running = true;
        }
    }

    Process {
        id: countProc
        command: ["swaync-client", "-c"]
        stdout: SplitParser {
            onRead: data => { root.count = parseInt(data) || 0; }
        }
    }

    Process {
        id: dndProc
        command: ["swaync-client", "-D"]
        stdout: SplitParser {
            onRead: data => { root.dnd = data.trim() === "true"; }
        }
    }

    Process {
        id: toggleProc
        command: ["swaync-client", "-t"]
    }

    Process {
        id: clearProc
        command: ["swaync-client", "-C"]
    }

    Process {
        id: dndToggleProc
        command: ["swaync-client", "-d"]
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            id: bellIcon
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.fontMono
            font.pixelSize: 16
            color: root.dnd ? Theme.red : root.count > 0 ? Theme.yellow : Theme.subtext0

            text: root.dnd ? "󰂛" : root.count > 0 ? "󰂚" : "󰂜"

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        // Badge with count
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.count > 0
            text: root.count
            color: Theme.yellow
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    // MouseArea covers the whole Item, not inside the Row
    MouseArea {
        anchors.fill: row
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                toggleProc.running = true;
            else if (mouse.button === Qt.RightButton)
                clearProc.running = true;
            else if (mouse.button === Qt.MiddleButton)
                dndToggleProc.running = true;
        }
    }
}
