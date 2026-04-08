import QtQuick
import Quickshell.Io

Item {
    id: root
    implicitWidth: statsRow.implicitWidth
    implicitHeight: statsRow.implicitHeight

    property int cpuUsage: 0
    property int memUsage: 0
    property int gpuUsage: 0
    property int gpuTemp: 0
    property string memText: "0"

    // Poll every 3 seconds
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
            gpuProc.running = true;
        }
    }

    // CPU usage via /proc/stat
    Process {
        id: cpuProc
        command: ["bash", "-c", "head -1 /proc/stat | awk '{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; print int(100*(total-idle)/total)}'"]
        stdout: SplitParser {
            onRead: data => { root.cpuUsage = parseInt(data) || 0; }
        }
    }

    // Memory usage
    Process {
        id: memProc
        command: ["bash", "-c", "free -m | awk '/Mem:/{printf \"%d %d\", $3, int($3/$2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split(" ");
                root.memText = (parseInt(parts[0]) / 1024).toFixed(1);
                root.memUsage = parseInt(parts[1]) || 0;
            }
        }
    }

    // GPU usage + temp via nvidia-smi
    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split(",");
                root.gpuUsage = parseInt(parts[0]) || 0;
                root.gpuTemp = parseInt(parts[1]) || 0;
            }
        }
    }

    function usageColor(pct) {
        if (pct > 85) return Theme.red;
        if (pct > 60) return Theme.yellow;
        return Theme.green;
    }

    Row {
        id: statsRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        // CPU
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "󰻠"
                color: Theme.blue
                font.family: Theme.fontMono
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.cpuUsage + "%"
                color: root.usageColor(root.cpuUsage)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // RAM
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "󰍛"
                color: Theme.blue
                font.family: Theme.fontMono
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.memText + "G"
                color: root.usageColor(root.memUsage)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // GPU
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: "󰢮"
                color: Theme.blue
                font.family: Theme.fontMono
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.gpuUsage + "%"
                color: root.usageColor(root.gpuUsage)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.gpuTemp + "°C"
                color: root.gpuTemp > 80 ? Theme.red : root.gpuTemp > 60 ? Theme.yellow : Theme.subtext0
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeNormal
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
