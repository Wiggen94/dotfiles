pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // Dynamic colors - loaded from theme JSON
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color mauve: "#cba6f7"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color teal: "#94e2d5"
    property color green: "#a6e3a1"
    property color yellow: "#f9e2af"
    property color peach: "#fab387"
    property color red: "#f38ba8"
    property color pink: "#f5c2e7"
    property color lavender: "#b4befe"
    property color rosewater: "#f5e0dc"

    // Transparent variants (computed from base)
    property color baseDim: Qt.rgba(base.r, base.g, base.b, 0.81)
    property color baseTranslucent: Qt.rgba(base.r, base.g, base.b, 0.69)

    // Fonts
    property string fontMono: "JetBrainsMono Nerd Font"
    property string fontSans: "Inter"
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeNormal: 12
    readonly property int fontSizeLarge: 14

    // Dimensions
    readonly property int barHeight: 42
    readonly property int borderRadius: 8
    readonly property int spacing: 8

    // Current theme name
    property string themeName: ""

    // Poll ~/.config/current-theme for changes
    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: themeChecker.running = true
    }

    Process {
        id: themeChecker
        command: ["bash", "-c", "cat ~/.config/current-theme"]
        stdout: SplitParser {
            onRead: data => {
                let name = data.trim();
                if (name && name !== theme.themeName) {
                    theme.themeName = name;
                    theme.loadCurrentTheme();
                }
            }
        }
    }

    function applyTheme(data) {
        try {
            let t = JSON.parse(data);
            theme.base = t.base;
            theme.mantle = t.mantle;
            theme.crust = t.crust;
            theme.surface0 = t.surface0;
            theme.surface1 = t.surface1;
            theme.surface2 = t.surface2;
            theme.overlay0 = t.overlay0;
            theme.overlay1 = t.overlay1;
            theme.text = t.text;
            theme.subtext0 = t.subtext0;
            theme.subtext1 = t.subtext1;
            theme.mauve = t.mauve;
            theme.blue = t.blue;
            theme.sapphire = t.sapphire;
            theme.teal = t.teal;
            theme.green = t.green;
            theme.yellow = t.yellow;
            theme.peach = t.peach;
            theme.red = t.red;
            theme.pink = t.pink;
            theme.lavender = t.lavender;
            theme.rosewater = t.rosewater;
            theme.fontMono = t.fontMono || "JetBrainsMono Nerd Font";
            theme.fontSans = t.fontSans || "Inter";
            console.log("Quickshell: Loaded theme " + t.name);
        } catch(e) {
            console.log("Quickshell: Failed to parse theme: " + e);
        }
    }

    Process {
        id: themeLoader
        stdout: SplitParser {
            onRead: data => theme.applyTheme(data)
        }
    }

    function loadCurrentTheme() {
        themeLoader.command = ["bash", "-c", "jq -c '.' ~/.local/share/themes/" + themeName + "/quickshell/colors.json"];
        themeLoader.running = true;
    }
}
