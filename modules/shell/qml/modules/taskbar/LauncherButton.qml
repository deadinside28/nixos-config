// Кнопка лаунчера: кольцо, как на Chromebook / Aluminium OS.
import QtQuick
import qs.common
import qs.widgets
import Pixel.MD3E

Rectangle {
    id: root
    property string screenName
    readonly property bool active: Ui.panel === "launcher"

    implicitWidth: 44
    implicitHeight: 44
    radius: active ? Theme.radius.l : height / 2
    color: active ? Theme.primaryContainer : "transparent"

    Behavior on radius {
        NumberAnimation {
            duration: Theme.anim.normal
            easing.type: Easing.OutBack
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fast
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 11
        color: "transparent"
        border.width: 2.5
        border.color: root.active ? Theme.fgPrimaryContainer : Theme.fgSurface
    }

    StateLayer {
        onClicked: Ui.toggle("launcher", root.screenName)
    }
}
