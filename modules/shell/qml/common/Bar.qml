pragma Singleton

// Где стоит панель задач: край экрана и на каких экранах она есть.
// По этому выезжают лаунчер, быстрые настройки и подсказки.
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string edge: Settings.data.taskbarPosition
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property int size: 56

    function shownOn(screenName) {
        const l = Settings.data.taskbarScreens;
        return l.length === 0 || l.includes(screenName);
    }
    // Сколько места панель занимает у стороны side на этом экране.
    // Рамка экрана (если включена) занимает остальные стороны.
    function inset(screenName, side) {
        if (edge === side && shownOn(screenName))
            return size;
        return frameOn(screenName) ? Settings.data.frameWidth : 0;
    }
    function frameOn(screenName) {
        const l = Settings.data.frameScreens;
        return Settings.data.screenFrame && (l.length === 0 || l.includes(screenName));
    }
    // С какой стороны от элемента панели открывать подсказки и меню.
    readonly property int popupEdge: edge === "top" ? Edges.Bottom : edge === "left" ? Edges.Right : edge === "right" ? Edges.Left : Edges.Top
}
