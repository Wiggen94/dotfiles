import QtQuick
import Quickshell.Networking

Item {
    id: root
    implicitWidth: visible ? netRow.implicitWidth : 0
    implicitHeight: netRow.implicitHeight
    visible: wifiDevice !== null

    signal menuRequested()

    property var wifiDevice: {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            let d = Networking.devices.values[i];
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    // Keep the scanner running so the active network's SSID/signal stay populated
    // (without scanning, `networks.values` can be empty even when the device is connected).
    Component.onCompleted:   { if (wifiDevice) wifiDevice.scannerEnabled = true; }
    Component.onDestruction: { if (wifiDevice) wifiDevice.scannerEnabled = false; }
    onWifiDeviceChanged: { if (wifiDevice) wifiDevice.scannerEnabled = true; }

    property var activeNetwork: {
        if (!wifiDevice) return null;
        for (let i = 0; i < wifiDevice.networks.values.length; i++) {
            let n = wifiDevice.networks.values[i];
            if (n.connected) return n;
        }
        return null;
    }

    // Drive "am I connected" from the device's connection state — the NM backend
    // wires `state` but leaves `connected` (the bool) unbound, so it's always false.
    property bool connected: wifiDevice?.state === ConnectionState.Connected
    property string ssid: activeNetwork?.name ?? ""
    property real signal: activeNetwork?.signalStrength ?? 0

    function wifiIcon(s) {
        if (!connected) return "󰤮";
        if (s > 0.8) return "󰤨";
        if (s > 0.6) return "󰤥";
        if (s > 0.4) return "󰤢";
        if (s > 0.2) return "󰤟";
        return "󰤯";
    }

    Row {
        id: netRow
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: root.wifiIcon(root.signal)
            color: root.connected ? Theme.subtext0 : Theme.red
            font.family: Theme.fontMono
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.connected && root.ssid !== ""
            text: root.ssid
            color: Theme.subtext0
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeNormal
            maximumLineCount: 1
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: netRow
        cursorShape: Qt.PointingHandCursor
        onClicked: root.menuRequested()
    }
}
