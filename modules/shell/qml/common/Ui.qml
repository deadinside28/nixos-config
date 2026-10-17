pragma Singleton

// Что сейчас открыто. Одна точка правды для панелей, чтобы открытие одной
// закрывало другие и чтобы IPC и кнопки на панели задач дёргали одно и то же.

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // "" | launcher | quicksettings | power | clipboard | overview
    property string panel: ""
    // Экран, на котором открыта панель (имя выхода). Пусто — экран с фокусом.
    property string panelScreen: ""

    property bool locked: false
    property bool caffeine: false
    property bool recording: false

    // Окно «Настройки» и открытый в нём раздел
    property bool settingsOpen: false
    property string settingsPage: "network"
    property bool updateWindowOpen: false // окно с прогрессом обновления и логом

    function openSettings(page) {
        if (page)
            settingsPage = page;
        settingsOpen = true;
        close();
    }

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "")
    readonly property string activeScreen: panelScreen || focusedScreen

    function toggle(name, screen) {
        if (panel === name) {
            close();
            return;
        }
        panelScreen = screen ?? "";
        panel = name;
    }
    function open(name, screen) {
        panelScreen = screen ?? "";
        panel = name;
    }
    function close() {
        panel = "";
    }
}
