// Пока открыта панель (шторка, лаунчер…), на остальных мониторах лежит
// прозрачный слой: клик по нему закрывает панель. Сам клик дальше не идёт,
// как и на экране с панелью, где закрывает подложка оверлея.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

PanelWindow {
    id: root
    required property ShellScreen modelData
    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pixel-shell:catcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: Ui.close()
        onWheel: Ui.close()
    }
}
