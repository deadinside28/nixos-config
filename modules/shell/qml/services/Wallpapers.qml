pragma Singleton

// Обои: список картинок из папки обоев (рекурсивно, до 2 уровней).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property var files: []
    // Картинка, которая сейчас «на обоях»: для Wallpaper Engine — его
    // превью (по нему считаются цвета, его видно на экране блокировки).
    readonly property string image: Settings.data.wallpaperType === "engine" && Settings.data.enginePreview ? Settings.data.enginePreview : Settings.data.wallpaper
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

    function set(path) {
        Settings.data.wallpaper = path;
        Settings.data.wallpaperType = "image";
    }
    function random() {
        if (files.length)
            set(files[Math.floor(Math.random() * files.length)]);
    }
    Component.onCompleted: refresh()
}
