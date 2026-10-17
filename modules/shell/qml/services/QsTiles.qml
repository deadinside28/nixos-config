pragma Singleton

// Каталог плиток быстрых настроек. Какие из них показывать и в каком
// порядке — Settings.data.qsTiles («Настройки → Быстрые настройки»).
import QtQuick
import Quickshell
import qs.common

Singleton {
    id: root

    readonly property var all: [
        {
            id: "internet",
            label: "Интернет",
            icon: () => Net.icon,
            sub: () => Net.label,
            active: () => Net.online || Net.wifiEnabled,
            toggle: () => Net.hasWifi && Net.setWifi(!Net.wifiEnabled),
            details: () => Ui.openSettings("network")
        },
        {
            id: "bluetooth",
            label: "Bluetooth",
            icon: () => Bt.icon,
            sub: () => Bt.label,
            active: () => Bt.enabled,
            toggle: () => Bt.setEnabled(!Bt.enabled),
            details: () => Ui.openSettings("bluetooth")
        },
        {
            id: "dnd",
            label: "Не беспокоить",
            icon: () => Settings.data.dnd ? "do_not_disturb_on" : "do_not_disturb_off",
            sub: () => Settings.data.dnd ? "Включено" : "Выключено",
            active: () => Settings.data.dnd,
            toggle: () => Settings.data.dnd = !Settings.data.dnd
        },
        {
            id: "night",
            label: "Ночной режим",
            icon: () => "nightlight",
            sub: () => Settings.data.nightLight ? Settings.data.nightTemp + " K" : "Выключен",
            active: () => Settings.data.nightLight,
            toggle: () => NightLight.toggle()
        },
        {
            id: "dark",
            label: "Тёмная тема",
            icon: () => "contrast",
            sub: () => Settings.data.darkMode ? "Включена" : "Выключена",
            active: () => Settings.data.darkMode,
            toggle: () => Settings.data.darkMode = !Settings.data.darkMode
        },
        {
            id: "mic",
            label: "Микрофон",
            icon: () => Audio.micMuted ? "mic_off" : "mic",
            sub: () => Audio.micMuted ? "Выключен" : Math.round(Audio.micVolume * 100) + "%",
            active: () => !Audio.micMuted && Audio.source !== null,
            toggle: () => Audio.toggleMicMute()
        },
        {
            id: "caffeine",
            label: "Без сна",
            icon: () => "coffee",
            sub: () => Ui.caffeine ? "Экран не гаснет" : "Выключено",
            active: () => Ui.caffeine,
            toggle: () => Ui.caffeine = !Ui.caffeine
        },
        {
            id: "record",
            label: "Запись экрана",
            icon: () => Ui.recording ? "stop_circle" : "screen_record",
            sub: () => Ui.recording ? "Нажми, чтобы остановить" : ({
                        screen: "Весь экран",
                        area: "Область",
                        window: "Окно"
                    })[Settings.data.recArea],
            active: () => Ui.recording,
            // идёт запись — остановить, иначе — выбрать, что записывать
            toggle: () => {
                if (Ui.recording) {
                    Quickshell.execDetached(["pixel-record"]);
                    Ui.close();
                } else
                    Ui.open("record");
            }
        },
        {
            id: "screenshot",
            label: "Скриншот",
            icon: () => "screenshot_region",
            sub: () => "Область",
            active: () => false,
            toggle: () => {
                Ui.close();
                Quickshell.execDetached(["sh", "-c", "sleep 0.4; pixel-screenshot area"]);
            }
        },
        {
            id: "lens",
            label: "Обвести и найти",
            icon: () => "frame_inspect",
            sub: () => "Поиск по экрану",
            active: () => false,
            toggle: () => {
                Ui.close();
                Quickshell.execDetached(["sh", "-c", "sleep 0.4; pixel-shell lens search"]);
            }
        },
        {
            id: "translate",
            label: "Перевод экрана",
            icon: () => "translate",
            sub: () => Lens.active && Lens.mode === "live" ? "В реальном времени" : "Перевести всё",
            active: () => Lens.active && Lens.mode === "live",
            toggle: () => {
                Ui.close();
                if (Lens.active)
                    Lens.stop();
                else
                    Quickshell.execDetached(["sh", "-c", "sleep 0.4; pixel-shell lens translate"]);
            }
        },
        {
            id: "clipboard",
            label: "Буфер обмена",
            icon: () => "content_paste",
            sub: () => "История",
            active: () => false,
            toggle: () => Ui.open("clipboard")
        },
        {
            id: "layout",
            label: "Раскладка",
            icon: () => "keyboard",
            sub: () => Keyboard.layoutName || "—",
            active: () => false,
            toggle: () => Keyboard.next()
        },
        {
            id: "wallpaper",
            label: "Живые обои",
            icon: () => "animated_images",
            sub: () => WallpaperEngine.active ? "Включены" : "Выключены",
            active: () => WallpaperEngine.active,
            toggle: () => {
                Wallpapers.target = "";
                Wallpapers.apply(WallpaperEngine.active ? {
                    type: "image",
                    image: Settings.data.wallpaper
                } : {
                    type: "engine",
                    engine: Settings.data.engineWallpaper,
                    preview: Settings.data.enginePreview
                });
            }
        },
        {
            id: "overview",
            label: "Обзор",
            icon: () => "overview",
            sub: () => "Все окна",
            active: () => false,
            toggle: () => Ui.open("overview")
        },
        {
            id: "settings",
            label: "Настройки",
            icon: () => "settings",
            sub: () => "Все параметры",
            active: () => false,
            toggle: () => Ui.openSettings("")
        }
    ]

    function byId(id) {
        return all.find(t => t.id === id) ?? null;
    }
}
