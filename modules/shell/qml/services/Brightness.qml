pragma Singleton

// Яркость: подсветка ноутбука через brightnessctl. У внешних мониторов
// подсветки в sysfs нет — тогда слайдер просто не показывается.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property real value: 0
    property int max: 1

    Process {
        id: probe
        running: true
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // name,class,current,percent,max
                const f = text.trim().split("\n")[0]?.split(",") ?? [];
                if (f.length >= 5) {
                    root.available = true;
                    root.max = parseInt(f[4]) || 1;
                    root.value = (parseInt(f[2]) || 0) / root.max;
                }
            }
        }
    }

    function set(v) {
        value = Math.max(0.01, Math.min(1, v));
        setter.restart();
    }
    Timer {
        id: setter
        interval: 30
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(root.value * 100) + "%"])
    }
}
