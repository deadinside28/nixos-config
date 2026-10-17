pragma Singleton

// Ночной режим через hyprsunset: тёплая температура экрана.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property bool enabled: Settings.data.nightLight

    Process {
        id: proc
        running: root.enabled && Settings.loaded
        command: ["hyprsunset", "-t", String(Settings.data.nightTemp)]
    }

    Connections {
        target: Settings.data
        function onNightTempChanged() {
            if (proc.running) {
                proc.running = false;
                restart.restart();
            }
        }
    }
    Timer {
        id: restart
        interval: 200
        onTriggered: proc.running = Qt.binding(() => root.enabled && Settings.loaded)
    }

    function toggle() {
        Settings.data.nightLight = !Settings.data.nightLight;
    }
}
