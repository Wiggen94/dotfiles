//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Io

ShellRoot {
    id: root

    property bool barVisible: true

    // Toggle bar via Hyprland global shortcut
    GlobalShortcut {
        name: "bartoggle"
        onPressed: root.barVisible = !root.barVisible
    }

    // External control via: qs ipc call bar toggle / show / hide
    IpcHandler {
        target: "bar"
        function toggle() { root.barVisible = !root.barVisible; }
        function show()   { root.barVisible = true; }
        function hide()   { root.barVisible = false; }
    }

    // Bind PipeWire default sink so audio properties are available everywhere
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    // Bar on every screen
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
            barHidden: !root.barVisible
        }
    }

    // Volume OSD (single instance, shows on volume change)
    VolumeOsd {}

    // Power menu (toggled via Hyprland keybind dispatching qs:powermenu)
    PowerMenu {
        id: powerMenu
    }

    // Polkit authentication agent (replaces polkit-gnome-authentication-agent-1)
    Polkit {}
}
