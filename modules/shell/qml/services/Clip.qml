pragma Singleton

// История буфера обмена (cliphist). Записи собирает служба cliphist
// из home-manager, здесь только чтение, выбор и удаление.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ id, text, image }]
    property var entries: []

    function refresh() {
        list.running = true;
    }

    Process {
        id: list
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.length > 0).slice(0, 200).map(l => {
                    const tab = l.indexOf("\t");
                    const id = l.slice(0, tab);
                    const body = l.slice(tab + 1);
                    return {
                        id,
                        line: l,
                        text: body,
                        image: body.startsWith("[[ binary data")
                    };
                });
            }
        }
    }

    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", entry.line]);
    }
    function remove(entry) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", entry.line]);
        entries = entries.filter(e => e.id !== entry.id);
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
    }
}
