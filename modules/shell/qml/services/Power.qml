pragma Singleton

// Питание и сессия.
import QtQuick
import Quickshell
import qs.common

Singleton {
    id: root

    function lock() {
        Ui.close();
        Ui.locked = true;
    }
    // Сон с блокировкой: засыпаем, только когда композитор подтвердил, что
    // экран закрыт. Не подтвердил — сна нет, иначе после пробуждения
    // рабочий стол был бы открыт. Внешние запросы сна (крышка, кнопка,
    // systemctl suspend) ловит Lock.qml через ингибитор logind.
    property bool suspendPending: false
    function suspend() {
        if (!Settings.data.lockBeforeSuspend || Ui.lockSecure) {
            Quickshell.execDetached(["systemctl", "suspend"]);
            return;
        }
        suspendPending = true;
        lockWait.restart();
        lock();
    }
    Connections {
        target: Ui
        function onLockSecureChanged() {
            if (!Ui.lockSecure || !root.suspendPending)
                return;
            root.suspendPending = false;
            lockWait.stop();
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }
    Timer {
        id: lockWait
        interval: 5000
        onTriggered: {
            if (!root.suspendPending)
                return;
            root.suspendPending = false;
            Quickshell.execDetached(["notify-send", "-a", "Питание", "-u", "critical", "-i", "dialog-warning", "Сон отменён", "Не удалось заблокировать экран перед сном"]);
        }
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
