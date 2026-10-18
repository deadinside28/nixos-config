pragma Singleton

// «Календарь»: события в ~/.local/share/pixel-calendar/events.json
// ({ schemaVersion, events: [...] }), повторения и .ics — calendar.js.
// Запись атомарная; рядом — events.json.bak, последняя читаемая копия:
// если файл не разобрался, он не перезаписывается, правки блокируются.
//
// Напоминания показывает не оболочка, а служба pixel-reminders
// (systemd --user): здесь события раскладываются на 60 дней вперёд в
// ~/.local/state/pixel-calendar/reminders.json, а служба читает его и
// работает, даже когда оболочка перезапускается.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import "calendar.js" as Cal

Singleton {
    id: root

    readonly property int schemaVersion: 1
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Settings.home + "/.local/share") + "/pixel-calendar"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Settings.home + "/.local/state") + "/pixel-calendar"

    // Каталоги — заранее: запись в несуществующую папку не удалась бы
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dataDir, stateDir])

    property var events: []
    property bool loaded: false
    property string error: ""

    FileView {
        id: file
        path: root.dataDir + "/events.json"
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (!d || !Array.isArray(d.events))
                    throw new Error("нет списка событий");
                if ((d.schemaVersion ?? 1) > root.schemaVersion)
                    throw new Error("файл от более новой версии календаря");
                root.events = d.events;
                root.error = "";
                root.loaded = true;
                if (text() !== backup.text())
                    backup.setText(text());
            } catch (e) {
                root.error = "events.json не читается (" + (e.message ?? e) + "). Правки отключены; последняя рабочая копия — events.json.bak.";
            }
            root.writeReminders();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.events = [];
                root.loaded = true;
                root.error = "";
            }
        }
    }
    FileView {
        id: backup
        path: root.dataDir + "/events.json.bak"
        printErrors: false
        blockLoading: true
    }
    function save(list) {
        if (error)
            return false;
        events = list;
        Quickshell.execDetached(["mkdir", "-p", dataDir, stateDir]);
        file.setText(JSON.stringify({
            schemaVersion,
            events: list
        }, null, 1) + "\n");
        writeReminders();
        return true;
    }

    function newId() {
        return "ev-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 1e6).toString(36);
    }
    function upsert(ev) {
        const list = events.filter(e => e.id !== ev.id);
        list.push(ev);
        return save(list);
    }
    function remove(id) {
        return save(events.filter(e => e.id !== id));
    }
    // Убрать одно вхождение повторяющегося события
    function skipOccurrence(id, start) {
        return save(events.map(e => e.id === id ? Object.assign({}, e, {
                exdates: [...(e.exdates ?? []), Cal.dateKey(start)]
            }) : e));
    }

    function occurrences(from, to) {
        return Cal.expand(events, from, to);
    }
    function dayKey(d) {
        return Cal.dateKey(d);
    }
    function parseLocal(s) {
        return Cal.parseLocal(s);
    }
    function formatLocal(d, allDay) {
        return Cal.formatLocal(d, allDay);
    }

    // --- Напоминания ----------------------------------------------------------
    FileView {
        id: remFile
        path: root.stateDir + "/reminders.json"
        printErrors: false
        atomicWrites: true
    }
    function writeReminders() {
        if (!loaded)
            return;
        Quickshell.execDetached(["mkdir", "-p", stateDir]);
        remFile.setText(JSON.stringify(Cal.reminders(events, new Date(), 60)));
    }
    Timer {
        // окно в 60 дней сдвигается — пересчитываем несколько раз в день
        running: root.loaded
        interval: 6 * 3600 * 1000
        repeat: true
        onTriggered: root.writeReminders()
    }

    // --- .ics ------------------------------------------------------------------
    property string icsMessage: ""
    function importIcs(path) {
        importProc.command = ["cat", "--", path];
        importProc.running = true;
    }
    Process {
        id: importProc
        stdout: StdioCollector {
            onStreamFinished: {
                const got = Cal.parseIcs(text);
                if (!got.length) {
                    root.icsMessage = "В файле нет событий";
                    return;
                }
                // тот же UID — обновить, а не задвоить
                const ids = {};
                for (const e of got)
                    ids[e.id] = true;
                if (root.save([...root.events.filter(e => !ids[e.id]), ...got]))
                    root.icsMessage = "Импортировано событий: " + got.length;
            }
        }
    }
    FileView {
        id: exportFile
        printErrors: false
        atomicWrites: true
        onSaved: root.icsMessage = "Сохранено: " + path.replace(Settings.home, "~")
        onSaveFailed: root.icsMessage = "Не удалось сохранить " + path
    }
    function exportIcs(path) {
        exportFile.path = path;
        exportFile.setText(Cal.toIcs(events));
    }
}
