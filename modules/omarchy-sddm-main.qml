import QtQuick 2.15
import SddmComponents 2.0

// Omarchy SDDM greeter — local fork of omarchy-nix's
// packages/sddm-theme-omarchy Main.qml (a deliberately minimal terminal-style
// theme). The stock file tries to hard-select "whichever session name
// contains uwsm" but does it via sessionModel.data(idx, Qt.DisplayRole),
// which SDDM's SessionModel returns as `undefined` (it only implements the
// custom `name`/`exec`/`comment` roles, not DisplayRole) — so upstream in
// practice always logs into session index 0 and offers no way to change it.
// Useless once more than one compositor is installed (Hyprland + Niri, see
// modules/system/niri.nix).
//
// Changes from upstream:
//   * session list + names come from a Repeater bound to sessionModel, using
//     the `name` role that SDDM actually populates.
//   * sessionIndex is a writable var; default still prefers the uwsm-managed
//     Hyprland session, else SDDM's remembered last session.
//   * F1 / Shift+F1 cycle the session (also Ctrl+Left/Right and
//     left/right-clicking the status line). Cycle keys are top-level Shortcut
//     items so keyboard focus doesn't matter.
//   * a dim status line under the password box shows the chosen session.
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

  property var sessionNames: []
  property int sessionIndex: 0
  property bool sessionPicked: false

  function rebuildSessions() {
    var a = []
    for (var i = 0; i < sessionRepeater.count; i++) {
      var it = sessionRepeater.itemAt(i)
      if (it)
        a.push(it.sessionName)
    }
    root.sessionNames = a

    if (!root.sessionPicked && a.length > 0) {
      root.sessionPicked = true
      var def = -1
      for (var j = 0; j < a.length; j++) {
        if (a[j].toLowerCase().indexOf("uwsm") !== -1) { def = j; break }
      }
      if (def < 0) {
        try {
          if (sessionModel.lastIndex >= 0 && sessionModel.lastIndex < a.length)
            def = sessionModel.lastIndex
        } catch (e) {}
      }
      root.sessionIndex = def < 0 ? 0 : def
    }
  }
  function cycleSession(step) {
    var n = root.sessionNames.length
    if (n > 0)
      root.sessionIndex = (root.sessionIndex + step + n) % n
  }

  // Hidden — just a data source for sessionNames.
  Item {
    visible: false
    Repeater {
      id: sessionRepeater
      model: sessionModel
      delegate: Item { property string sessionName: model.name }
      onCountChanged: root.rebuildSessions()
    }
  }

  Shortcut { sequences: ["F1"];         onActivated: root.cycleSession(1)  }
  Shortcut { sequences: ["Shift+F1"];   onActivated: root.cycleSession(-1) }
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
      opacity: sessionMouse.containsMouse ? 0.95 : 0.55
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 14
      text: (root.sessionNames[root.sessionIndex] || ("session " + root.sessionIndex))
            + "   ·   F1 / click to switch"

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
    root.rebuildSessions()
    password.forceActiveFocus()
  }
}
