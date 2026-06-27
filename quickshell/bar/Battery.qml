import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

Item {
    id: root
    implicitWidth: hasBattery ? batteryRow.implicitWidth : 0
    implicitHeight: batteryRow.implicitHeight
    visible: hasBattery

    property bool hasBattery: UPower.displayDevice?.isLaptopBattery ?? false
    property int capacity: 0
    property bool charging: false

    // Poll sysfs every 5 seconds for reliable battery data
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batCapProc.running = true;
            batStatusProc.running = true;
        }
    }

    Process {
        id: batCapProc
        command: ["cat", "/sys/class/power_supply/BAT0/capacity"]
        stdout: SplitParser {
            onRead: data => { root.capacity = parseInt(data) || 0; }
        }
    }

    Process {
        id: batStatusProc
        command: ["cat", "/sys/class/power_supply/BAT0/status"]
        stdout: SplitParser {
            onRead: data => { root.charging = (data.trim() === "Charging" || data.trim() === "Full"); }
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
