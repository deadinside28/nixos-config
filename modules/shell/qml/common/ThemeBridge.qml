// Мост оболочки к теме библиотеки Pixel.MD3E (modules/shell/md3e):
// настройки оболочки и Nix → входы Theme, colors.json от matugen
// (services/Theming.qml) → Theme.scheme. Один экземпляр — в shell.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import Pixel.MD3E

Scope {
    Binding {
        target: Theme
        property: "dark"
        value: Settings.data.darkMode
    }
    Binding {
        target: Theme
        property: "font"
        value: Settings.data.uiFont || Nix.uiFont
    }
    Binding {
        target: Theme
        property: "monoFont"
        value: Settings.data.monoFont || Nix.monoFont
    }
    Binding {
        target: Theme
        property: "fontWeightName"
        value: Settings.data.uiFontWeight
    }
    Binding {
        target: Theme
        property: "fontSize"
        value: Settings.data.uiFontSize || 12
    }
    Binding {
        target: Theme
        property: "animationScale"
        value: Settings.data.animationScale
    }
    // Полупрозрачные панели — под ними размытие Hyprland (матовое стекло)
    Binding {
        target: Theme
        property: "panelOpacity"
        value: Settings.data.blur ? Settings.data.panelOpacity : 1
    }
    // Рамка экрана лежит поверх краёв окон, поэтому она непрозрачная; панель
    // задач на экране с рамкой красится так же — получается одна деталь.
    Binding {
        target: Theme
        property: "frame"
        value: Settings.data.frameColor === "black" ? "#000000" : Theme.surfaceContainer
    }

    FileView {
        path: Settings.stateDir + "/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                Theme.scheme = JSON.parse(text());
            } catch (e) {
                console.warn("theme: colors.json не читается:", e);
            }
        }
        onLoadFailed: Theme.scheme = {}
    }
}
