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
    readonly property bool running: status === "running"
    // Прогресс 0…1; -1 — неопределённый (ждём, скачиваем индекс, переключаем)
    property real progress: -1
    property int buildsDone: 0
    property int buildsTotal: 0
    property int fetchDone: 0
    property int fetchTotal: 0
    property string current: "" // что сейчас собирается или качается
    property date startedAt: new Date()
    property date finishedAt: new Date()
    // Карточку прогресса во всплывающих уведомлениях можно смахнуть
    property bool popupHidden: false
    // …а в центре уведомлений она живёт, пока её не закроют
    property bool cardDismissed: true

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
        pending_ = [];
        acts = {};
        progress = -1;
        buildsDone = buildsTotal = fetchDone = fetchTotal = 0;
        current = "";
        startedAt = new Date();
        popupHidden = false;
        cardDismissed = false;
        lastRun = [name, cmd];
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
    property var lastRun: null
    function retry() {
        if (lastRun)
            run(lastRun[0], lastRun[1]);
    }
    function cancel() {
        proc.signal(15);
    }

    // --- Разбор вывода ----------------------------------------------------
    // Строки копятся и сбрасываются в log пачками, иначе на сборке с
    // тысячами строк лога интерфейс бы задыхался.
    property var pending_: []
    property var acts: ({}) // id активности Nix → { type, done, expected }

    function storeName(p) {
        return String(p ?? "").replace(/^\/nix\/store\/[a-z0-9]{32}-/, "").replace(/\.drv$/, "");
    }
    function addLine(line) {
        pending_.push(line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, ""));
        if (!flush.running)
            flush.start();
    }
    function recount() {
        let bd = 0, bt = 0, fd = 0, ft = 0;
        for (const id in acts) {
            const a = acts[id];
            if (a.type === 104) {
                bd += a.done;
                bt += a.expected;
            } else if (a.type === 103) {
                fd += a.done;
                ft += a.expected;
            }
        }
        buildsDone = bd;
        buildsTotal = bt;
        fetchDone = fd;
        fetchTotal = ft;
        const total = bt + ft;
        progress = total > 0 ? Math.min(1, (bd + fd) / total) : -1;
    }
    function handleNix(j) {
        if (j.action === "msg") {
            if (j.level <= 3 && j.msg)
                addLine(j.msg);
        } else if (j.action === "start") {
            const f = j.fields ?? [];
            if (j.type === 103 || j.type === 104) {
                acts[j.id] = {
                    type: j.type,
                    done: 0,
                    expected: 0
                };
            } else if (j.type === 105) {
                current = storeName(f[0]);
                addLine("⚙ Сборка " + current);
            } else if (j.type === 108) {
                current = storeName(f[0]);
                addLine("↓ Загрузка " + current);
            } else if (j.type === 112 && j.text) {
                addLine(j.text);
            }
        } else if (j.action === "result") {
            const f = j.fields ?? [];
            if (j.type === 105 && acts[j.id]) {
                acts[j.id].done = f[0] ?? 0;
                acts[j.id].expected = f[1] ?? 0;
                recount();
            } else if (j.type === 101 || j.type === 107) {
                addLine("    " + (f[0] ?? ""));
            } else if (j.type === 104 && f[0]) {
                addLine("    — " + f[0]);
            }
        }
    }
    function pushLog(line) {
        if (line.startsWith("@nix ")) {
            try {
                handleNix(JSON.parse(line.slice(5)));
            } catch (e) {}
            return;
        }
        if (line.startsWith("::stage ")) {
            stage = line.slice(8);
            // сборка закончилась — дальше прогресс неопределённый
            if (!stage.startsWith("Собираю"))
                progress = -1;
            current = "";
            addLine("▸ " + stage);
            return;
        }
        addLine(line);
    }
    Timer {
        id: flush
        interval: 120
        onTriggered: {
            if (root.pending_.length === 0)
                return;
            const l = root.log.concat(root.pending_);
            root.pending_ = [];
            root.log = l.length > 1500 ? l.slice(-1200) : l;
        }
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
            flush.triggered();
            root.status = code === 0 ? "success" : "failed";
            root.stage = code === 0 ? "Готово" : code === 143 || code === 15 ? "Остановлено" : "Ошибка (код " + code + ")";
            root.progress = code === 0 ? 1 : root.progress;
            root.current = "";
            root.finishedAt = new Date();
            root.popupHidden = false;
            popupTimer.restart();
            appliedFile.reload();
            root.refreshGenerations();
            Updates.refresh();
        }
    }
    // Итог висит во всплывашке несколько секунд, дальше — только в шторке
    Timer {
        id: popupTimer
        interval: 8000
        onTriggered: if (!root.running)
            root.popupHidden = true
    }
    function dismissCard() {
        if (running)
            popupHidden = true;
        else {
            cardDismissed = true;
            popupHidden = true;
            if (status !== "running")
                status = "idle";
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
