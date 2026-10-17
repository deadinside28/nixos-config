// Подсказка над элементом панели.
import QtQuick
import Quickshell
import qs.common
import qs.widgets

PopupWindow {
    id: root
    required property Item target
    required property var bar
    property string text
    property bool shown: false

    anchor.window: bar
    anchor.item: target
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -8
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
