pragma Singleton

// Магазин: каталог Nixpkgs, Chaotic-Nyx и Flatpak с общим поиском.
//
// Управление пакетами одно — декларативное: установка и удаление меняют
// списки в system.json (extraPackages, flatpaks), а применяет их
// пересборка (SystemConfig.rebuild) в отдельной службе, которая
// переживает перезапуск оболочки. Поэтому у каждой записи два состояния:
// желаемое (что в system.json) и фактическое (что в применённой системе
// или реально установлено во Flatpak), и «Установлено» появляется только
// после успешного применения. nix profile install не используется.
//
// Каталог Nix — индекс pixel-store из тех же ревизий, что во flake.lock
// (modules/shell/store.sh), поэтому найденное устанавливается без
// обновления входов. Пакеты Chaotic-Nyx ставятся тем же списком: оверлей
// Nyx кладёт их в pkgs.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property var sources: ({
            nixpkgs: "Nixpkgs",
            chaotic: "Chaotic-Nyx",
            flatpak: "Flatpak"
        })

    // --- Каталог -----------------------------------------------------------
    property string indexStatus: "" // "" | building | ready | failed
    function prepare() {
        refreshFlatpaks();
        if (!indexProc.running && indexStatus !== "ready")
            indexProc.running = true;
    }
    function rebuildIndex() {
        if (!indexProc.running)
            indexProc.running = true;
    }
    Process {
        id: indexProc
        command: [Nix.store, "index", Nix.flake, "nixpkgs", "chaotic"]
        onRunningChanged: if (running)
            root.indexStatus = "building"
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] === "index" && f[1] === "nixpkgs" && (f[2] === "failed"))
                    root.indexStatus = "failed";
            }
        }
        onExited: {
            if (root.indexStatus === "building")
                root.indexStatus = "ready";
            if (root.query)
                root.search(root.query);
        }
    }

    property string query: ""
    property var nixResults: []
    property var flatpakResults: []
    readonly property bool searching: nixSearch.running || flatSearch.running
    readonly property var results: [...nixResults, ...flatpakResults]
    function search(q) {
        query = q;
        searchTimer.restart();
    }
    Timer {
        id: searchTimer
        interval: 300
        onTriggered: {
            const q = root.query.trim();
            if (!q) {
                root.nixResults = [];
                root.flatpakResults = [];
                return;
            }
            nixSearch.running = false;
            nixSearch.command = [Nix.store, "search", q];
            nixSearch.running = true;
            flatSearch.running = false;
            flatSearch.command = [Nix.store, "flatpak-search", q];
            flatSearch.running = true;
        }
    }
    function parse(text) {
        return text.split("\n").filter(l => l.includes("\t")).map(l => {
            const [source, id, version, description, name, remote] = l.split("\t");
            return {
                source,
                id,
                version,
                description,
                name: name || id.split(".").pop(),
                remote: remote ?? ""
            };
        });
    }
    Process {
        id: nixSearch
        stdout: StdioCollector {
            onStreamFinished: root.nixResults = root.parse(text)
        }
    }
    Process {
        id: flatSearch
        stdout: StdioCollector {
            onStreamFinished: root.flatpakResults = root.parse(text)
        }
    }

    // --- Flatpak: установлено и обновления -----------------------------------
    property var flatpakInstalled: []
    property var flatpakUpdates: []
    function refreshFlatpaks() {
        flatList.running = true;
        flatUpd.running = true;
    }
    Process {
        id: flatList
        command: [Nix.store, "flatpak-installed"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpakInstalled = text.split("\n").filter(l => l)
        }
    }
    Process {
        id: flatUpd
        command: [Nix.store, "flatpak-updates"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpakUpdates = text.split("\n").filter(l => l)
        }
    }

    // --- Состояние записи ----------------------------------------------------
    function listKey(item) {
        return item.source === "flatpak" ? "flatpaks" : "extraPackages";
    }
    function inList(list, item) {
        return (list ?? []).some(x => x === item.id || (item.source === "flatpak" && x.startsWith(item.id + "//")));
    }
    // desired: в system.json; actual: в применённой системе / установлено
    function stateOf(item) {
        const key = listKey(item);
        const desired = inList(SystemConfig.data[key], item);
        const actual = item.source === "flatpak" ? flatpakInstalled.includes(item.id) : inList(SystemConfig.applied[key], item);
        const declared = item.source === "flatpak" ? inList(SystemConfig.applied.flatpaks, item) || desired : true;
        let label;
        if (desired && actual)
            label = "Установлено";
        else if (desired)
            label = SystemConfig.running ? "Устанавливается…" : SystemConfig.status === "failed" ? "Ошибка применения — см. журнал" : "Будет установлено после применения";
        else if (actual && declared)
            label = SystemConfig.running ? "Удаляется…" : "Будет удалено после применения";
        else if (actual)
            label = "Установлено вручную";
        else
            label = "Не установлено";
        return {
            desired,
            actual,
            manual: actual && !declared,
            label
        };
    }

    function install(item) {
        SystemConfig.addTo(listKey(item), item.id);
        log("Выбрано для установки", item);
    }
    function remove(item) {
        const st = stateOf(item);
        if (st.manual) {
            uninstallProc.item = item;
            uninstallProc.command = ["flatpak", "uninstall", "-y", "--noninteractive", item.id];
            uninstallProc.running = true;
            return;
        }
        const list = SystemConfig.get(listKey(item), []);
        const entry = list.find(x => x === item.id || x.startsWith(item.id + "//"));
        if (entry)
            SystemConfig.removeFrom(listKey(item), entry);
        log("Выбрано для удаления", item);
    }
    property string lastError: ""
    Process {
        id: uninstallProc
        property var item
        stderr: StdioCollector {
            id: unErr
        }
        onExited: code => {
            root.lastError = code === 0 ? "" : unErr.text.trim().split("\n").pop();
            if (code === 0)
                root.log("Удалено (Flatpak)", uninstallProc.item);
            root.refreshFlatpaks();
        }
    }
    // Изменения, ожидающие применения
    readonly property var pending: {
        const out = [];
        for (const key of ["extraPackages", "flatpaks"]) {
            const want = SystemConfig.data[key] ?? [];
            const have = SystemConfig.applied[key] ?? [];
            for (const x of want)
                if (!have.includes(x))
                    out.push({
                        key,
                        id: x,
                        add: true
                    });
            for (const x of have)
                if (!want.includes(x))
                    out.push({
                        key,
                        id: x,
                        add: false
                    });
        }
        return out;
    }
    function apply() {
        SystemConfig.rebuild("switch");
    }
    Connections {
        target: SystemConfig
        function onStatusChanged() {
            if (SystemConfig.status === "success" || SystemConfig.status === "failed")
                root.refreshFlatpaks();
        }
    }

    // --- История ---------------------------------------------------------------
    // Последние действия в магазине (сами версии системы — SystemConfig.generations)
    property var history: []
    function log(what, item) {
        history = [{
                what,
                id: item.id,
                source: item.source,
                at: new Date()
            }, ...history].slice(0, 50);
    }
}
