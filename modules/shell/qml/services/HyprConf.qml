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
        blur = {
            enabled = ${lua(d.blur)},
            passes = ${d.blurPasses},
            size = ${d.blurSize},
            xray = ${lua(d.blurXray)},
            new_optimizations = true,
        },
        shadow = { enabled = ${lua(d.shadows)} },
        -- прозрачность окон — параметрами, а не правилом: правило при каждом
        -- изменении заново применялось ко всем окнам и двигало плавающие
        active_opacity = ${d.windowOpacity},
        inactive_opacity = ${d.windowOpacity},
        fullscreen_opacity = 1.0,
    },
})
`;
    }

    // Анимации окон — из той же таблицы движения, что и у панелей оболочки
    // (Theme.anim): те же кривые M3 и длительности, одна шкала скорости.
    // Пружины масштабируются с сохранением демпфирования ζ: k' = k / s²,
    // c' = 2ζ√k' — движение то же, только быстрее или медленнее.
    readonly property string animLua: {
        const s = Settings.data.animationScale;
        const on = s >= 0.05;
        const spring = (name, k, z) => {
            const kk = k / (s * s);
            return `hl.curve("${name}", { type = "spring", mass = 1, stiffness = ${kk.toFixed(2)}, dampening = ${(2 * z * Math.sqrt(kk)).toFixed(2)} })`;
        };
        const bez = (name, p) => `hl.curve("${name}", { type = "bezier", points = { {${p[0]}, ${p[1]}}, {${p[2]}, ${p[3]}} } })`;
        // длительность в мс → speed Hyprland (десятые доли секунды)
        const sp = ms => (ms / 100 * s).toFixed(2);
        const a = Theme.anim;
        const anim = (leaf, extra) => `hl.animation({ leaf = "${leaf}", enabled = true, ${extra} })`;
        return `-- Сгенерировано оболочкой: Настройки → Рабочий стол и окна. Не править руками.
hl.config({ animations = { enabled = ${lua(on)} } })
${spring("m3FastSpatial", 800, 0.6)}
${spring("m3DefaultSpatial", 380, 0.8)}
${spring("m3SlowSpatial", 200, 0.8)}
${spring("m3DefaultSpatialCalm", 380, 1)}
${spring("m3DefaultEffects", 1600, 1)}
${spring("m3FastEffects", 3800, 1)}
${bez("m3EmphasizedDecel", a.emphasizedDecel)}
${bez("m3EmphasizedAccel", a.emphasizedAccel)}
${bez("m3Standard", a.standard)}
${anim("global", `speed = ${sp(300)}, bezier = "m3Standard"`)}
${anim("windowsIn", `speed = ${sp(300)}, bezier = "m3EmphasizedDecel", style = "popin 85%"`)}
${anim("windowsOut", `speed = ${sp(200)}, bezier = "m3EmphasizedAccel", style = "popin 85%"`)}
${anim("windowsMove", `speed = ${sp(300)}, spring = "m3DefaultSpatialCalm"`)}
${anim("fadeIn", `speed = ${sp(200)}, spring = "m3DefaultEffects"`)}
${anim("fadeOut", `speed = ${sp(150)}, bezier = "m3EmphasizedAccel"`)}
${anim("fadeSwitch", `speed = ${sp(200)}, spring = "m3DefaultEffects"`)}
${anim("fadeDim", `speed = ${sp(200)}, spring = "m3DefaultEffects"`)}
${anim("border", `speed = ${sp(200)}, spring = "m3FastEffects"`)}
${anim("workspaces", `speed = ${sp(450)}, spring = "m3SlowSpatial", style = "slidefadevert 15%"`)}
${anim("specialWorkspace", `speed = ${sp(450)}, spring = "m3SlowSpatial", style = "slidefadevert 20%"`)}
${anim("zoomFactor", `speed = ${sp(300)}, spring = "m3DefaultSpatial"`)}
${anim("layers", `speed = ${sp(200)}, spring = "m3DefaultEffects"`)}
${anim("layersIn", `speed = ${sp(200)}, spring = "m3DefaultEffects", style = "fade"`)}
${anim("layersOut", `speed = ${sp(150)}, bezier = "m3EmphasizedAccel", style = "fade"`)}
`;
    }

    readonly property string tilingLua: {
        const d = Settings.data;
        return `-- Сгенерировано оболочкой: Настройки → Окна и тайлинг. Не править руками.
hl.config({
    general = {
        layout = ${lua(d.layout)},
        resize_on_border = ${lua(d.resizeOnBorder)},
        allow_tearing = ${lua(d.allowTearing)},
        snap = { enabled = ${lua(d.snapEnabled)} },
    },
    input = { follow_mouse = ${d.followMouse} },
    misc = { focus_on_activate = ${lua(d.focusOnActivate)} },
    scrolling = {
        column_width = ${Number(d.scrollColumnWidth).toFixed(2)},
        fullscreen_on_one_column = ${lua(d.scrollFullscreenOne)},
        focus_fit_method = ${d.scrollFocusFit},
        follow_focus = ${lua(d.scrollFollowFocus)},
    },
    dwindle = {
        preserve_split = ${lua(d.dwindlePreserveSplit)},
        smart_split = ${lua(d.dwindleSmartSplit)},
    },
    master = {
        mfact = ${Number(d.masterMfact).toFixed(2)},
        new_status = ${lua(d.masterNewStatus)},
        orientation = ${lua(d.masterOrientation)},
    },
})
`;
    }

    // Действие бинда → выражение hl.dsp
    function bindExpr(b) {
        const n = parseInt(b.arg) || 1;
        switch (b.action) {
        case "exec":
            return `hl.dsp.exec_cmd(${lua(b.arg ?? "")})`;
        case "app":
            return `hl.dsp.exec_cmd(${lua("gtk-launch " + (b.arg ?? ""))})`;
        case "shell":
            return `hl.dsp.exec_cmd(${lua("pixel-shell " + (b.arg ?? ""))})`;
        case "close":
            return "hl.dsp.window.close()";
        case "float":
            return `hl.dsp.window.float({ action = "toggle" })`;
        case "fullscreen":
            return "hl.dsp.window.fullscreen()";
        case "maximize":
            return "hl.dsp.window.fullscreen({ mode = 1 })";
        case "pin":
            return "hl.dsp.window.pin()";
        case "workspace":
            return `hl.dsp.focus({ workspace = ${n} })`;
        case "movetows":
            return `hl.dsp.window.move({ workspace = ${n} })`;
        case "focus":
            return `hl.dsp.focus({ direction = ${lua(b.arg || "left")} })`;
        }
        return "";
    }
    function bindKey(b) {
        return (b.mods ? b.mods + " + " : "") + b.key;
    }

    readonly property string bindsLua: {
        const d = Settings.data;
        const off = d.disabledBinds.map(k => `hl.unbind(${lua(k)})`);
        const on = (d.userBinds ?? []).filter(b => b.key && bindExpr(b)).map(b => `hl.bind(${lua(bindKey(b))}, ${bindExpr(b)})`);
        return `-- Сгенерировано оболочкой: Настройки → Клавиатура и мышь. Не править руками.
${off.join("\n")}
${on.join("\n")}
`;
    }

    // Регулярное выражение по точному имени, если не похоже на regex
    function rx(s) {
        if (!s)
            return "";
        return /[\^$.*+?()[\]|]/.test(s) ? s : "^(" + s + ")$";
    }

    readonly property string rulesLua: {
        const rules = (Settings.data.userRules ?? []).filter(r => r.cls || r.title).map(r => {
            const match = [];
            if (r.cls)
                match.push(`class = ${lua(r.exact ? "^(" + r.cls.replace(/[\^$.*+?()[\]{}|\\]/g, "\\$&") + ")$" : rx(r.cls))}`);
            if (r.title)
                match.push(`title = ${lua(rx(r.title))}`);
            const fx = [`match = { ${match.join(", ")} }`];
            if (r.float)
                fx.push("float = true");
            else if (r.tile && !r.fullscreen)
                fx.push("tile = true");
            if (r.center)
                fx.push("center = true");
            if (r.pin)
                fx.push("pin = true");
            if (r.fullscreen)
                fx.push("fullscreen = true");
            if (r.noBlur)
                fx.push("no_blur = true");
            if (r.opaque)
                fx.push("opaque = true");
            if (r.workspace)
                fx.push(`workspace = ${lua(String(r.workspace))}`);
            if (r.monitor)
                fx.push(`monitor = ${lua(r.monitor)}`);
            if (r.width && r.height)
                fx.push(`size = { ${lua(String(r.width))}, ${lua(String(r.height))} }`);
            if (r.opacity && r.opacity < 1)
                fx.push(`opacity = "${r.opacity} override ${r.opacity} override"`);
            return `hl.window_rule({ ${fx.join(", ")} })`;
        });
        return `-- Сгенерировано оболочкой: Настройки → Окна и тайлинг. Не править руками.
${rules.join("\n")}
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
            tilingFile.setText(root.tilingLua);
            animFile.setText(root.animLua);
            bindsFile.setText(root.bindsLua);
            rulesFile.setText(root.rulesLua);
            recordFile.setText(root.recordEnv);
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
    onTilingLuaChanged: if (Settings.loaded)
        tilingTimer.restart()
    onAnimLuaChanged: if (Settings.loaded)
        animTimer.restart()
    // Бинды и правила через eval дублировались бы — для них перезагрузка
    onBindsLuaChanged: if (Settings.loaded)
        bindsTimer.restart()
    onRulesLuaChanged: if (Settings.loaded)
        rulesTimer.restart()

    Timer {
        id: tilingTimer
        interval: 250
        onTriggered: root.apply(tilingFile, root.tilingLua)
    }
    Timer {
        id: bindsTimer
        interval: 400
        onTriggered: {
            bindsFile.setText(root.bindsLua);
            reloadTimer.restart();
        }
    }
    Timer {
        id: rulesTimer
        interval: 400
        onTriggered: {
            rulesFile.setText(root.rulesLua);
            reloadTimer.restart();
        }
    }
    Timer {
        id: animTimer
        interval: 250
        onTriggered: root.apply(animFile, root.animLua)
    }
    FileView {
        id: animFile
        path: Settings.hyprDir + "/animations.lua"
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: tilingFile
        path: Settings.hyprDir + "/tiling.lua"
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: bindsFile
        path: Settings.hyprDir + "/binds.lua"
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: rulesFile
        path: Settings.hyprDir + "/rules.lua"
        printErrors: false
        atomicWrites: true
    }

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

    // Параметры записи экрана — для pixel-record (shell-файл, его source-ят)
    readonly property string recordEnv: {
        const d = Settings.data;
        const q = v => "'" + String(v).replace(/'/g, "'\\''") + "'";
        return `REC_FPS=${q(d.recFps)}
REC_CODEC=${q(d.recCodec)}
REC_QUALITY=${q(d.recQuality)}
REC_CONTAINER=${q(d.recContainer)}
REC_CURSOR=${q(d.recCursor ? "yes" : "no")}
REC_DIR=${q(d.recDir)}
`;
    }
    onRecordEnvChanged: if (Settings.loaded)
        recordFile.setText(recordEnv)
    FileView {
        id: recordFile
        path: Settings.stateDir + "/record.env"
        printErrors: false
        atomicWrites: true
    }

    // Dispatch в Lua-синтаксисе Hyprland 0.56.
    function dispatch(expr) {
        Quickshell.execDetached(["hyprctl", "dispatch", expr]);
    }
}
