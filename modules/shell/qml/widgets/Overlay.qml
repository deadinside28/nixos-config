// Выезжающая панель (лаунчер, быстрые настройки, меню питания…) поверх
// экрана. Клик мимо содержимого и Esc закрывают.
//
// Панель — не своё окно, а элемент внутри окна-хоста экрана
// (modules/frame/ScreenHost.qml, common/Hosts.qml), как в Caelestia:
// хост уже показан, поэтому открытие начинается с первого кадра — без
// создания поверхности, буферов и GL-контекста.
//
// progress (0…1) анимируется сам: содержимое привязывает к нему
// масштаб/сдвиг/прозрачность, а панель видна, пока идёт анимация закрытия.
import QtQuick
import Quickshell
import qs.common
import Pixel.MD3E

Item {
    id: root

    property bool open: false
    property bool dim: false
    property bool grabKeyboard: true
    // монопольный фокус клавиатуры — только для запроса пароля
    property bool exclusiveFocus: false
    property string name: "panel"
    property int duration: Theme.anim.expressiveDefaultSpatialDuration
    property real progress: open ? 1 : 0
    default property alias content: container.data
    signal dismissed

    readonly property var screen: Quickshell.screens.find(s => s.name === Ui.activeScreen) ?? Quickshell.screens[0]
    readonly property string screenName: screen?.name ?? ""
    // видна, пока открыта или ещё закрывается
    readonly property bool shown: open || progress > 0.001

    parent: shown ? Hosts.items[screenName] ?? null : null
    width: parent?.width ?? 0
    height: parent?.height ?? 0
    visible: shown
    z: exclusiveFocus ? 10 : 0

    Component.onCompleted: Hosts.addOverlay(root)
    Component.onDestruction: Hosts.removeOverlay(root)
    // фокус клавиатуры — содержимому, когда панель уже в окне хоста
    onOpenChanged: if (open && grabKeyboard)
        Qt.callLater(() => container.forceActiveFocus())

    // Место, которое занимает панель задач на этом экране, по сторонам
    readonly property int insetTop: Bar.inset(screenName, "top")
    readonly property int insetBottom: Bar.inset(screenName, "bottom")
    readonly property int insetLeft: Bar.inset(screenName, "left")
    readonly property int insetRight: Bar.inset(screenName, "right")
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

    // Открытие — выразительная кривая M3 с лёгким перелётом (как у
    // выдвижных панелей Caelestia), закрытие — короче и с ускорением
    Behavior on progress {
        NumberAnimation {
            duration: root.open ? root.duration : Theme.anim.emphasizedAccelDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Theme.anim.expressiveDefaultSpatial : Theme.anim.emphasizedAccel
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        // затемнение — без перелёта
        opacity: root.dim ? 0.32 * Math.min(1, root.progress) : 0
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
