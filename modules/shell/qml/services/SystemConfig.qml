pragma Singleton

// Настройки NixOS из GUI. Всё системное (пакеты, Flatpak, службы, игры,
// часовой пояс, обслуживание Nix) лежит в system.json в корне flake —
// Nix читает его через lib.importJSON. Здесь мы этот файл правим, а
// «Применить» собирает систему от пользователя и переключает её через
// pkexec (пароль спросит наш агент polkit).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property string path: Nix.flake + "/system.json"
    property var data: ({})
    property var applied: ({})
    readonly property bool loaded: Object.keys(data).length > 0
    readonly property bool pending: loaded && norm(data) !== norm(applied)

    // Пересборка
    property string status: "idle" // idle | running | success | failed
    property string stage: ""
    property string task: ""
    property var log: []
    property var generations: []

    function norm(v) {
        if (Array.isArray(v))
            return "[" + v.map(norm).join(",") + "]";
        if (v && typeof v === "object")
            return "{" + Object.keys(v).sort().map(k => JSON.stringify(k) + ":" + norm(v[k])).join(",") + "}";
        return JSON.stringify(v);
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                console.warn("system.json не читается:", e);
            }
        }
    }
    FileView {
        id: appliedFile
        path: "/etc/pixel-shell/system.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.applied = JSON.parse(text());
            } catch (e) {}
        }
    }

    function get(keyPath, fallback) {
        let v = data;
        for (const k of keyPath.split(".")) {
            if (v === undefined || v === null)
                return fallback;
            v = v[k];
        }
        return v ?? fallback;
    }
    function set(keyPath, value) {
        const d = JSON.parse(JSON.stringify(data));
        const keys = keyPath.split(".");
        let o = d;
        for (const k of keys.slice(0, -1))
            o = (o[k] = o[k] ?? {});
        o[keys[keys.length - 1]] = value;
        data = d;
        file.setText(JSON.stringify(d, null, 2) + "\n");
    }
    function addTo(keyPath, value) {
        const list = get(keyPath, []);
        if (!list.includes(value))
            set(keyPath, [...list, value].sort());
    }
    function removeFrom(keyPath, value) {
        set(keyPath, get(keyPath, []).filter(v => v !== value));
    }
    function revert() {
        data = JSON.parse(JSON.stringify(applied));
        file.setText(JSON.stringify(data, null, 2) + "\n");
    }

    // --- Пересборка и обслуживание --------------------------------------

    function run(name, cmd) {
        if (proc.running)
            return;
        task = name;
        status = "running";
        stage = "Запуск…";
        log = [];
        proc.command = cmd;
        proc.running = true;
    }
    function rebuild(mode) {
        run(mode === "build" ? "Проверка сборки" : "Применение настроек", ["pixel-rebuild", mode ?? "switch"]);
    }
    function updateAndRebuild() {
        run("Обновление системы", ["pixel-rebuild", "switch", "--update"]);
    }
    function rollback() {
        run("Откат", ["pixel-rebuild", "rollback"]);
    }
    function collectGarbage() {
        run("Очистка", ["pixel-rebuild", "gc"]);
    }
    function cancel() {
        proc.signal(15);
    }

    function pushLog(line) {
        if (line.startsWith("::stage ")) {
            stage = line.slice(8);
            return;
        }
        const l = log.length > 600 ? log.slice(-500) : log.slice();
        l.push(line);
        log = l;
    }

    Process {
        id: proc
        stdout: SplitParser {
            onRead: line => root.pushLog(line)
        }
        stderr: SplitParser {
            onRead: line => root.pushLog(line)
        }
        onExited: code => {
            root.status = code === 0 ? "success" : "failed";
            root.stage = code === 0 ? "Готово" : "Ошибка (код " + code + ")";
            appliedFile.reload();
            root.refreshGenerations();
        }
    }

    function refreshGenerations() {
        gens.running = true;
    }
    Process {
        id: gens
        command: ["sh", "-c", "for l in /nix/var/nix/profiles/system-*-link; do n=${l##*/system-}; n=${n%-link}; printf '%s\\t%s\\t%s\\n' \"$n\" \"$(stat -c %Y \"$l\")\" \"$(readlink /nix/var/nix/profiles/system)\"; done | sort -n -r | head -20"]
        stdout: StdioCollector {
            onStreamFinished: root.generations = text.split("\n").filter(l => l).map(l => {
                const [n, t, cur] = l.split("\t");
                return {
                    number: parseInt(n),
                    date: new Date(parseInt(t) * 1000),
                    current: cur === "system-" + n + "-link"
                };
            })
        }
    }
}
