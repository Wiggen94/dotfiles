import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: weatherText.implicitWidth
    implicitHeight: weatherText.implicitHeight

    property string weatherInfo: "..."

    // WMO weather code to icon mapping
    function weatherIcon(code) {
        if (code === 0) return "☀️";
        if (code <= 3) return "⛅";
        if (code <= 48) return "🌫️";
        if (code <= 55) return "🌦️";
        if (code <= 57) return "🌧️";
        if (code <= 65) return "🌧️";
        if (code <= 67) return "🌨️";
        if (code <= 75) return "❄️";
        if (code <= 77) return "🌨️";
        if (code <= 82) return "🌧️";
        if (code <= 86) return "❄️";
        if (code <= 99) return "⛈️";
        return "🌡️";
    }

    // Fetch weather on load and every 15 minutes
    Timer {
        interval: 900000  // 15 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Process {
        id: weatherProc
        // Trondheim coordinates: 63.43°N 10.39°E
        command: ["curl", "-s", "https://api.open-meteo.com/v1/forecast?latitude=63.43&longitude=10.39&current=temperature_2m,weather_code&timezone=auto"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    let json = JSON.parse(data);
                    let temp = Math.round(json.current.temperature_2m);
                    let icon = root.weatherIcon(json.current.weather_code);
                    root.weatherInfo = icon + " " + temp + "°C";
                } catch(e) {
                    root.weatherInfo = "🌡️ --";
                }
            }
        }
    }

    Text {
        id: weatherText
        anchors.verticalCenter: parent.verticalCenter
        text: root.weatherInfo
        color: Theme.peach
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontSizeNormal

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: weatherProc.running = true  // Click to refresh
        }
    }
}
