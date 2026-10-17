pragma Singleton

// Обои: список картинок из папки обоев (рекурсивно, до 2 уровней).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property var files: []
    readonly property string dir: Settings.data.wallpaperDir

    function refresh() {
        find.running = false;
        find.running = true;
    }
    onDirChanged: refresh()

    Process {
        id: find
        command: ["find", "-L", root.dir, "-maxdepth", "2", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(f => f).sort()
        }
    }

    // Для какого монитора выбираем обои в настройках; "" — для всех
    property string target: ""

    // Обои экрана: свои, если заданы, иначе общие.
    function forScreen(name) {
        const d = Settings.data;
        const own = (d.screenWallpapers ?? {})[name];
        if (own)
            return own;
        return {
            type: d.wallpaperType,
            image: d.wallpaper,
            engine: d.engineWallpaper,
            preview: d.enginePreview
        };
    }
    // Картинка экрана: для Wallpaper Engine — его превью.
    function imageFor(name) {
        const w = forScreen(name);
        return w.type === "engine" && w.preview ? w.preview : (w.image ?? "");
    }

    // По основному (первому) монитору считаются цвета и рисуется экран блокировки.
    readonly property string primaryScreen: Quickshell.screens[0]?.name ?? ""
    readonly property string image: {
        const _ = Settings.data.screenWallpapers;
        const __ = Settings.data.wallpaper + Settings.data.wallpaperType + Settings.data.enginePreview;
        return imageFor(primaryScreen);
    }

    // Поставить обои: на выбранный монитор или на все (тогда свои
    // обои отдельных мониторов сбрасываются).
    function apply(entry) {
        if (target === "") {
            Settings.data.screenWallpapers = {};
            if (entry.type === "engine") {
                Settings.data.enginePreview = entry.preview ?? "";
                Settings.data.engineWallpaper = entry.engine;
            } else {
                Settings.data.wallpaper = entry.image;
            }
            Settings.data.wallpaperType = entry.type;
        } else {
            const m = Object.assign({}, Settings.data.screenWallpapers);
            m[target] = entry;
            Settings.data.screenWallpapers = m;
        }
    }
    function set(path) {
        apply({
            type: "image",
            image: path
        });
    }
    // Обои выбранного в настройках монитора (или основного)
    readonly property var current: {
        const _ = Settings.data.screenWallpapers;
        const __ = Settings.data.wallpaper + Settings.data.wallpaperType + Settings.data.engineWallpaper;
        return forScreen(target || primaryScreen);
    }
    function resetScreen(name) {
        const m = Object.assign({}, Settings.data.screenWallpapers);
        delete m[name];
        Settings.data.screenWallpapers = m;
    }
    function random() {
        if (files.length)
            set(files[Math.floor(Math.random() * files.length)]);
    }
    Component.onCompleted: refresh()
}
