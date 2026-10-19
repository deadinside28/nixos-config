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
        loadCatalog();
        featuredProc.running = true;
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

    // --- Каталог Flathub (AppStream) -------------------------------------------
    // [{ id, remote, name, summary, developer, categories, keywords, icon,
    //    version, released, verified, shot }] — лёгкий индекс pixel-store
    //    catalog; описание и скриншоты — loadDetails()
    property var catalog: []
    property var catalogById: ({})
    property bool catalogLoading: false
    function loadCatalog() {
        if (!catalogProc.running)
            catalogProc.running = true;
    }
    Process {
        id: catalogProc
        command: [Nix.store, "catalog"]
        onRunningChanged: root.catalogLoading = running
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] === "catalog" && f[1]) {
                    root.catalogPath = f[1];
                    catalogFile.path = f[1];
                }
            }
        }
    }
    FileView {
        id: catalogFile
        printErrors: false
        onLoaded: {
            try {
                const apps = JSON.parse(text()).apps ?? [];
                const by = {};
                for (const a of apps) {
                    by[a.id] = a;
                    // строчные копии один раз — поиск идёт по ним на каждую букву
                    a._n = a.name.toLowerCase();
                    a._i = a.id.toLowerCase();
                    a._k = a.keywords.join(" ").toLowerCase();
                    a._s = a.summary.toLowerCase();
                }
                root.catalog = apps;
                root.catalogById = by;
            } catch (e) {
                console.warn("store: каталог не читается", e);
            }
        }
    }

    // Подробности приложения (описание, скриншоты, лицензия, сайт) — в
    // отдельном файле на каждое, читаются при открытии его страницы: в
    // памяти держится только лёгкий индекс
    property string catalogPath: ""
    property var details: ({}) // id → подробности, последние открытые
    function loadDetails(id) {
        if (!id || details[id] || !catalogPath)
            return;
        detailsFile.wanted = id;
        const p = catalogPath + ".d/" + id + ".json";
        if (detailsFile.path === p)
            detailsFile.reload();
        else
            detailsFile.path = p;
    }
    FileView {
        id: detailsFile
        property string wanted: ""
        printErrors: false
        onLoaded: {
            try {
                const d = {};
                // кеш на десяток страниц
                for (const k of Object.keys(root.details).slice(-9))
                    d[k] = root.details[k];
                d[wanted] = JSON.parse(text());
                root.details = d;
            } catch (e) {}
        }
    }

    // Подборки Flathub: популярное, в тренде, недавно обновлённое, новое
    property var featured: ({})
    Process {
        id: featuredProc
        command: [Nix.store, "featured"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] === "featured" && f[1])
                    featuredFile.path = f[1];
            }
        }
    }
    FileView {
        id: featuredFile
        printErrors: false
        onLoaded: {
            try {
                root.featured = JSON.parse(text());
            } catch (e) {}
        }
    }
    // id из подборки → приложения каталога (неизвестные пропускаются)
    function collection(key, limit) {
        const ids = featured[key] ?? [];
        return ids.map(id => catalogById[id]).filter(a => a).slice(0, limit ?? 24);
    }
    // Запасной вариант без сети: свежие релизы из AppStream
    readonly property var recentlyReleased: catalog.slice().filter(a => a.released > 0).sort((a, b) => b.released - a.released).slice(0, 24)

    // Категории как в GNOME Software: основная категория freedesktop → раздел
    readonly property var categories: [
        {
            id: "create",
            label: "Творчество",
            icon: "palette",
            cats: ["Graphics", "2DGraphics", "3DGraphics", "Photography", "VectorGraphics", "RasterGraphics", "AudioVideoEditing", "Publishing"]
        },
        {
            id: "work",
            label: "Работа",
            icon: "work",
            cats: ["Office", "Finance", "WordProcessor", "Spreadsheet", "Presentation", "ProjectManagement", "Calendar", "ContactManagement"]
        },
        {
            id: "social",
            label: "Общение",
            icon: "forum",
            cats: ["Chat", "InstantMessaging", "Email", "VideoConference", "IRCClient", "Telephony", "News"]
        },
        {
            id: "play",
            label: "Игры",
            icon: "stadia_controller",
            cats: ["Game"]
        },
        {
            id: "media",
            label: "Аудио и видео",
            icon: "music_note",
            cats: ["AudioVideo", "Audio", "Video", "Music", "Player", "Recorder", "TV"]
        },
        {
            id: "internet",
            label: "Интернет",
            icon: "language",
            cats: ["Network", "WebBrowser", "FileTransfer", "P2P", "RemoteAccess"]
        },
        {
            id: "learn",
            label: "Образование и наука",
            icon: "school",
            cats: ["Education", "Science", "Math", "Astronomy", "Chemistry", "Languages", "Geography", "Literature"]
        },
        {
            id: "develop",
            label: "Разработка",
            icon: "code",
            cats: ["Development", "IDE", "TextEditor", "Debugger", "WebDevelopment", "RevisionControl", "Database"]
        },
        {
            id: "system",
            label: "Утилиты и система",
            icon: "build",
            cats: ["Utility", "System", "Settings", "Monitor", "FileManager", "Archiving", "Security", "Accessibility", "Emulator"]
        }
    ]
    function categoryApps(catId) {
        const c = categories.find(x => x.id === catId);
        if (!c)
            return [];
        return catalog.filter(a => a.categories.some(k => c.cats.includes(k))).sort((a, b) => (b.verified - a.verified) || (b.released - a.released));
    }

    // Навигация окна магазина из его карточек
    signal appRequested(var item)
    signal shotRequested(string url)
    function requestApp(item) {
        appRequested(item);
    }
    function requestShot(url) {
        shotRequested(url);
    }
    // Открыть магазин с поиском (IPC)
    signal searchRequested(string q)
    function showSearch(q) {
        search(q);
        Ui.storeOpen = true;
        searchRequested(q);
    }
    // Открыть страницу приложения по id (IPC, ссылки appstream://)
    property string pendingApp: ""
    function showApp(id) {
        pendingApp = String(id).replace(/^appstream:\/\//, "").replace(/\.desktop$/, "");
        Ui.storeOpen = true;
    }
    function takePendingApp() {
        if (!pendingApp)
            return null;
        const a = catalogById[pendingApp];
        if (!a && catalog.length === 0)
            return null; // каталог ещё грузится
        const item = a ? itemOf(a) : {
            source: "nixpkgs",
            id: pendingApp,
            name: pendingApp.split(".").pop(),
            version: "",
            description: ""
        };
        pendingApp = "";
        return item;
    }

    // Запись каталога → элемент установки (как у результатов поиска)
    function itemOf(app) {
        return {
            source: "flatpak",
            id: app.id,
            name: app.name,
            version: app.version,
            description: app.summary,
            remote: app.remote,
            app
        };
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
            if (root.catalog.length) {
                root.flatpakResults = root.searchCatalog(q);
            } else {
                flatSearch.running = false;
                flatSearch.command = [Nix.store, "flatpak-search", q];
                flatSearch.running = true;
            }
        }
    }
    // Поиск по каталогу: имя > начало имени > ключевые слова > описание
    function searchCatalog(q) {
        const ql = q.toLowerCase();
        const scored = [];
        for (const a of catalog) {
            const n = a._n;
            let r = -1;
            if (n === ql || a._i === ql)
                r = 0;
            else if (n.startsWith(ql))
                r = 1;
            else if (n.includes(ql) || a._i.includes(ql))
                r = 2;
            else if (a._k.includes(ql))
                r = 3;
            else if (a._s.includes(ql))
                r = 4;
            if (r >= 0)
                scored.push([r, a]);
        }
        scored.sort((x, y) => x[0] - y[0] || (y[1].verified - x[1].verified) || x[1].name.localeCompare(y[1].name));
        return scored.slice(0, 40).map(x => itemOf(x[1]));
    }

    // Описание пакета Nix для страницы приложения: attr → meta
    property var nixInfo: ({})
    function loadNixInfo(item) {
        if (item.source === "flatpak" || nixInfo[item.id] || nixInfoProc.running)
            return;
        nixInfoProc.item = item;
        nixInfoProc.command = [Nix.store, "nix-info", Nix.flake, item.source, item.id];
        nixInfoProc.running = true;
    }
    Process {
        id: nixInfoProc
        property var item
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = Object.assign({}, root.nixInfo);
                    o[nixInfoProc.item.id] = JSON.parse(text);
                    root.nixInfo = o;
                } catch (e) {}
            }
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
            onStreamFinished: root.flatpakResults = root.parse(text).map(r => root.catalogById[r.id] ? root.itemOf(root.catalogById[r.id]) : r)
        }
    }

    // --- Flatpak: установлено и обновления -----------------------------------
    property var flatpakInstalled: []
    property var flatpakUpdates: []
    property var flatpakUpdatesAll: [] // с средами выполнения и расширениями
    function refreshFlatpaks() {
        flatList.running = true;
        flatUpd.running = true;
        flatUpdAll.running = true;
    }
    Process {
        id: flatUpdAll
        command: [Nix.store, "flatpak-updates-all"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpakUpdatesAll = text.split("\n").filter(l => l)
        }
    }

    // Обновление Flatpak прямо из магазина. Системная установка обновляется
    // через flatpak-system-helper: polkit разрешает это активной сессии без
    // пароля. ids пусто — обновить всё, вместе со средами выполнения.
    property bool updating: false
    property string updatingId: "" // "" — всё
    property string updateLine: ""
    property int updateStep: 0
    property int updateTotal: 0
    function updateFlatpaks(ids) {
        if (updating)
            return;
        lastError = "";
        updatingId = ids && ids.length === 1 ? ids[0] : "";
        updateTotal = ids && ids.length ? ids.length : Math.max(1, flatpakUpdatesAll.length);
        updateStep = 0;
        updateLine = "Готовлю обновление…";
        updating = true;
        updProc.command = ["sh", "-c", 'export LC_ALL=C; exec flatpak update -y --noninteractive "$@" 2>&1', "sh", ...(ids ?? [])];
        updProc.running = true;
    }
    Process {
        id: updProc
        property string tail: ""
        stdout: SplitParser {
            onRead: line => {
                const l = line.trim();
                if (!l)
                    return;
                updProc.tail = l;
                // «Updating 3/17…» в обычном режиме, «Updating app/…» в noninteractive
                const m = l.match(/^(Updating|Installing)\s+(\d+)\/(\d+)/);
                if (m) {
                    root.updateStep = Number(m[2]);
                    root.updateTotal = Number(m[3]);
                } else if (/^(Updating|Installing)\b/.test(l))
                    root.updateStep = Math.min(root.updateTotal, root.updateStep + 1);
                const ref = l.match(/(?:app|runtime)\/([^/\s]+)/);
                root.updateLine = ref ? "Обновляю " + (root.catalogById[ref[1]]?.name ?? ref[1]) : l.length < 120 ? l : root.updateLine;
            }
        }
        onExited: code => {
            root.updating = false;
            root.updateLine = "";
            if (code !== 0)
                root.lastError = "Flatpak: " + updProc.tail;
            else
                root.log("Обновлено (Flatpak)", {
                    id: root.updatingId || "всё",
                    source: "flatpak"
                });
            root.refreshFlatpaks();
        }
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
