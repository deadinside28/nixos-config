// Экран блокировки (ext-session-lock). Пароль проверяет PAM.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.common

Scope {
    id: root

    property string password: ""
    property string error: ""
    readonly property bool busy: pam.active

    function unlock() {
        if (password === "" || pam.active)
            return;
        error = "";
        pam.start();
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                Ui.locked = false;
                root.error = "";
            } else {
                root.error = "Неверный пароль";
            }
            root.password = "";
        }
    }

    WlSessionLock {
        id: lock
        locked: Ui.locked

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }
}
