pragma Singleton

// Цвета из обоев. matugen пересчитывает схему при смене обоев, палитры
// или светлой/тёмной темы и раскладывает шаблоны: colors.json оболочки,
// GTK3/GTK4, kitty, рамки окон Hyprland. После — пинаем тех, кто не
// следит за файлами сам.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.services

Singleton {
    id: root

    readonly property bool busy: matugen.running
    readonly property string mode: Settings.data.darkMode ? "dark" : "light"

    readonly property var schemes: [
        {
            value: "scheme-tonal-spot",
            label: "Тональная"
        },
        {
            value: "scheme-vibrant",
            label: "Яркая"
        },
        {
            value: "scheme-expressive",
            label: "Выразительная"
        },
        {
            value: "scheme-fruit-salad",
            label: "Фруктовая"
        },
        {
            value: "scheme-rainbow",
            label: "Радуга"
        },
        {
            value: "scheme-content",
            label: "По содержимому"
        },
        {
            value: "scheme-neutral",
            label: "Нейтральная"
        },
        {
            value: "scheme-monochrome",
            label: "Монохром"
        }
    ]
    readonly property var presets: ["#4285f4", "#1e8e3e", "#f9ab00", "#d93025", "#a142f4", "#e8710a", "#12b5cb", "#e52592", "#5f6368"]

    function regenerate() {
        debounce.restart();
    }

    Connections {
        target: Settings.data
        function onWallpaperChanged() {
            root.regenerate();
        }
        function onWallpaperTypeChanged() {
            root.regenerate();
        }
        function onEnginePreviewChanged() {
            root.regenerate();
        }
        function onColorSourceChanged() {
            root.regenerate();
        }
        function onPresetColorChanged() {
            root.regenerate();
        }
        function onSchemeTypeChanged() {
            root.regenerate();
        }
        function onDarkModeChanged() {
            root.regenerate();
        }
        function onThemeAppsChanged() {
            root.regenerate();
        }
    }

    Connections {
        target: Settings
        function onLoadedChanged() {
            if (Settings.loaded)
                root.regenerate();
        }
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: {
            if (matugen.running) {
                restart();
                return;
            }
            const d = Settings.data;
            const config = d.themeApps ? Nix.matugenConfig : Nix.matugenShellConfig;
            const img = Wallpapers.image;
            const useImage = d.colorSource === "wallpaper" && img !== "";
            const src = useImage ? ["image", img, "--source-color-index", "0"] : ["color", "hex", d.presetColor];
            matugen.command = [Nix.matugen, ...src, "-c", config, "-t", d.schemeType, "-m", root.mode, "-q", "--fallback-color", d.presetColor];
            matugen.running = true;
        }
    }

    Process {
        id: matugen
        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("matugen:", text.trim())
        }
        onExited: code => {
            if (code !== 0) {
                console.warn("matugen завершился с кодом", code);
                return;
            }
            if (!Settings.data.themeApps)
                return;
            const dark = Settings.data.darkMode;
            Quickshell.execDetached(["sh", "-c", `
                gsettings set org.gnome.desktop.interface color-scheme '${dark ? "prefer-dark" : "prefer-light"}'
                gsettings set org.gnome.desktop.interface gtk-theme '${dark ? "adw-gtk3-dark" : "adw-gtk3"}'
                pkill -USR1 -x kitty || true
                f="${Settings.hyprDir}/colors.lua"
                [ -f "$f" ] && hyprctl eval "$(cat "$f")" >/dev/null || true
            `]);
        }
    }

    // Иконки: GTK (settings.ini + gsettings) и сама оболочка через Qt.
    function setIconTheme(name) {
        Settings.data.iconTheme = name;
        Quickshell.execDetached(["sh", "-c", `
            gsettings set org.gnome.desktop.interface icon-theme '${name}'
            for f in "${Settings.configDir}/gtk-3.0/settings.ini" "${Settings.configDir}/gtk-4.0/settings.ini"; do
                [ -w "$f" ] || continue
                if grep -q '^gtk-icon-theme-name=' "$f"; then
                    sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=${name}|" "$f"
                else
                    sed -i "/^\\[Settings\\]/a gtk-icon-theme-name=${name}" "$f"
                fi
            done
            # Значки самой оболочки (Qt) берутся при запуске — перезапускаем её.
            printf 'QS_ICON_THEME=%s\\n' '${name}' > "${Settings.stateDir}/env"
            sleep 0.5
            systemctl --user restart pixel-shell
        `]);
    }
}
