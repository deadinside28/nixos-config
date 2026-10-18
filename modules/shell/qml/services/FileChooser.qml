pragma Singleton

// Запросы системного диалога выбора файлов от pixel-portal
// (modules/shell/portal/pixel-portal.py). Портал передаёт запрос JSON-ом
// через IPC (`pixel-shell filechooser request`), окно — modules/filechooser,
// ответ атомарно пишется в файл reply из запроса, портал его ждёт.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property var requests: []

    function request(json) {
        let r;
        try {
            r = JSON.parse(json);
        } catch (e) {
            console.warn("filechooser: неверный запрос", e);
            return;
        }
        requests = [...requests, r];
    }
    function cancel(id) {
        const r = requests.find(x => x.id === id);
        if (r)
            finish(r, {
                response: 2
            });
    }
    // response: 0 — выбрано, 1 — отменено пользователем, 2 — прервано
    function finish(r, reply) {
        if (!requests.some(x => x.id === r.id))
            return;
        requests = requests.filter(x => x.id !== r.id);
        const w = writer.createObject(root, {
            path: r.reply
        });
        w.setText(JSON.stringify(reply));
        if (reply.response === 0 && reply.paths?.length) {
            const p = reply.paths[0];
            Settings.data.chooserLastDir = r.directory || r.kind === "saveFiles" ? p.replace(/\/[^/]*$/, "") || p : p.slice(0, p.lastIndexOf("/"));
        }
    }
    property Component writer: Component {
        FileView {
            printErrors: false
            atomicWrites: true
            onSaved: destroy()
            onSaveFailed: destroy()
        }
    }

    // Фильтр портала → маски для FolderListModel. MIME-типы — по известным
    // расширениям; неизвестный MIME не фильтрует (лучше показать лишнее,
    // чем спрятать нужный файл).
    readonly property var mimeGlobs: ({
            "image/*": ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.svg", "*.avif", "*.heic", "*.tiff", "*.ico", "*.jxl"],
            "image/png": ["*.png"],
            "image/jpeg": ["*.jpg", "*.jpeg"],
            "image/webp": ["*.webp"],
            "image/gif": ["*.gif"],
            "image/svg+xml": ["*.svg"],
            "video/*": ["*.mp4", "*.mkv", "*.webm", "*.mov", "*.avi", "*.m4v"],
            "audio/*": ["*.mp3", "*.flac", "*.ogg", "*.opus", "*.wav", "*.m4a"],
            "text/plain": ["*.txt", "*.text", "*.log", "*.md"],
            "text/html": ["*.html", "*.htm"],
            "text/csv": ["*.csv"],
            "application/pdf": ["*.pdf"],
            "application/zip": ["*.zip"],
            "application/json": ["*.json"]
        })
    function globsFor(filter) {
        if (!filter)
            return ["*"];
        const out = [];
        for (const p of filter.patterns ?? []) {
            if (!p.mime)
                out.push(p.pattern);
            else {
                const g = mimeGlobs[p.pattern] ?? mimeGlobs[p.pattern.replace(/\/.*$/, "/*")];
                if (!g)
                    return ["*"];
                out.push(...g);
            }
        }
        return out.length ? out : ["*"];
    }
}
