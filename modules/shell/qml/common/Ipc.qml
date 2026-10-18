// IPC для биндов Hyprland:  pixel-shell <цель> <функция>
// (обёртка над `qs -c pixel ipc call`). Список: pixel-shell show
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

Scope {
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            Ui.toggle("launcher");
        }
    }
    IpcHandler {
        target: "quicksettings"
        function toggle(): void {
            Ui.toggle("quicksettings");
        }
    }
    IpcHandler {
        target: "notifications"
        function toggle(): void {
            Ui.toggle("quicksettings");
        }
        function clear(): void {
            Notifs.clearAll();
        }
        function dnd(): void {
            Settings.data.dnd = !Settings.data.dnd;
        }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            Ui.toggle("clipboard");
        }
    }
    IpcHandler {
        target: "overview"
        function toggle(): void {
            Ui.toggle("overview");
        }
    }
    IpcHandler {
        target: "power"
        function toggle(): void {
            Ui.toggle("power");
        }
    }
    IpcHandler {
        target: "notes"
        function open(): void {
            Ui.notesOpen = true;
        }
    }
    IpcHandler {
        target: "calendar"
        function open(): void {
            Ui.calendarOpen = true;
        }
        // .ics из «Файлов» или браузера — в календарь
        function importFile(path: string): void {
            Ui.calendarOpen = true;
            Calendar.importIcs(String(path).replace(/^file:\/\//, ""));
        }
    }
    IpcHandler {
        target: "store"
        function open(): void {
            Ui.storeOpen = true;
        }
        function search(query: string): void {
            Ui.storeOpen = true;
            Store.search(query);
        }
    }
    IpcHandler {
        target: "windows"
        // Режим текущего стола по кругу (Super+Shift+Пробел)
        function cycle(): void {
            WindowModes.cycleActive();
        }
        // Общий режим: scrolling | dwindle | master | mixed | floating
        function mode(preset: string): void {
            if (WindowModes.presets.some(p => p.value === preset))
                WindowModes.setGlobal(preset);
        }
    }
    IpcHandler {
        target: "lock"
        function lock(): void {
            Power.lock();
        }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void {
            Ui.settingsOpen = !Ui.settingsOpen;
        }
        function open(page: string): void {
            Ui.openSettings(page);
        }
    }
    IpcHandler {
        target: "record"
        // панель «что записывать»; если запись идёт — остановить
        function toggle(): void {
            if (Ui.recording)
                Quickshell.execDetached(["pixel-record"]);
            else
                Ui.toggle("record");
        }
    }
    IpcHandler {
        target: "lens"
        // обвести и найти / перевести экран / перевод в реальном времени
        function search(): void {
            Lens.start("search");
        }
        function translate(): void {
            Lens.start("translate");
        }
        function live(): void {
            Lens.start("live");
        }
    }
    IpcHandler {
        target: "files"
        // pixel-shell files open [путь или file://-адрес]
        function open(path: string): void {
            Files.open(path);
        }
    }
    IpcHandler {
        target: "archive"
        // pixel-shell archive open <архив> — окно архиватора
        function open(path: string): void {
            Files.openArchiveWindow(path);
        }
    }
    IpcHandler {
        target: "update"
        // окно с прогрессом и логом последнего обновления
        function open(): void {
            Ui.updateWindowOpen = true;
        }
        function run(): void {
            SystemConfig.updateAndRebuild();
        }
    }
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void {
            Wallpapers.set(path);
        }
        function random(): void {
            Wallpapers.random();
        }
    }
    IpcHandler {
        target: "theme"
        function toggle(): void {
            Settings.data.darkMode = !Settings.data.darkMode;
        }
    }
    IpcHandler {
        target: "audio"
        function up(): void {
            Audio.setVolume(Audio.volume + 0.02);
        }
        function down(): void {
            Audio.setVolume(Audio.volume - 0.02);
        }
        function mute(): void {
            Audio.toggleMute();
        }
        function micMute(): void {
            Audio.toggleMicMute();
        }
    }
    IpcHandler {
        target: "brightness"
        function up(): void {
            Brightness.step(0.05);
        }
        function down(): void {
            Brightness.step(-0.05);
        }
    }
    IpcHandler {
        target: "media"
        function toggle(): void {
            Media.active?.togglePlaying();
        }
        function next(): void {
            Media.active?.next();
        }
        function previous(): void {
            Media.active?.previous();
        }
    }
}
