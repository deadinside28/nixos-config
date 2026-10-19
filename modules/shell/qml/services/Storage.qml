pragma Singleton

// Раздел «Память»: место на диске по категориям и по приложениям, очистка
// кеша и данных. Считает pixel-storage (modules/shell/storage.sh) в фоне,
// подсчёт можно прервать. Речь о диске, не об оперативной памяти.
//
// Чистить можно только то, чья принадлежность известна:
//   Flatpak — ~/.var/app/<id> (данные и настройки) и …/cache (кеш);
//   Nix     — пути из rules ниже, по desktop ID.
// У остальных показываются размеры, но не кнопки сброса: угадывать пути
// по похожему имени нельзя. Настройки, которыми управляет Home Manager,
// pixel-storage не трогает.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    // Известные пути данных Nix-приложений (~ — домашняя папка). Это общие
    // для этих программ пути; если у тебя они другие — поправь здесь.
    // Лаунчеры игр (Steam, Lutris, Heroic) сюда намеренно не входят: в их
    // данных лежат сами игры, и «сброс» удалил бы их.
    readonly property var rules: ({
            "google-chrome": {
                config: ["~/.config/google-chrome"],
                cache: ["~/.cache/google-chrome"]
            },
            "org.telegram.desktop": {
                data: ["~/.local/share/TelegramDesktop"]
            },
            "dev.zed.Zed": {
                config: ["~/.config/zed"],
                data: ["~/.local/share/zed"],
                cache: ["~/.cache/zed"]
            },
            "org.qbittorrent.qBittorrent": {
                config: ["~/.config/qBittorrent"],
                data: ["~/.local/share/qBittorrent"],
                cache: ["~/.cache/qBittorrent"]
            },
            "discord": {
                config: ["~/.config/discord"]
            },
            "onlyoffice-desktopeditors": {
                data: ["~/.local/share/onlyoffice"]
            }
        })

    function expand(p) {
        return p.startsWith("~/") ? Settings.home + p.slice(1) : p;
    }
    function kindOf(app) {
        if (!app || app.custom)
            return "";
        if (app.origin === "Flatpak")
            return "flatpak";
        return (app.origin ?? "").startsWith("Nix") ? "nix" : "";
    }
    // { cache: [], data: [] } — пути с известной принадлежностью, или null
    function pathsFor(app) {
        const kind = kindOf(app);
        if (kind === "flatpak") {
            const base = Settings.home + "/.var/app/" + app.id;
            return {
                cache: [base + "/cache"],
                data: [base]
            };
        }
        const r = rules[app?.id];
        if (!r)
            return null;
        return {
            cache: (r.cache ?? []).map(expand),
            data: [...(r.config ?? []), ...(r.data ?? []), ...(r.cache ?? [])].map(expand)
        };
    }

    // --- Подсчёт -------------------------------------------------------------
    property var overview: ({}) // ключ → [числа]
    property var appSizes: ({}) // id → { own, closure, store }
    property date measuredAt: new Date(0)
    readonly property bool measuring: overviewProc.running || appsProc.running

    function refresh() {
        if (measuring)
            return;
        overviewAcc = {};
        overviewProc.running = true;
        const args = [];
        for (const a of Apps.everything) {
            const k = kindOf(a);
            if (k)
                args.push(a.id, k, k === "nix" ? (Apps.origins[a.id] ?? "") : "");
        }
        appsAcc = {};
        appsProc.command = [Nix.storage, "apps", ...args];
        appsProc.running = true;
    }
    function cancel() {
        overviewProc.running = false;
        appsProc.running = false;
    }

    property var overviewAcc: ({})
    Process {
        id: overviewProc
        command: [Nix.storage, "overview"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] === "done") {
                    root.measuredAt = new Date();
                    return;
                }
                const acc = Object.assign({}, root.overviewAcc);
                acc[f[0]] = f.slice(1).map(Number);
                root.overviewAcc = acc;
                root.overview = acc;
            }
        }
    }
    property var appsAcc: ({})
    Process {
        id: appsProc
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] !== "app")
                    return;
                const cur = root.appsAcc[f[1]] ?? {};
                cur[f[2]] = f[2] === "store" ? f[3] : Number(f[3]);
                root.appsAcc[f[1]] = cur;
            }
        }
        onRunningChanged: if (!running)
            root.appSizes = Object.assign({}, root.appsAcc)
    }

    // Размеры путей данных одного приложения: путь → байт
    property var pathSizes: ({})
    function measurePaths(paths) {
        pathsProc.running = false;
        pathsProc.command = [Nix.storage, "paths", ...paths];
        pathsProc.running = true;
    }
    Process {
        id: pathsProc
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] !== "path")
                    return;
                const o = Object.assign({}, root.pathSizes);
                o[f[1]] = Number(f[2]);
                root.pathSizes = o;
            }
        }
    }

    // --- Кеш по программам («Память → Кеш») -----------------------------------
    // [{ path, size, name, icon, flatpak }] — по убыванию размера
    property var caches: []
    property var cachesAcc: []
    readonly property bool cachesLoading: cachesProc.running
    function refreshCaches() {
        if (cachesProc.running)
            return;
        cachesAcc = [];
        cachesProc.running = true;
    }
    // ~/.cache/<имя> или ~/.var/app/<ID>/cache → приложение
    function cacheOwner(path) {
        const fp = path.match(/\/\.var\/app\/([^/]+)\/cache$/);
        const key = fp ? fp[1] : path.split("/").pop();
        const e = DesktopEntries.byId(key) ?? (fp ? null : DesktopEntries.heuristicLookup(key.replace(/^\./, "")));
        // имя каталога похоже на приложение, только если правда совпадает
        const ok = e && (fp || (e.id + " " + e.name + " " + (e.startupClass ?? "")).toLowerCase().includes(key.toLowerCase().replace(/^\./, "")));
        return {
            name: ok ? e.name : key,
            icon: ok ? e.icon : (fp ? "application-x-executable" : ""),
            flatpak: fp ? fp[1] : ""
        };
    }
    Process {
        id: cachesProc
        command: [Nix.storage, "caches"]
        stdout: SplitParser {
            onRead: line => {
                const f = line.split("\t");
                if (f[0] !== "cache")
                    return;
                root.cachesAcc.push(Object.assign({
                    path: f[1],
                    size: Number(f[2])
                }, root.cacheOwner(f[1])));
            }
        }
        onRunningChanged: if (!running)
            root.caches = root.cachesAcc.slice().sort((a, b) => b.size - a.size)
    }
    // Очистить кеш выбранных путей (содержимое каталога или сам файл)
    property bool cleaningCache: false
    function cleanCaches(items) {
        if (cleaningCache || !items.length)
            return;
        lastError = "";
        lastDone = "";
        cleaningCache = true;
        // Flatpak можно проверить на запущенность — по одному
        const fp = items.length === 1 && items[0].flatpak ? ["--flatpak", items[0].flatpak] : [];
        cacheCleanProc.command = [Nix.storage, "clean", "cache", ...fp, "--", ...items.map(i => i.path)];
        cacheCleanProc.running = true;
    }
    Process {
        id: cacheCleanProc
        stderr: StdioCollector {
            id: cacheCleanErr
        }
        onExited: code => {
            root.lastError = code === 0 ? "" : cacheCleanErr.text.trim().split("\n").pop();
            root.lastDone = code === 0 ? "Кеш очищен" : "";
            root.cleaningCache = false;
            root.refreshCaches();
        }
    }

    // --- Диски -------------------------------------------------------------------
    // Все накопители и разделы (lsblk): размер, занято, куда смонтирован.
    // [{ name, model, size, removable, transport, parts: [{ path, label, fstype, size, used, avail, mount }] }]
    property var disks: []
    function refreshDisks() {
        disksProc.running = true;
    }
    function mountPart(part) {
        Quickshell.execDetached(["sh", "-c", 'udisksctl mount -b "$1" >/dev/null 2>&1; true', "sh", part.path]);
        disksTimer.restart();
    }
    function unmountPart(part) {
        Quickshell.execDetached(["sh", "-c", 'udisksctl unmount -b "$1" >/dev/null 2>&1; true', "sh", part.path]);
        disksTimer.restart();
    }
    Timer {
        id: disksTimer
        interval: 1500
        onTriggered: root.refreshDisks()
    }
    Process {
        id: disksProc
        command: ["lsblk", "-J", "-b", "-o", "NAME,PATH,TYPE,SIZE,MODEL,RM,TRAN,LABEL,FSTYPE,FSUSED,FSAVAIL,MOUNTPOINTS"]
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try {
                    j = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const mount = d => (d.mountpoints ?? []).filter(m => m)[0] ?? "";
                const flat = (n, out) => {
                    // разделы, LUKS и LVM внутри — всё, где есть файловая система
                    if (n.fstype && n.fstype !== "swap" && !["crypto_LUKS", "LVM2_member"].includes(n.fstype) || n.type === "part" && !n.children)
                        out.push({
                            path: n.path,
                            label: n.label ?? "",
                            fstype: n.fstype ?? "",
                            size: Number(n.size ?? 0),
                            used: Number(n.fsused ?? 0),
                            avail: Number(n.fsavail ?? 0),
                            mount: mount(n),
                            swap: n.fstype === "swap"
                        });
                    for (const c of n.children ?? [])
                        flat(c, out);
                    return out;
                };
                root.disks = (j.blockdevices ?? []).filter(d => d.type === "disk" && Number(d.size) > 0 && !/^(zram|loop)/.test(d.name)).map(d => ({
                            name: d.name,
                            model: (d.model ?? "").trim(),
                            size: Number(d.size),
                            removable: d.rm === true || d.rm === "1" || d.tran === "usb",
                            transport: d.tran ?? "",
                            parts: flat(d, []).filter(p => p.fstype !== "swap")
                        }));
            }
        }
    }

    // --- Действия -----------------------------------------------------------------
    property string busyId: ""
    property string lastError: ""
    property string lastDone: ""
    // what: cache | data
    function clean(app, what) {
        const p = pathsFor(app);
        if (!p || busyId)
            return;
        const kind = kindOf(app);
        const opts = kind === "flatpak" ? ["--flatpak", app.id] : appSizes[app.id]?.store ? ["--running", appSizes[app.id].store] : [];
        lastError = "";
        lastDone = "";
        busyId = app.id;
        cleanProc.what = what;
        cleanProc.paths = what === "cache" ? p.cache : p.data;
        cleanProc.command = [Nix.storage, "clean", what, ...opts, "--", ...cleanProc.paths];
        cleanProc.running = true;
    }
    Process {
        id: cleanProc
        property string what
        property var paths: []
        stderr: StdioCollector {
            id: cleanErr
        }
        onExited: code => {
            root.lastError = code === 0 ? "" : cleanErr.text.trim().split("\n").pop();
            root.lastDone = code === 0 ? (cleanProc.what === "cache" ? "Кеш очищен" : "Данные сброшены") : "";
            root.busyId = "";
            root.measurePaths(cleanProc.paths);
        }
    }

    // Удаление. Установленное через «Настройки → Система» (system.json)
    // убирается оттуда и применяется пересборкой; Flatpak, поставленный
    // вручную, — flatpak uninstall. Остальное входит в конфигурацию
    // (modules/system/packages.nix) — его удаляют там.
    function uninstallPlan(app) {
        const kind = kindOf(app);
        if (kind === "flatpak") {
            const entry = SystemConfig.get("flatpaks", []).find(f => f === app.id || f.startsWith(app.id + "//"));
            return entry ? {
                how: "system",
                key: "flatpaks",
                entry
            } : {
                how: "flatpak"
            };
        }
        if (kind === "nix") {
            const store = appSizes[app.id]?.store ?? "";
            const name = store.replace(/^\/nix\/store\/[a-z0-9]{32}-/, "");
            const entry = SystemConfig.get("extraPackages", []).find(p => name.startsWith(p.split(".").pop() + "-"));
            return entry ? {
                how: "system",
                key: "extraPackages",
                entry
            } : {
                how: "config"
            };
        }
        return {
            how: "unknown"
        };
    }
    function uninstall(app) {
        const plan = uninstallPlan(app);
        if (plan.how === "system")
            SystemConfig.removeFrom(plan.key, plan.entry);
        else if (plan.how === "flatpak") {
            busyId = app.id;
            uninstallProc.command = ["flatpak", "uninstall", "-y", "--noninteractive", app.id];
            uninstallProc.running = true;
        }
    }
    Process {
        id: uninstallProc
        stderr: StdioCollector {
            id: unErr
        }
        onExited: code => {
            root.busyId = "";
            root.lastError = code === 0 ? "" : unErr.text.trim().split("\n").pop();
            root.lastDone = code === 0 ? "Приложение удалено" : "";
        }
    }
}
