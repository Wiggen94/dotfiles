import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

// Keyboard layout indicator. Reflects Hyprland's active xkb layout
// (no / kvikk, toggled with Super+Space). Click to switch to the next layout.
Item {
    id: root
    implicitWidth: layoutRow.implicitWidth
    implicitHeight: layoutRow.implicitHeight

    // Full xkb layout description as reported by Hyprland (e.g. "Norwegian", "Kvikk (nb)")
    property string layout: ""
    // Name of the main keyboard, needed to dispatch layout switches
    property string mainKeyboard: ""

    // Short label shown in the bar
    function shortName(name) {
        if (name.startsWith("Norwegian")) return "NO";
        if (name.startsWith("Kvikk")) return "KV";
        return name.substring(0, 2).toUpperCase();
    }

    // Initial state: query the main keyboard's current keymap on startup
    Process {
        id: initProc
        running: true
        command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | \"\\(.name)\\t\\(.active_keymap)\"'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split("\t");
                if (parts.length >= 2) {
                    root.mainKeyboard = parts[0];
                    root.layout = parts[1];
                }
            }
        }
    }

    // Live updates: Hyprland emits `activelayout>>KEYBOARD_NAME,LAYOUT_NAME` on every switch
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            let idx = event.data.indexOf(",");
            if (idx < 0) return;
            let kbd = event.data.substring(0, idx);
            let name = event.data.substring(idx + 1);
            if (root.mainKeyboard === "" || kbd === root.mainKeyboard) {
                root.mainKeyboard = kbd;
                root.layout = name;
            }
        }
    }

    Process { id: switchProc }

    Row {
        id: layoutRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            text: "󰌌"
            color: Theme.blue
            font.family: Theme.fontMono
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.shortName(root.layout)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeNormal
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.mainKeyboard === "") return;
            switchProc.command = ["hyprctl", "switchxkblayout", root.mainKeyboard, "next"];
            switchProc.startDetached();
        }
    }
}
