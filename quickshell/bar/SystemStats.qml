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

    // CPU usage: two /proc/stat reads 200ms apart → delta-based (single read gives boot average, not current)
    Process {
        id: cpuProc
        command: ["bash", "-c", "r1=($(head -1 /proc/stat)); sleep 0.2; r2=($(head -1 /proc/stat)); t1=0; t2=0; for i in ${r1[@]:1}; do ((t1+=i)); done; for i in ${r2[@]:1}; do ((t2+=i)); done; dt=$((t2-t1)); [ $dt -gt 0 ] && echo $((100*(dt-(${r2[4]}-${r1[4]}))/dt)) || echo 0"]
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
