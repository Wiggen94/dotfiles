import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property bool visible: false

    // Process lives outside LazyLoader so it survives menu closing
    Process {
        id: proc
    }

    function runAndClose(cmd) {
        proc.command = ["bash", "-c", cmd];
        proc.startDetached();
        root.visible = false;
    }

    // Listen for the global keybind event from Hyprland
    GlobalShortcut {
        name: "powermenu"

        onPressed: {
            root.visible = !root.visible;
        }
    }

    LazyLoader {
        active: root.visible

        Variants {
            model: Quickshell.screens

            PanelWindow {
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                exclusiveZone: 0
                color: "#80000000"
                focusable: true
                aboveWindows: true

                // Close on Escape
                Shortcut {
                    sequence: "Escape"
                    onActivated: root.visible = false
                }

                // Button grid in center
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 30

                    Repeater {
                        model: [
                            { label: "Lock",      icon: "󰌾", key: "l", cmd: "loginctl lock-session",     color: Theme.blue },
                            { label: "Logout",    icon: "󰍃", key: "e", cmd: "loginctl terminate-user $USER", color: Theme.green },
                            { label: "Suspend",   icon: "󰤄", key: "u", cmd: "systemctl suspend",         color: Theme.yellow },
                            { label: "Hibernate",  icon: "󰒲", key: "h", cmd: "systemctl hibernate",      color: Theme.peach },
                            { label: "Reboot",    icon: "󰜉", key: "r", cmd: "systemctl reboot",          color: Theme.mauve },
                            { label: "Shutdown",  icon: "󰐥", key: "s", cmd: "systemctl poweroff",        color: Theme.red },
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 120
                            height: 120
                            radius: 16
                            color: mouseArea.containsMouse ? Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.2) : Theme.surface0

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: modelData.icon
                                    color: modelData.color
                                    font.family: Theme.fontMono
                                    font.pixelSize: 36
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: modelData.label
                                    color: Theme.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeNormal
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: "(" + modelData.key + ")"
                                    color: Theme.overlay0
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runAndClose(modelData.cmd)
                            }

                            // Keyboard shortcut
                            Shortcut {
                                sequence: modelData.key
                                onActivated: root.runAndClose(modelData.cmd)
                            }
                        }
                    }
                }

            }
        }
    }
}
