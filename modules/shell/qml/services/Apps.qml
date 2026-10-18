pragma Singleton

// Приложения из .desktop файлов: поиск, запуск, частота использования.
//
// Меню настраивается поверх исходных .desktop — сами файлы (в том числе
// из /nix/store) не редактируются. Правки живут в настройках оболочки:
//   appOverrides { "<desktop id>": { name, icon, folder, keywords, args,
//                                    env, cwd, terminal, hidden } }
//   customApps   [{ id, name, icon, command, folder, keywords, cwd, terminal }]
// и накладываются здесь, поэтому переживают обновление пакета. Запись
// узнаётся по desktop ID, а не по названию. Аргументы и переменные
// окружения разбираются в argv (splitArgs) — без сборки shell-строки.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

Singleton {
    id: root

    // Все записи, включая скрытые пользователем (для редактора меню)
    readonly property var everything: {
        const ov = Settings.data.appOverrides ?? {};
        const origins = root.origins;
        const list = DesktopEntries.applications.values.filter(a => !a.noDisplay).map(e => wrap(e, ov[e.id] ?? {}, origins));
        for (const c of Settings.data.customApps ?? [])
            list.push(wrapCustom(c));
        // Одинаковые названия из разных источников — подписываем источник
        const count = {};
        for (const a of list)
            count[a.name] = (count[a.name] ?? 0) + 1;
        for (const a of list)
            a.duplicate = count[a.name] > 1;
        return list.sort((a, b) => a.name.localeCompare(b.name));
    }
    readonly property var all: everything.filter(a => !a.hidden)

    function wrap(e, o, origins) {
        const terminal = o.terminal === "yes" ? true : o.terminal === "no" ? false : e.runInTerminal;
        return {
            id: e.id,
            entry: e,
            custom: false,
            name: o.name || e.name,
            icon: o.icon || e.icon,
            genericName: e.genericName,
            comment: e.comment,
            categories: e.categories,
            keywords: [...(e.keywords ?? []), ...splitWords(o.keywords)],
            actions: e.actions,
            command: e.command,
            execString: e.execString,
            workingDirectory: o.cwd || e.workingDirectory,
            runInTerminal: terminal,
            args: o.args ?? "",
            env: o.env ?? "",
            folder: o.folder ?? "",
            hidden: !!o.hidden,
            edited: Object.keys(o).length > 0,
            origin: originOf(e, origins[e.id] ?? "")
        };
    }
    function wrapCustom(c) {
        return {
            id: c.id,
            entry: null,
            custom: true,
            name: c.name || c.command || "Команда",
            icon: c.icon || "application-x-executable",
            genericName: "",
            comment: c.command,
            categories: [],
            keywords: splitWords(c.keywords),
            actions: [],
            command: splitArgs(c.command ?? ""),
            execString: c.command ?? "",
            workingDirectory: c.cwd ?? "",
            runInTerminal: !!c.terminal,
            args: "",
            env: c.env ?? "",
            folder: c.folder ?? "",
            hidden: !!c.hidden,
            edited: true,
            origin: "Своя команда"
        };
    }

    // --- Источник записи -------------------------------------------------------
    // Путь .desktop по desktop ID — из XDG_DATA_DIRS, как их ищет и Quickshell
    // (первый найденный выигрывает).
    property var origins: ({})
    readonly property int entryCount: DesktopEntries.applications.values.length
    onEntryCountChanged: originsTimer.restart()
    Component.onCompleted: originsTimer.start()
    Timer {
        id: originsTimer
        interval: 500
        onTriggered: originsProc.running = true
    }
    Process {
        id: originsProc
        command: ["sh", "-c", `
            IFS=:
            for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                [ -d "$d/applications" ] || continue
                find -L "$d/applications" -name '*.desktop' 2>/dev/null | while IFS= read -r f; do
                    rel=\${f#"$d/applications/"}
                    printf '%s\\t%s\\n' "$(printf '%s' "\${rel%.desktop}" | tr / -)" "$f"
                done
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const t = l.indexOf("\t");
                    if (t > 0 && !(l.slice(0, t) in o))
                        o[l.slice(0, t)] = l.slice(t + 1);
                }
                root.origins = o;
            }
        }
    }
    function originOf(e, path) {
        const home = Settings.home;
        if (/appimage/i.test(e.execString ?? "") || e.id.startsWith("appimage-"))
            return "AppImage";
        if (e.id.startsWith("pixel-files-"))
            return "Добавлено из «Файлов»";
        if (path.includes("/flatpak/exports/"))
            return "Flatpak";
        if (e.id.startsWith("cpak") || path.includes("/cpak/"))
            return "cpak";
        if (path.startsWith("/run/current-system/sw/"))
            return "Nix · система";
        if (path.startsWith("/etc/profiles/per-user/") || path.startsWith(home + "/.nix-profile/") || path.startsWith(home + "/.local/state/nix/"))
            return "Nix · Home Manager";
        if (path.startsWith(home + "/.local/share/applications/"))
            return "Своя запись";
        return path ? "Другое" : "";
    }

    // --- Правка меню -----------------------------------------------------------
    function override(id) {
        return (Settings.data.appOverrides ?? {})[id] ?? {};
    }
    // Пустое значение убирает поле — снова как в .desktop
    function setOverride(id, key, value) {
        const all = Object.assign({}, Settings.data.appOverrides ?? {});
        const o = Object.assign({}, all[id] ?? {});
        if (value === "" || value === false || value === undefined || value === null)
            delete o[key];
        else
            o[key] = value;
        if (Object.keys(o).length)
            all[id] = o;
        else
            delete all[id];
        Settings.data.appOverrides = all;
    }
    function resetOverride(id) {
        const all = Object.assign({}, Settings.data.appOverrides ?? {});
        delete all[id];
        Settings.data.appOverrides = all;
    }
    function addCustom(name, command) {
        const id = "pixel-custom-" + Date.now().toString(36);
        Settings.data.customApps = [...(Settings.data.customApps ?? []), {
                id,
                name,
                command,
                icon: "",
                terminal: false
            }];
        return id;
    }
    function setCustom(id, key, value) {
        Settings.data.customApps = (Settings.data.customApps ?? []).map(c => {
            if (c.id !== id)
                return c;
            const n = Object.assign({}, c);
            n[key] = value;
            return n;
        });
    }
    function removeCustom(id) {
        Settings.data.customApps = (Settings.data.customApps ?? []).filter(c => c.id !== id);
        Settings.unpin(id);
    }
    readonly property var folders: {
        const set = {};
        for (const a of all)
            if (a.folder)
                set[a.folder] = true;
        return Object.keys(set).sort((a, b) => a.localeCompare(b));
    }

    // --- Лаунчер ---------------------------------------------------------------
    function sorted(list) {
        if (Settings.data.launcherSort !== "usage")
            return list;
        const u = Settings.data.appUsage;
        return [...list].sort((a, b) => (u[b.id] ?? 0) - (u[a.id] ?? 0) || a.name.localeCompare(b.name));
    }
    // Сетка без поиска: папки (как плитки) и приложения вне папок;
    // внутри папки — её приложения
    function launcherItems(folder) {
        if (folder)
            return sorted(all.filter(a => a.folder === folder));
        const out = folders.map(f => ({
                    id: "folder:" + f,
                    isFolder: true,
                    folder: f,
                    name: f,
                    icon: "folder",
                    count: all.filter(a => a.folder === f).length
                }));
        return [...out, ...sorted(all.filter(a => !a.folder))];
    }

    readonly property var frequent: {
        const u = Settings.data.appUsage;
        return all.filter(a => (u[a.id] ?? 0) > 0).sort((a, b) => (u[b.id] ?? 0) - (u[a.id] ?? 0)).slice(0, 8);
    }

    // Нечёткий поиск: начало названия > начало слова > подстрока > буквы по порядку.
    function score(app, q) {
        const name = app.name.toLowerCase();
        const generic = (app.genericName ?? "").toLowerCase();
        const kw = (app.keywords ?? []).join(" ").toLowerCase();
        const id = app.id.toLowerCase();
        let s = 0;
        if (name === q)
            s = 1000;
        else if (name.startsWith(q))
            s = 800;
        else if (name.split(/[\s\-_.]/).some(w => w.startsWith(q)))
            s = 600;
        else if (name.includes(q))
            s = 400;
        else if (generic.includes(q) || kw.includes(q) || id.includes(q))
            s = 250;
        else {
            let i = 0;
            for (const ch of name) {
                if (ch === q[i])
                    i++;
                if (i === q.length)
                    break;
            }
            if (i === q.length)
                s = 100;
        }
        if (s > 0)
            s += Math.min(50, (Settings.data.appUsage[app.id] ?? 0) * 2);
        return s;
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        if (!q)
            return all;
        return all.map(a => ({
                    a,
                    s: score(a, q)
                })).filter(x => x.s > 0).sort((x, y) => y.s - x.s).map(x => x.a);
    }

    // Каждое приложение — в своём systemd-scope: перезапуск оболочки
    // (например, после nixos-rebuild) не убивает то, что из неё запущено.
    function run(command, workingDirectory) {
        Quickshell.execDetached({
            command: ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--slice=app.slice", "--", ...command],
            workingDirectory: workingDirectory || Settings.home
        });
    }

    // Команда запуска с правками меню: аргументы — в конец, переменные —
    // через env, терминал — снаружи
    function commandFor(app) {
        let cmd = [...(app.command ?? []), ...splitArgs(app.args)];
        const env = splitArgs(app.env).filter(v => /^[A-Za-z_][A-Za-z0-9_]*=/.test(v));
        if (env.length)
            cmd = ["env", ...env, ...cmd];
        return app.runInTerminal ? [Nix.terminal, "-e", ...cmd] : cmd;
    }
    function launch(app) {
        if (!app || app.isFolder || !(app.command ?? []).length)
            return;
        Settings.bumpUsage(app.id);
        run(commandFor(app), app.workingDirectory);
    }

    function byId(id) {
        const hit = everything.find(a => a.id === id);
        if (hit)
            return hit;
        const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
        return e ? everything.find(a => a.id === e.id) ?? wrap(e, override(e.id), origins) : null;
    }

    // Окно → .desktop: по app_id/классу, как это делает heuristicLookup.
    function forWindow(appId) {
        if (!appId)
            return null;
        return byId(appId);
    }

    // --- Разбор строк ------------------------------------------------------------
    // Как в .desktop и shell, но без исполнения: пробелы делят слова,
    // '…' и "…" — дословно, \ экранирует следующий символ.
    function splitArgs(s) {
        const out = [];
        let cur = "", has = false, q = "";
        for (let i = 0; i < (s ?? "").length; i++) {
            const ch = s[i];
            if (q) {
                if (ch === q)
                    q = "";
                else if (ch === "\\" && q === '"' && i + 1 < s.length)
                    cur += s[++i];
                else
                    cur += ch;
            } else if (ch === "'" || ch === '"') {
                q = ch;
                has = true;
            } else if (ch === "\\" && i + 1 < s.length) {
                cur += s[++i];
                has = true;
            } else if (/\s/.test(ch)) {
                if (has || cur)
                    out.push(cur);
                cur = "";
                has = false;
            } else {
                cur += ch;
                has = true;
            }
        }
        if (has || cur)
            out.push(cur);
        return out;
    }
    function splitWords(s) {
        return String(s ?? "").split(/[,;\s]+/).filter(w => w);
    }
}
