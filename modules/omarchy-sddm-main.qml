import QtQuick 2.15
import SddmComponents 2.0

// Omarchy SDDM greeter — local fork of omarchy-nix's
// packages/sddm-theme-omarchy Main.qml (a deliberately minimal terminal-style
// theme). The stock file hard-selects "whichever session name contains uwsm"
// and offers no way to pick another, which is useless once more than one
// compositor is installed (Hyprland + Niri, see modules/system/niri.nix).
//
// Changes from upstream:
//   * sessionIndex is a plain writable var (still defaulting to the uwsm
//     session) instead of a read-only binding.
//   * F1 / Shift+F1 cycle the session (also Ctrl+Right / Ctrl+Left). Wired as
//     top-level Shortcut items so they fire regardless of which item holds
//     keyboard focus.
//   * a status line under the password box shows the chosen session, its
//     index, the session count, and the keybind hint.
//
// omarchy-sddm-sync (modules/omarchy-hm.nix) drops this file in over the
// packaged theme's Main.qml and then recolours it, so the #1a1b26 /
// #ffffff sentinels below MUST stay literal for the sed to hit them.
Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  property string currentUser: userModel.lastUser
  property bool loginFailed: false

  // Session list count / name lookups go through this hidden view rather than
  // sessionModel.rowCount() so we never depend on that being QML-invokable.
  ListView { id: sessionList; model: sessionModel; visible: false }

  // Default session: the uwsm-managed Hyprland one (upstream's behaviour),
  // falling back to SDDM's remembered last session. Assigned in
  // Component.onCompleted, not bound, so the cycle keys can overwrite it.
  property int sessionIndex: 0

  function sessionName(i) {
    if (i < 0 || i >= sessionList.count)
      return "?"
    return (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
  }
  function defaultSessionIndex() {
    for (var i = 0; i < sessionList.count; i++) {
      if (sessionName(i).indexOf("uwsm") !== -1)
        return i
    }
    return Math.max(0, sessionModel.lastIndex)
  }
  function cycleSession(step) {
    var n = sessionList.count
    if (n > 0)
      root.sessionIndex = (root.sessionIndex + step + n) % n
  }

  Shortcut { sequences: ["F1"];        onActivated: root.cycleSession(1)  }
  Shortcut { sequences: ["Shift+F1"];  onActivated: root.cycleSession(-1) }
  Shortcut { sequences: ["Ctrl+Right"]; onActivated: root.cycleSession(1)  }
  Shortcut { sequences: ["Ctrl+Left"];  onActivated: root.cycleSession(-1) }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Image {
      id: logo
      source: "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "•"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            } else if (event.key === Qt.Key_F1) {
              root.cycleSession((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
              event.accepted = true
            }
          }
        }
      }
    }

    Text {
      id: sessionLabel
      anchors.horizontalCenter: parent.horizontalCenter
      horizontalAlignment: Text.AlignHCenter
      color: "#ffffff"
      opacity: sessionMouse.containsMouse ? 0.95 : 0.6
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 14
      text: root.sessionName(root.sessionIndex)
            + "   [" + root.sessionIndex + "/" + sessionList.count + "]"
            + "   ·   F1 / click to switch session"

      MouseArea {
        id: sessionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
          root.cycleSession(mouse.button === Qt.RightButton ? -1 : 1)
          password.forceActiveFocus()
        }
      }
    }
  }

  Component.onCompleted: {
    root.sessionIndex = root.defaultSessionIndex()
    password.forceActiveFocus()
  }
}
