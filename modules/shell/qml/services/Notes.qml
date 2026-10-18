pragma Singleton

// «Заметки»: обычные Markdown-файлы в папке заметок (по умолчанию
// ~/Documents/Заметки), подпапки — папки заметок. Формат переносимый:
// заметки открываются любым редактором, синхронизируются и резервируются
// как обычные файлы, а к кешу приложения отношения не имеют. Индекса нет —
// список и поиск строятся по самим файлам (find / grep).
//
// Сохранение — автоматическое и атомарное (FileView.atomicWrites): файл
// заменяется только целиком записанным новым, поэтому аварийное закрытие
// не оставляет обрезанную заметку.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property string dir: Settings.data.notesDir || Settings.home + "/Documents/Заметки"
    // [{ path, rel, title, folder, mtime }]
    property var notes: []
    readonly property var folders: {
        const set = {};
        for (const n of notes)
            if (n.folder)
                set[n.folder] = true;
        return Object.keys(set).sort((a, b) => a.localeCompare(b));
    }
    function isPinned(path) {
        return (Settings.data.notesPinned ?? []).includes(path.slice(dir.length + 1));
    }
    function setPinned(path, on) {
        const rel = path.slice(dir.length + 1);
        const list = (Settings.data.notesPinned ?? []).filter(p => p !== rel);
        Settings.data.notesPinned = on ? [...list, rel] : list;
    }

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }
    Process {
        id: listProc
        command: ["sh", "-c", 'mkdir -p "$1" && cd "$1" && find . -name "*.md" -not -path "*/.*" -printf "%T@\\t%P\\n"', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.notes = text.split("\n").filter(l => l.includes("\t")).map(l => {
                const t = l.indexOf("\t");
                const rel = l.slice(t + 1);
                const slash = rel.lastIndexOf("/");
                return {
                    path: root.dir + "/" + rel,
                    rel,
                    title: rel.slice(slash + 1).replace(/\.md$/, ""),
                    folder: slash > 0 ? rel.slice(0, slash) : "",
                    mtime: new Date(parseFloat(l.slice(0, t)) * 1000)
                };
            }).sort((a, b) => (root.isPinned(b.path) - root.isPinned(a.path)) || (b.mtime - a.mtime))
        }
    }

    // Поиск по тексту: пути заметок, где встречается запрос
    property var matches: null // null — поиска нет
    function search(q) {
        searchProc.running = false;
        if (!q.trim()) {
            matches = null;
            return;
        }
        searchProc.command = ["grep", "-r", "-i", "-l", "-F", "--include=*.md", "--", q.trim(), dir];
        searchProc.running = true;
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: root.matches = text.split("\n").filter(l => l)
        }
    }

    // Свободное имя файла для заголовка
    function safeName(title) {
        return (title || "Без названия").replace(/[\/\\:*?"<>|\x00-\x1f]/g, " ").replace(/^\.+/, "").trim().slice(0, 120) || "Без названия";
    }
    function uniquePath(folder, title, except) {
        const base = dir + (folder ? "/" + folder : "") + "/" + safeName(title);
        let p = base + ".md";
        let n = 2;
        while (p !== except && notes.some(x => x.path === p))
            p = base + " (" + n++ + ").md";
        return p;
    }
    // Новая заметка: файл создаётся сразу, чтобы появиться в списке
    function create(folder) {
        const stamp = new Date().toLocaleString(Qt.locale("ru_RU"), "d MMMM yyyy, HH.mm");
        const p = uniquePath(folder, "Заметка " + stamp);
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && [ ! -e "$1" ] && : > "$1"', "sh", p]);
        refreshSoon.restart();
        return p;
    }
    // Переименование файла по новому заголовку; mv -n — не затирать чужое
    function rename(path, title, cb) {
        const n = notes.find(x => x.path === path);
        const target = uniquePath(n?.folder ?? "", title, path);
        if (target === path) {
            cb(path);
            return;
        }
        const wasPinned = isPinned(path);
        renameProc.cb = cb;
        renameProc.target = target;
        renameProc.pin = wasPinned;
        renameProc.from = path;
        renameProc.command = ["mv", "-n", "--", path, target];
        renameProc.running = true;
    }
    Process {
        id: renameProc
        property var cb
        property string target
        property string from
        property bool pin
        onExited: code => {
            const ok = code === 0;
            if (ok && renameProc.pin) {
                root.setPinned(renameProc.from, false);
                root.setPinned(renameProc.target, true);
            }
            renameProc.cb(ok ? renameProc.target : renameProc.from);
            root.refresh();
        }
    }
    function moveTo(path, folder, cb) {
        const n = notes.find(x => x.path === path);
        const target = uniquePath(folder, n?.title ?? "Заметка");
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && mv -n -- "$1" "$2"', "sh", path, target]);
        refreshSoon.restart();
        cb(target);
    }
    // В корзину, а не насовсем
    function trash(path) {
        Quickshell.execDetached(["gio", "trash", "--", path]);
        setPinned(path, false);
        refreshSoon.restart();
    }
    Timer {
        id: refreshSoon
        interval: 300
        onTriggered: root.refresh()
    }
}
