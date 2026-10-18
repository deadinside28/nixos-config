pragma Singleton

// Настройки оболочки. Живут в ~/.local/state/pixel-shell/settings.json —
// обычный файл, который оболочка пишет сама при каждом изменении в
// «Настройках». Конфиг Nix сюда не лезет: что выбрал мышкой, то и
// остаётся после пересборки.
//
// Запись атомарная (FileView.atomicWrites). Рядом лежит settings.json.bak —
// последняя читаемая копия. Если settings.json не разбирается (правили
// руками, сбой диска), оболочка не затирает его значениями по умолчанию:
// повреждённый файл откладывается в settings.json.broken-<время>, а
// настройки восстанавливаются из копии.

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

    // Версия формата settings.json. Растёт, когда ключ переименовывается
    // или меняет смысл; перевод старых значений — в migrate().
    readonly property int schemaVersion: 2
    // from — версия из файла; файлы старше схемы версии не хранят (1)
    function migrate(from) {
        if (from >= schemaVersion)
            return;
        // 2: плитка Quick Share в быстрых настройках (видна, когда служба
        // включена в «Системе»)
        if (from < 2 && !adapter.qsTiles.includes("quickshare"))
            adapter.qsTiles = [...adapter.qsTiles, "quickshare"];
        adapter.schemaVersion = schemaVersion;
    }

    // settings.json не разобрался — пока он не восстановлен, не пишем
    property bool broken: false
    readonly property string path: stateDir + "/settings.json"
    readonly property string backupPath: path + ".bak"

    FileView {
        id: file
        path: root.path
        watchChanges: true
        printErrors: false
        property bool loaded: false

        onFileChanged: reload()
        onAdapterUpdated: if (!root.broken)
            writeAdapter()
        onLoaded: {
            let ok = false, j = null;
            try {
                j = JSON.parse(text());
                ok = j !== null && typeof j === "object" && !Array.isArray(j);
            } catch (e) {}
            if (!ok) {
                root.restore();
                return;
            }
            root.broken = false;
            loaded = true;
            root.migrate(j.schemaVersion ?? 1);
            if (text() !== backup.text())
                backup.setText(text());
        }
        onLoadFailed: error => {
            loaded = true;
            if (error === FileViewError.FileNotFound) {
                root.broken = false;
                Quickshell.execDetached(["mkdir", "-p", root.stateDir, root.hyprDir]);
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter

            property int schemaVersion: 2

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
            // Значки приложений в оболочке: original | shaped | themed (как на Pixel)
            property string iconStyle: "themed"
            property string iconShape: "circle"
            property string iconColor: "primary" // primary | secondary | tertiary | neutral
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

            // Рамка экрана со скруглёнными углами
            property bool screenFrame: false
            property int frameWidth: 8 // 0 — только скруглённые углы
            property int frameRadius: 24
            property string frameColor: "panel" // panel — как панель задач | black
            property list<string> frameScreens: [] // пусто — на всех экранах

            // Быстрые настройки (шторка)
            property list<string> qsTiles: ["internet", "bluetooth", "quickshare", "dnd", "night", "dark", "mic", "caffeine", "record", "screenshot", "lens", "translate", "clipboard"]
            property bool qsShowMedia: true
            property bool qsShowBrightness: true
            property bool showWorkspaces: true
            property bool showTray: true
            property list<string> pinnedApps: ["google-chrome", "pixel-shell-files", "kitty", "org.telegram.desktop", "steam"]

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
            property real panelOpacity: 0.82 // непрозрачность панелей оболочки (стекло)
            property bool shadows: true
            property bool hyprAnimations: true
            property real windowOpacity: 0.93

            // Раскладка окон и поведение (Hyprland)
            property string layout: "scrolling" // scrolling | dwindle | master
            // Режим окон (services/WindowModes.qml): tiled — по раскладке выше,
            // mixed — тайлинг, но floatApps плавают, floating — все плавают
            property string windowMode: "tiled"
            property list<string> floatApps: [] // классы окон для «Смешанного»
            property var workspaceModes: ({}) // свой режим стола: { "3": "dwindle" }
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
            property string recArea: "screen" // screen | area | window
            property string recAudio: "system" // system | mic | none

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

            // Обвести и найти / перевод экрана
            property string ocrLangs: "eng+rus" // языки распознавания (tesseract)
            property string translateTo: "ru"

            // Файлы
            property string filesView: "grid" // grid | list
            property bool filesHidden: false
            property string filesSort: "name" // name | time | size | type
            property bool filesSortDesc: false
            property var netPlaces: [] // сохранённые сетевые папки: [{ uri, user }]

            property string chooserLastDir: "" // последняя папка диалога выбора файлов

            // Заметки (services/Notes.qml): папка — пусто = ~/Documents/Заметки
            property string notesDir: ""
            property list<string> notesPinned: [] // пути относительно папки заметок

            // Лаунчер и меню приложений (services/Apps.qml)
            property var appUsage: ({})
            property var appOverrides: ({}) // правки поверх .desktop: { id: { name, icon, folder, … } }
            property var customApps: [] // свои команды: [{ id, name, icon, command, … }]
            property string launcherSort: "name" // name | usage
            property int launcherColumns: 6
            property int launcherIconSize: 48
            property bool launcherLabels: true
            property string searchEngine: "https://www.google.com/search?q="
        }
    }

    FileView {
        id: backup
        path: root.backupPath
        printErrors: false
        blockLoading: true
    }
    function restore() {
        if (broken)
            return;
        broken = true;
        console.warn("settings.json не разбирается — восстанавливаю из", backupPath);
        // Копии нет — убираем файл, и оболочка создаст его заново (onLoadFailed)
        Quickshell.execDetached(["sh", "-c", `
            f="$1"; bak="$2"; keep="$f.broken-$(date +%Y%m%d-%H%M%S)"
            cp -f -- "$f" "$keep"
            if [ -s "$bak" ]; then cp -f -- "$bak" "$f.tmp" && mv -f -- "$f.tmp" "$f"; what="восстановлены из резервной копии"
            else rm -f -- "$f"; what="сброшены: резервной копии нет"; fi
            notify-send -a "Pixel Shell" -u critical -i dialog-warning "Настройки оболочки повреждены" "Настройки $what. Повреждённый файл: $keep"
        `, "sh", path, backupPath]);
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
