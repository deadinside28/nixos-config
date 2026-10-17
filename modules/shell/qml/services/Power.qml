pragma Singleton

// Питание и сессия.
import QtQuick
import Quickshell
import qs.common

Singleton {
    function lock() {
        Ui.close();
        Ui.locked = true;
    }
    function suspend() {
        if (Settings.data.lockBeforeSuspend)
            Ui.locked = true;
        Quickshell.execDetached(["sh", "-c", "sleep 0.5; systemctl suspend"]);
    }
    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }
    function logout() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]);
    }
}
