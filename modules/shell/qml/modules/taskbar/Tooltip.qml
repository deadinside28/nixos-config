// Подсказка над элементом панели. Это элемент окна-хоста, а не своё
// всплывающее окно: такое окно Quickshell создаёт заново при каждом
// показе, а с ним и GL-контекст — наведение на панель подтормаживало.
import QtQuick
import qs.common
import qs.widgets
import Pixel.MD3E

Item {
    id: root
    required property Item target
    required property var bar
    property string text
    property bool shown: false
    readonly property bool open: shown && text !== "" && delay.done

    parent: bar
    z: 10
    width: label.implicitWidth + 24
    height: 32
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.9
    transformOrigin: Bar.edge === "bottom" ? Item.Bottom : Bar.edge === "top" ? Item.Top : Bar.edge === "left" ? Item.Left : Item.Right

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.expressiveFastEffectsDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.expressiveFastEffects
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.anim.expressiveFastEffectsDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.expressiveFastEffects
        }
    }

    onShownChanged: if (!shown)
        delay.done = false
    onOpenChanged: if (open)
        place()
    onWidthChanged: if (open)
        place()

    // со стороны рабочего стола, по центру элемента, не за краем экрана
    function place() {
        const p = target.mapToItem(bar, 0, 0);
        const gap = 8;
        if (Bar.vertical) {
            x = Bar.edge === "left" ? bar.width + gap : -width - gap;
            y = Math.max(8, Math.min(bar.height - height - 8, p.y + (target.height - height) / 2));
        } else {
            x = Math.max(8, Math.min(bar.width - width - 8, p.x + (target.width - width) / 2));
            y = Bar.edge === "top" ? bar.height + gap : -height - gap;
        }
    }

    Timer {
        id: delay
        property bool done: false
        interval: 500
        running: root.shown
        onTriggered: done = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.s
        color: Theme.inverseSurface
        MText {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.inverseOnSurface
            size: Theme.type.bodyS
        }
    }
}
