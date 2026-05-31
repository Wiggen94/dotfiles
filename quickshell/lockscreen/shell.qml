import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    // Holds password while PAM restarts after a timeout
    property string pendingPassword: ""

    PamContext {
        id: pam
        config: "login"

        onResponseRequiredChanged: {
            // If PAM just became ready and we have a queued password, send it
            if (responseRequired && root.pendingPassword !== "") {
                let pw = root.pendingPassword;
                root.pendingPassword = "";
                pam.respond(pw);
            }
        }

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                lock.locked = false;
            } else {
                root.pendingPassword = "";
                lockSurface.authFailed();
                // Restart PAM for next attempt
                pam.start("gjermund");
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: true

        onLockedChanged: {
            if (!locked) Qt.quit();
        }

        onSecureChanged: {
            // Start PAM session as soon as lock is secured
            if (secure) pam.start("gjermund");
        }

        WlSessionLockSurface {
            id: lockSurface

            signal authFailed()

            Rectangle {
                anchors.fill: parent
                color: Theme.base

                Column {
                    anchors.centerIn: parent
                    spacing: 20

                    SystemClock {
                        id: lockClock
                        precision: SystemClock.Minutes
                    }

                    // Time
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 72
                        font.bold: true
                        text: Qt.formatDateTime(lockClock.date, "hh:mm")
                    }

                    // Date
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.subtext0
                        font.family: Theme.fontMono
                        font.pixelSize: 20
                        text: Qt.formatDateTime(lockClock.date, "dddd, MMMM d")
                    }

                    Item { width: 1; height: 30 }

                    // Password field
                    Rectangle {
                        id: inputContainer
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 300
                        height: 50
                        radius: 10
                        color: Theme.surface0
                        border.color: inputField.activeFocus ? Theme.mauve : Theme.surface1
                        border.width: 3

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }

                        property real shakeOffset: 0
                        transform: Translate { x: inputContainer.shakeOffset }

                        SequentialAnimation {
                            id: shakeAnim
                            NumberAnimation { target: inputContainer; property: "shakeOffset"; to: 10; duration: 50 }
                            NumberAnimation { target: inputContainer; property: "shakeOffset"; to: -10; duration: 50 }
                            NumberAnimation { target: inputContainer; property: "shakeOffset"; to: 8; duration: 50 }
                            NumberAnimation { target: inputContainer; property: "shakeOffset"; to: -8; duration: 50 }
                            NumberAnimation { target: inputContainer; property: "shakeOffset"; to: 0; duration: 50 }
                        }

                        TextInput {
                            id: inputField
                            anchors.fill: parent
                            anchors.margins: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: 16
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            focus: true
                            clip: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !inputField.text
                                text: "Password..."
                                color: Theme.overlay0
                                font.family: Theme.fontMono
                                font.pixelSize: 16
                            }

                            onAccepted: {
                                if (text.length > 0) {
                                    if (pam.responseRequired) {
                                        // PAM is ready, respond directly
                                        pam.respond(text);
                                    } else {
                                        // PAM session likely timed out, restart and queue the password
                                        root.pendingPassword = text;
                                        pam.start("gjermund");
                                    }
                                }
                            }

                            Keys.onPressed: errorText.visible = false
                        }
                    }

                    // Error message
                    Text {
                        id: errorText
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Authentication failed"
                        color: Theme.red
                        font.family: Theme.fontSans
                        font.pixelSize: 14
                        visible: false

                        Timer {
                            id: errorTimer
                            interval: 3000
                            onTriggered: errorText.visible = false
                        }
                    }
                }

                // Bottom hint
                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 40
                    text: "Type password to unlock"
                    color: Theme.overlay0
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }

                Connections {
                    target: lockSurface
                    function onAuthFailed() {
                        shakeAnim.start();
                        inputField.text = "";
                        errorText.visible = true;
                        errorTimer.restart();
                    }
                }
            }
        }
    }
}
