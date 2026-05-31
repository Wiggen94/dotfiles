import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

PanelWindow {
    id: menu

    property var wifiDevice

    signal closeRequested()

    anchors.top: true
    anchors.right: true
    margins.top: Theme.barHeight
    margins.right: 12
    exclusiveZone: 0
    implicitWidth: 300
    implicitHeight: contentCol.implicitHeight + 24
    color: "transparent"

    property var expandedNetwork: null

    property var sortedNetworks: {
        if (!wifiDevice) return [];
        let nets = [...wifiDevice.networks.values];
        nets.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return nets;
    }

    Component.onCompleted:   { if (wifiDevice) wifiDevice.scannerEnabled = true; }
    Component.onDestruction: { if (wifiDevice) wifiDevice.scannerEnabled = false; }

    function signalIcon(net) {
        if (net.connected) return "󰤨";
        let s = net.signalStrength;
        if (s > 0.8) return "󰤨";
        if (s > 0.6) return "󰤥";
        if (s > 0.4) return "󰤢";
        if (s > 0.2) return "󰤟";
        return "󰤯";
    }

    function isSecured(net) {
        return net.security !== WifiSecurityType.None;
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
            spacing: 2

            // Header
            RowLayout {
                width: parent.width
                height: 32

                Text {
                    text: "󰤨  Wi-Fi"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: "✕"
                    color: Theme.subtext0
                    font.family: Theme.fontMono
                    font.pixelSize: 12
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.closeRequested()
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.surface1 }

            Item { width: 1; height: 4 }

            // Network list
            Repeater {
                model: menu.sortedNetworks

                Column {
                    width: parent.width
                    spacing: 0

                    required property var modelData
                    property bool isExpanded: menu.expandedNetwork === modelData

                    // Network row
                    Rectangle {
                        width: parent.width
                        height: 40
                        radius: 8
                        color: rowArea.containsMouse ? Theme.surface0 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: menu.signalIcon(modelData)
                                color: modelData.connected ? Theme.green
                                     : modelData.signalStrength > 0.5 ? Theme.text : Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 16
                            }

                            Text {
                                text: modelData.name
                                color: modelData.connected ? Theme.green : Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSizeNormal
                                font.bold: modelData.connected
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                visible: modelData.connected
                                text: "Connected"
                                color: Theme.green
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Text {
                                visible: !modelData.connected && menu.isSecured(modelData)
                                text: "󰌾"
                                color: Theme.subtext0
                                font.family: Theme.fontMono
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let net = modelData;
                                if (net.connected) {
                                    net.disconnect();
                                } else if (net.known) {
                                    net.connect();
                                } else if (menu.isSecured(net)) {
                                    menu.expandedNetwork = (menu.expandedNetwork === net) ? null : net;
                                } else {
                                    net.connect();
                                }
                            }
                        }
                    }

                    // Inline PSK input for unknown secured networks
                    Rectangle {
                        visible: isExpanded
                        width: parent.width
                        height: visible ? 48 : 0
                        color: "transparent"
                        clip: true

                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 4
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                color: Theme.surface0
                                border.color: pskInput.activeFocus ? Theme.mauve : Theme.surface1
                                border.width: 1
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                TextInput {
                                    id: pskInput
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeNormal
                                    echoMode: TextInput.Password
                                    passwordCharacter: "●"
                                    focus: isExpanded

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !pskInput.text
                                        text: "Password..."
                                        color: Theme.overlay0
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeNormal
                                    }

                                    onAccepted: {
                                        modelData.connectWithPsk(text);
                                        text = "";
                                        menu.expandedNetwork = null;
                                    }
                                }
                            }

                            Rectangle {
                                width: 36; height: 36
                                radius: 8
                                color: okHover.containsMouse ? Theme.mauve : Theme.surface0
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰌓"
                                    color: okHover.containsMouse ? Theme.crust : Theme.text
                                    font.family: Theme.fontMono
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: okHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        modelData.connectWithPsk(pskInput.text);
                                        pskInput.text = "";
                                        menu.expandedNetwork = null;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
