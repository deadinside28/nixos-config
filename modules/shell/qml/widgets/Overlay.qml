// Слой поверх всего экрана для выезжающих панелей (лаунчер, быстрые
// настройки, меню питания…). Клик мимо содержимого и Esc закрывают.
// progress (0…1) анимируется сам: содержимое привязывает к нему
// масштаб/сдвиг/прозрачность, а окно живёт, пока анимация закрытия идёт.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common

PanelWindow {
    id: root

    property bool open: false
    property bool dim: false
    property bool grabKeyboard: true
    property string name: "panel"
    property int duration: Theme.anim.normal
    property real progress: open ? 1 : 0
    default property alias content: container.data
    signal dismissed

    // Место, которое занимает панель задач на этом экране, по сторонам
    readonly property int insetTop: Bar.inset(screen?.name ?? "", "top")
    readonly property int insetBottom: Bar.inset(screen?.name ?? "", "bottom")
    readonly property int insetLeft: Bar.inset(screen?.name ?? "", "left")
    readonly property int insetRight: Bar.inset(screen?.name ?? "", "right")
    // Сдвиг для анимации появления: со стороны панели
    function slideX(amount) {
        return Bar.edge === "left" ? -amount : Bar.edge === "right" ? amount : 0;
    }
    // Сбоку панели всё выезжает снизу, как в Aluminium OS
    function slideY(amount) {
        return Bar.edge === "top" ? -amount : amount;
    }
    function slideXv(amount) {
        return 0;
    }

    screen: Quickshell.screens.find(s => s.name === Ui.activeScreen) ?? Quickshell.screens[0]
    visible: open || progress > 0.001
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pixel-shell:" + name
    WlrLayershell.keyboardFocus: open && grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Behavior on progress {
        NumberAnimation {
            duration: root.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.anim.emphasizedDecel : Theme.anim.emphasizedAccel
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.dim ? 0.32 * root.progress : 0
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        acceptedButtons: Qt.AllButtons
        onClicked: root.dismissed()
    }

    Item {
        id: container
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.dismissed()
    }
}
