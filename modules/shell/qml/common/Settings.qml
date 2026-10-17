pragma Singleton

// Настройки оболочки. Живут в ~/.local/state/pixel-shell/settings.json —
// обычный файл, который оболочка пишет сама при каждом изменении в
// «Настройках». Конфиг Nix сюда не лезет: что выбрал мышкой, то и
// остаётся после пересборки.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/pixel-shell"
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config")
    readonly property string hyprDir: configDir + "/hypr/shell"

    property alias data: adapter
    readonly property bool loaded: file.loaded

    FileView {
        id: file
        path: root.stateDir + "/settings.json"
        watchChanges: true
        printErrors: false
        property bool loaded: false

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: loaded = true
        onLoadFailed: error => {
            loaded = true;
            if (error === FileViewError.FileNotFound) {
                Quickshell.execDetached(["mkdir", "-p", root.stateDir, root.hyprDir]);
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter

            // Тема
            property bool darkMode: true
            property string wallpaper: ""
            property string wallpaperDir: root.home + "/Pictures/Wallpapers"
            // Wallpaper Engine (linux-wallpaperengine)
            property string wallpaperType: "image" // image | engine
            property string engineWallpaper: "" // папка обоев в мастерской
            property string enginePreview: "" // превью — из него берутся цвета
            property int engineFps: 30
            property int engineVolume: 15
            property bool engineSilent: true
            property bool enginePauseFullscreen: true
            property string engineScaling: "fill"
            property bool engineParticles: true
            property bool engineParallax: true
            property bool engineMouse: true
            // Свои значения параметров сцен: { "<папка обоев>": { имя: "значение" } }
            property var engineProps: ({})
            // Свои обои для отдельных мониторов:
            // { "HDMI-A-2": { type, image, engine, preview } }; нет записи — общие
            property var screenWallpapers: ({})
            property string colorSource: "wallpaper" // wallpaper | preset
            property string presetColor: "#4285f4"
            property string schemeType: "scheme-tonal-spot"
            property bool themeApps: true // красить GTK, kitty, рамки окон
            property string iconTheme: ""
            property real animationScale: 1.0

            // Шрифты всей системы (по умолчанию — из appearance во flake.nix)
            property string uiFont: Nix.uiFont
            property string uiFontWeight: Nix.uiFontStyle // Regular | Medium | Bold
            property int uiFontSize: Nix.uiFontSize
            property string monoFont: Nix.monoFont
            property string monoFontWeight: Nix.monoFontStyle
            property int monoFontSize: Nix.monoFontSize

            // Панель задач
            property bool taskbarCentered: true
            property string taskbarPosition: "bottom" // bottom | top | left | right
            property list<string> taskbarScreens: [] // пусто — на всех экранах
            property bool showKeyboardLayout: true
            property int trayVisible: 3 // сколько значков трея видно, остальные — под стрелкой
            property bool showUpdates: true // значок «что обновилось» и прогресс обновления
            property int updatesSeen: 0 // поколение системы, изменения которого уже просмотрены

            // Быстрые настройки (шторка)
            property list<string> qsTiles: ["internet", "bluetooth", "dnd", "night", "dark", "mic", "caffeine", "record", "screenshot", "clipboard"]
            property bool qsShowMedia: true
            property bool qsShowBrightness: true
            property bool showWorkspaces: true
            property bool showTray: true
            property list<string> pinnedApps: ["google-chrome", "nemo", "kitty", "org.telegram.desktop", "steam"]

            // Часы
            property bool use24h: true
            property bool showSeconds: false
            property bool showDate: true

            // Уведомления
            property bool dnd: false
            property bool notifPopups: true
            property int notifTimeout: 6000
            property string notifPosition: "auto" // auto | top-right | top-left | bottom-right | bottom-left | top
            property string notifScreen: "focused" // focused | primary | имя монитора
            property bool notifyScreenshots: true // уведомления о скриншотах и записи экрана

            // Ночной режим (hyprsunset)
            property bool nightLight: false
            property int nightTemp: 4000

            // Простой и блокировка, секунды; 0 — выключено
            property int lockTimeout: 600
            property int screenOffTimeout: 900
            property int suspendTimeout: 0
            property bool lockBeforeSuspend: true

            // Окна (Hyprland)
            property int gapsIn: 4
            property int gapsOut: 8
            property int borderSize: 2
            property int rounding: 16
            property bool blur: true
            property int blurPasses: 2
            property int blurSize: 5
            property bool blurXray: false // размывать только обои — заметно дешевле
            property bool shadows: true
            property bool hyprAnimations: true
            property real windowOpacity: 0.93

            // Раскладка окон и поведение (Hyprland)
            property string layout: "scrolling" // scrolling | dwindle | master
            property real scrollColumnWidth: 0.5
            property bool scrollFullscreenOne: true
            property int scrollFocusFit: 1 // 0 — по центру, 1 — по краю
            property bool scrollFollowFocus: true
            property bool dwindlePreserveSplit: false
            property bool dwindleSmartSplit: false
            property real masterMfact: 0.55
            property string masterNewStatus: "slave"
            property string masterOrientation: "left"
            property bool resizeOnBorder: false
            property bool snapEnabled: false
            property int followMouse: 1
            property bool focusOnActivate: false
            property bool allowTearing: false

            // Свои бинды: [{ mods, key, action, arg }], отключённые стандартные: ["SUPER + J"]
            property var userBinds: []
            property list<string> disabledBinds: []
            // Свои правила окон: [{ cls, title, float, center, pin, fullscreen, noBlur, opaque, workspace, monitor, width, height, opacity }]
            property var userRules: []

            // Запись экрана (gpu-screen-recorder)
            property int recFps: 60
            property string recCodec: "av1" // av1 | hevc | h264
            property string recQuality: "very_high" // medium | high | very_high | ultra
            property string recContainer: "mp4" // mp4 | mkv
            property bool recCursor: true
            property string recDir: root.home + "/Videos"

            // Ввод (Hyprland)
            property string kbLayout: "us,ru"
            property string kbOptions: "grp:alt_shift_toggle"
            property real mouseSensitivity: 0
            property string accelProfile: "flat"
            property bool naturalScroll: false
            property int repeatRate: 30
            property int repeatDelay: 400

            // Мониторы: { "HDMI-A-1": { mode, position, scale, vrr } }
            property var monitors: ({})

            // Лаунчер
            property var appUsage: ({})
            property string searchEngine: "https://www.google.com/search?q="
        }
    }

    function pin(id) {
        if (!adapter.pinnedApps.includes(id))
            adapter.pinnedApps = [...adapter.pinnedApps, id];
    }
    function unpin(id) {
        adapter.pinnedApps = adapter.pinnedApps.filter(a => a !== id);
    }
    function bumpUsage(id) {
        const u = Object.assign({}, adapter.appUsage);
        u[id] = (u[id] ?? 0) + 1;
        adapter.appUsage = u;
    }
}
