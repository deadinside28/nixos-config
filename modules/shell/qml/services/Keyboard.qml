pragma Singleton

// Текущая раскладка клавиатуры: событие activelayout от Hyprland,
// а при старте — `hyprctl devices -j` (основная клавиатура).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property string layoutName: ""
    readonly property string code: short(layoutName)

    // «Russian» → RU, «English (US)» → EN и т.д.
    function short(name) {
        if (!name)
            return "";
        const n = name.toLowerCase();
        const known = {
            "russian": "RU",
            "english": "EN",
            "ukrainian": "UA",
            "belarusian": "BY",
            "kazakh": "KZ",
            "german": "DE",
            "french": "FR",
            "spanish": "ES",
            "polish": "PL",
            "japanese": "JP"
        };
        for (const k of Object.keys(known))
            if (n.startsWith(k))
                return known[k];
        return name.slice(0, 2).toUpperCase();
    }

    function next() {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            const data = event.data;
            const i = data.lastIndexOf(",");
            const name = data.slice(i + 1);
            // виртуальные клавиатуры (wtype, ydotool) тоже шлют событие — пропускаем
            if (data.slice(0, i).includes("virtual"))
                return;
            root.layoutName = name;
        }
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    if (kb)
                        root.layoutName = kb.active_keymap;
                } catch (e) {}
            }
        }
    }
}
