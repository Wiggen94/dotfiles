import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit

Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            visible: agent.flow !== null

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: 0
            color: "#80000000"
            focusable: true
            aboveWindows: true

            // Close on Escape (cancels auth)
            Shortcut {
                sequence: "Escape"
                onActivated: agent.flow?.cancel()
            }

            // Only render dialog on the first screen to avoid duplicates
            Loader {
                active: modelData === Quickshell.screens[0]
                anchors.centerIn: parent

                sourceComponent: Rectangle {
                    width: 360
                    height: authCol.implicitHeight + 48
                    radius: 16
                    color: Theme.base
                    border.color: Theme.surface1
                    border.width: 1

                    Column {
                        id: authCol
                        anchors.centerIn: parent
                        width: parent.width - 48
                        spacing: 16

                        Text {
                            text: "󰌾  Authentication Required"
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 16
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            visible: text !== ""
                            text: agent.flow?.message ?? ""
                            color: Theme.subtext0
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeNormal
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            visible: text !== ""
                            text: agent.flow?.supplementaryMessage ?? ""
                            color: Theme.overlay0
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 46
                            radius: 10
                            color: Theme.surface0
                            border.color: pwInput.activeFocus ? Theme.mauve : Theme.surface1
                            border.width: 2

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }

                            TextInput {
                                id: pwInput
                                anchors.fill: parent
                                anchors.margins: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: 14
                                echoMode: TextInput.Password
                                passwordCharacter: "●"
                                focus: agent.flow !== null
                                clip: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !pwInput.text
                                    text: agent.flow?.inputPrompt ?? "Password..."
                                    color: Theme.overlay0
                                    font.family: Theme.fontMono
                                    font.pixelSize: 14
                                }

                                onAccepted: {
                                    if (text) {
                                        agent.flow.respond(text);
                                        text = "";
                                    }
                                }
                            }
                        }

                        Text {
                            id: errorText
                            visible: false
                            text: "Authentication failed"
                            color: Theme.red
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSizeNormal
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Row {
                            spacing: 12
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                width: 120; height: 36
                                radius: 8
                                color: cancelArea.containsMouse ? Theme.red : Theme.surface0
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: cancelArea.containsMouse ? Theme.crust : Theme.subtext0
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeNormal
                                }

                                MouseArea {
                                    id: cancelArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: agent.flow?.cancel()
                                }
                            }

                            Rectangle {
                                width: 120; height: 36
                                radius: 8
                                color: okArea.containsMouse ? Theme.mauve : Theme.surface0
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "Authenticate"
                                    color: okArea.containsMouse ? Theme.crust : Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeNormal
                                }

                                MouseArea {
                                    id: okArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (pwInput.text) {
                                            agent.flow.respond(pwInput.text);
                                            pwInput.text = "";
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Connections {
                        target: agent.flow

                        function onAuthenticationFailed() {
                            errorText.visible = true;
                            pwInput.text = "";
                        }

                        function onAuthenticationSucceeded() {
                            errorText.visible = false;
                            pwInput.text = "";
                        }
                    }
                }
            }
        }
    }
}
