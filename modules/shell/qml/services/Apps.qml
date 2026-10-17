pragma Singleton

// Приложения из .desktop файлов: поиск, запуск, частота использования.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common

Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(a => !a.noDisplay).sort((a, b) => a.name.localeCompare(b.name))

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

    function launch(app) {
        Settings.bumpUsage(app.id);
        run(app.runInTerminal ? [Nix.terminal, "-e", ...app.command] : app.command, app.workingDirectory);
    }

    function byId(id) {
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }

    // Окно → .desktop: по app_id/классу, как это делает heuristicLookup.
    function forWindow(appId) {
        if (!appId)
            return null;
        return DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId);
    }
}
