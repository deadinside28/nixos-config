pragma Singleton

// Настройки окон, ввода и мониторов → Lua-файлы в ~/.config/hypr/shell/.
// hyprland.lua подключает их при старте (pcall(require, "shell.*")),
// а здесь они ещё и применяются сразу через `hyprctl eval`, без перезагрузки.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    function lua(v) {
        if (typeof v === "string")
            return JSON.stringify(v);
        if (typeof v === "boolean")
            return v ? "true" : "false";
        return String(v);
    }

    readonly property string lookLua: {
        const d = Settings.data;
        return `-- Сгенерировано оболочкой: Настройки → Рабочий стол. Не править руками.
hl.config({
    general = {
        gaps_in = ${d.gapsIn},
        gaps_out = ${d.gapsOut},
        border_size = ${d.borderSize},
    },
    decoration = {
        rounding = ${d.rounding},
        rounding_power = 2.4,
        blur = { enabled = ${lua(d.blur)} },
    },
})
hl.window_rule({
    name = "shell-opacity",
    match = { class = ".*" },
    opacity = "${d.windowOpacity} override ${d.windowOpacity} override 1.0 override",
})
`;
    }

    readonly property string inputLua: {
        const d = Settings.data;
        return `-- Сгенерировано оболочкой: Настройки → Клавиатура и мышь. Не править руками.
hl.config({
    input = {
        kb_layout = ${lua(d.kbLayout)},
        kb_options = ${lua(d.kbOptions)},
        sensitivity = ${d.mouseSensitivity.toFixed(2)},
        accel_profile = ${lua(d.accelProfile)},
        natural_scroll = ${lua(d.naturalScroll)},
        repeat_rate = ${d.repeatRate},
        repeat_delay = ${d.repeatDelay},
    },
})
`;
    }

    readonly property string monitorsLua: {
        const m = Settings.data.monitors ?? {};
        const lines = Object.keys(m).map(name => {
            const c = m[name];
            const parts = [`output = ${lua(name)}`];
            if (c.disabled)
                parts.push("disabled = true");
            else {
                parts.push(`mode = ${lua(c.mode ?? "preferred")}`);
                parts.push(`position = ${lua(c.position ?? "auto")}`);
                parts.push(`scale = ${lua(String(c.scale ?? "auto"))}`);
                if (c.vrr !== undefined)
                    parts.push(`vrr = ${c.vrr}`);
            }
            return `hl.monitor({ ${parts.join(", ")} })`;
        });
        return `-- Сгенерировано оболочкой: Настройки → Экран. Не править руками.
${lines.join("\n")}
`;
    }

    function apply(file, content) {
        file.setText(content);
        Quickshell.execDetached(["hyprctl", "eval", content]);
    }

    // Правило hl.monitor() через eval только запоминается, а уже включённые
    // выходы не перестраивает. Поэтому для мониторов — полная перезагрузка
    // конфига: hyprland.lua заново подключит shell/monitors.lua.
    function applyMonitors(content) {
        monitorsFile.setText(content);
        reloadTimer.restart();
    }
    Timer {
        id: reloadTimer
        interval: 300 // дать файлу записаться
        onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
    }

    Connections {
        target: Settings
        function onLoadedChanged() {
            if (!Settings.loaded)
                return;
            lookFile.setText(root.lookLua);
            inputFile.setText(root.inputLua);
            monitorsFile.setText(root.monitorsLua);
        }
    }

    // Пишем только после загрузки настроек, иначе при старте затрём
    // файлы значениями по умолчанию.
    onLookLuaChanged: if (Settings.loaded)
        lookTimer.restart()
    onInputLuaChanged: if (Settings.loaded)
        inputTimer.restart()
    onMonitorsLuaChanged: if (Settings.loaded)
        monitorsTimer.restart()

    Timer {
        id: lookTimer
        interval: 250
        onTriggered: root.apply(lookFile, root.lookLua)
    }
    Timer {
        id: inputTimer
        interval: 250
        onTriggered: root.apply(inputFile, root.inputLua)
    }
    Timer {
        id: monitorsTimer
        interval: 250
        onTriggered: root.applyMonitors(root.monitorsLua)
    }

    FileView {
        id: lookFile
        path: Settings.hyprDir + "/look.lua"
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: inputFile
        path: Settings.hyprDir + "/input.lua"
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: monitorsFile
        path: Settings.hyprDir + "/monitors.lua"
        printErrors: false
        atomicWrites: true
    }

    // Dispatch в Lua-синтаксисе Hyprland 0.56.
    function dispatch(expr) {
        Quickshell.execDetached(["hyprctl", "dispatch", expr]);
    }
}
