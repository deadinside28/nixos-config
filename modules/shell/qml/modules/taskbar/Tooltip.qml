// Подсказка над элементом панели.
import QtQuick
import Quickshell
import qs.common
import qs.widgets
import Pixel.MD3E

PopupWindow {
    id: root
    required property Item target
    required property var bar
    property string text
    property bool shown: false

    anchor.window: bar
    anchor.item: target
    anchor.edges: Bar.popupEdge
    anchor.gravity: Bar.popupEdge
    anchor.margins.top: Bar.edge === "bottom" ? -8 : 0
    anchor.margins.bottom: Bar.edge === "top" ? -8 : 0
    anchor.margins.left: Bar.edge === "right" ? -8 : 0
    anchor.margins.right: Bar.edge === "left" ? -8 : 0
    implicitWidth: label.implicitWidth + 24
    implicitHeight: 32
    color: "transparent"
    visible: shown && text !== "" && delay.done

    onShownChanged: if (!shown)
        delay.done = false

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
