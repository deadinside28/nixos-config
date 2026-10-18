// Экран блокировки (ext-session-lock). Пароль проверяет PAM.
import QtQuick
import Quickshell
import Quickshell.Io
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
        onSecureChanged: Ui.lockSecure = secure

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    // --- Внешние запросы сна и блокировки -----------------------------------
    // Крышка, кнопка питания, systemctl suspend, loginctl lock-session.
    // Пока включено «Блокировать перед сном», держим delay-ингибитор
    // logind: перед сном он ждёт, пока экран не будет подтверждённо
    // заблокирован (не дольше InhibitDelayMaxSec), и только тогда отпускается.
    property bool sleeping: false
    Process {
        running: Settings.data.lockBeforeSuspend && !(root.sleeping && lock.secure)
        // Ребёнок завершается сам, когда systemd-inhibit убит (ингибитор
        // отпущен), чтобы не копить «sleep» после каждого сна
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Pixel Shell", "--why=Блокировка экрана перед сном", "sh", "-c", 'while kill -0 "$PPID" 2>/dev/null; do sleep 2; done']
    }
    Process {
        id: login1
        running: true
        // Путь нашей графической сессии — чтобы реагировать на Lock только для неё
        command: ["sh", "-c", `
            sid=$(loginctl show-user "$(id -u)" -p Display --value 2>/dev/null)
            [ -n "$sid" ] && gdbus call --system --dest org.freedesktop.login1 --object-path /org/freedesktop/login1 \
                --method org.freedesktop.login1.Manager.GetSession "$sid" 2>/dev/null | sed -n "s/^(objectpath '\\(.*\\)',)$/session \\1/p"
            exec gdbus monitor --system --dest org.freedesktop.login1
        `]
        property string session: ""
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("session ")) {
                    login1.session = line.slice(8);
                } else if (line.includes("org.freedesktop.login1.Manager.PrepareForSleep (true")) {
                    root.sleeping = true;
                    if (Settings.data.lockBeforeSuspend) {
                        Ui.close();
                        Ui.locked = true;
                    }
                } else if (line.includes("org.freedesktop.login1.Manager.PrepareForSleep (false")) {
                    root.sleeping = false;
                } else if (login1.session !== "" && line.startsWith(login1.session + ": org.freedesktop.login1.Session.Lock ")) {
                    Ui.close();
                    Ui.locked = true;
                }
            }
        }
        // gdbus отвалился (перезапуск D-Bus) — переподключаемся
        onRunningChanged: if (!running)
            login1Restart.start()
    }
    Timer {
        id: login1Restart
        interval: 3000
        onTriggered: login1.running = true
    }
}
