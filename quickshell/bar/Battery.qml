import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: hasBattery ? batteryRow.implicitWidth : 0
    implicitHeight: batteryRow.implicitHeight
    visible: hasBattery

    property bool hasBattery: false
    property int capacity: 0
    property bool charging: false

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            detectProc.running = true;
        }
    }

    Process {
        id: detectProc
        command: ["bash", "-c", "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && echo \"$(cat $b/capacity) $(cat $b/status)\" && exit; done; echo 'none'"]
        stdout: SplitParser {
            onRead: data => {
                if (data === "none") {
                    root.hasBattery = false;
                } else {
                    root.hasBattery = true;
                    let parts = data.split(" ");
                    root.capacity = parseInt(parts[0]) || 0;
                    root.charging = parts[1] === "Charging" || parts[1] === "Full";
                }
            }
        }
    }

    function batteryIcon() {
        if (charging) return "󰂄";
        if (capacity > 90) return "󰁹";
        if (capacity > 80) return "󰂂";
        if (capacity > 70) return "󰂁";
        if (capacity > 60) return "󰂀";
        if (capacity > 50) return "󰁿";
        if (capacity > 40) return "󰁾";
        if (capacity > 30) return "󰁽";
        if (capacity > 20) return "󰁼";
        if (capacity > 10) return "󰁻";
        return "󰁺";
    }

    function batteryColor() {
        if (charging) return Theme.green;
        if (capacity <= 10) return Theme.red;
        if (capacity <= 20) return Theme.yellow;
        return Theme.green;
    }

    Row {
        id: batteryRow
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: root.batteryIcon()
            color: root.batteryColor()
            font.family: Theme.fontMono
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.capacity + "%"
            color: root.batteryColor()
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeNormal
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
