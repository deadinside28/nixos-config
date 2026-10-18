pragma Singleton

// Режимы окон: Лента / Мозаика / Главное окно / Смешанный / Плавающие —
// общий для всех рабочих столов и свой для отдельного стола, без выхода
// из сессии.
//
// Общий режим — Settings.data.windowMode (tiled | mixed | floating) плюс
// раскладка тайлинга Settings.data.layout (scrolling | dwindle | master).
// Свой режим стола — пресет в Settings.data.workspaceModes { "3": "dwindle" }.
// «Смешанный» — тайлинг, но приложения из Settings.data.floatApps плавают.
//
// Новые окна расставляют правила Hyprland (HyprConf.modesLua). Уже
// открытые окна при смене режима перекладываются здесь: плавающими
// делаются те, кому это положено по режиму, а обратно в тайлинг
// возвращаются только окна, которые сделал плавающими сам режим, —
// диалоги и окна, плавающие по своим правилам, остаются как были.
// Hyprland помнит последнюю плавающую геометрию окна, поэтому при
// возврате в плавающий режим окна встают на прежние места.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.common

Singleton {
    id: root

    // Пресеты в порядке переключения (горячая клавиша, плитка шторки)
    readonly property var presets: [
        {
            value: "scrolling",
            label: "Лента",
            icon: "view_column"
        },
        {
            value: "dwindle",
            label: "Мозаика",
            icon: "dashboard"
        },
        {
            value: "master",
            label: "Главное окно",
            icon: "view_quilt"
        },
        {
            value: "mixed",
            label: "Смешанный",
            icon: "auto_awesome_mosaic"
        },
        {
            value: "floating",
            label: "Плавающие",
            icon: "select_window"
        }
    ]
    function presetInfo(p) {
        return presets.find(x => x.value === p) ?? presets[0];
    }

    // Пресет общего режима
    readonly property string globalPreset: {
        const m = Settings.data.windowMode;
        return m === "floating" || m === "mixed" ? m : Settings.data.layout;
    }
    function modeOf(preset) {
        return preset === "floating" || preset === "mixed" ? preset : "tiled";
    }
    function layoutOf(preset) {
        return preset === "scrolling" || preset === "dwindle" || preset === "master" ? preset : Settings.data.layout;
    }
    // Свой пресет стола или "" — как везде
    function workspacePreset(id) {
        return (Settings.data.workspaceModes ?? {})[String(id)] ?? "";
    }
    function effectivePreset(id) {
        return workspacePreset(id) || globalPreset;
    }

    function setGlobal(preset) {
        if (preset === "floating" || preset === "mixed") {
            Settings.data.windowMode = preset;
        } else {
            Settings.data.windowMode = "tiled";
            Settings.data.layout = preset;
        }
        reconcileSoon();
    }
    // preset "" — снять свой режим, стол снова как все
    function setWorkspace(id, preset) {
        const w = Object.assign({}, Settings.data.workspaceModes ?? {});
        if (preset)
            w[String(id)] = preset;
        else
            delete w[String(id)];
        Settings.data.workspaceModes = w;
        reconcileSoon();
    }
    readonly property int activeWorkspace: Hyprland.focusedWorkspace?.id ?? 0
    // Следующий режим для текущего стола (Super+Shift+Пробел, плитка шторки)
    function cycleActive() {
        const id = activeWorkspace;
        if (id <= 0)
            return;
        const cur = effectivePreset(id);
        const i = presets.findIndex(x => x.value === cur);
        const next = presets[(i + 1) % presets.length].value;
        setWorkspace(id, next === globalPreset ? "" : next);
        Quickshell.execDetached(["notify-send", "-a", "Окна", "-t", "1500", "-i", "preferences-system-windows", "-h", "string:x-canonical-private-synchronous:pixel-window-mode", "Рабочий стол " + id + ": " + presetInfo(next).label]);
    }

    // Регулярное выражение классов для «Смешанного»
    readonly property string floatRx: {
        const apps = (Settings.data.floatApps ?? []).filter(a => a);
        return apps.length ? "^(" + apps.map(a => a.replace(/[\^$.*+?()[\]{}|\\]/g, "\\$&")).join("|") + ")$" : "";
    }

    // --- Уже открытые окна ---------------------------------------------------
    // Адреса окон, которые сделал плавающими режим (а не пользователь)
    property var modeFloated: ({})
    function reconcileSoon() {
        reconcileTimer.restart();
    }
    Timer {
        id: reconcileTimer
        interval: 300
        onTriggered: clients.running = true
    }
    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.reconcile(list);
            }
        }
    }
    function reconcile(list) {
        const rx = floatRx ? new RegExp(floatRx) : null;
        const tracked = Object.assign({}, modeFloated);
        const alive = {};
        for (const c of list) {
            const ws = c.workspace?.id ?? 0;
            if (ws <= 0 || !c.mapped)
                continue;
            alive[c.address] = true;
            const mode = modeOf(effectivePreset(ws));
            const want = mode === "floating" || (mode === "mixed" && rx !== null && rx.test(c.class ?? ""));
            const sel = `"address:${c.address}"`;
            if (want && !c.floating) {
                Hyprland.dispatch(`hl.dsp.window.float({ action = "enable", window = ${sel} })`);
                tracked[c.address] = true;
            } else if (!want && tracked[c.address]) {
                if (c.floating)
                    Hyprland.dispatch(`hl.dsp.window.float({ action = "disable", window = ${sel} })`);
                delete tracked[c.address];
            }
        }
        for (const a in tracked)
            if (!alive[a])
                delete tracked[a];
        modeFloated = tracked;
    }
}
