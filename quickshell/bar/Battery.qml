import QtQuick
import Quickshell.Services.UPower

Item {
    id: root
    implicitWidth: hasBattery ? batteryRow.implicitWidth : 0
    implicitHeight: batteryRow.implicitHeight
    visible: hasBattery

    property bool hasBattery: (UPower.displayDevice?.isLaptopBattery ?? false) && (UPower.displayDevice?.isPresent ?? false)
    property int capacity: Math.round(UPower.displayDevice?.percentage ?? 0)
    property bool charging: {
        let s = UPower.displayDevice?.state ?? UPowerDeviceState.Unknown;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged;
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
