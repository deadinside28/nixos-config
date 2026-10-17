// Слайдер из быстрых настроек Pixel: широкая скруглённая «таблетка»,
// заполненная часть — основной цвет, значок внутри слева.
import QtQuick
import qs.common

Rectangle {
    id: root

    property real value: 0 // 0…1
    property string icon: "volume_up"
    property bool muted: false
    signal moved(real value)
    signal iconClicked

    implicitHeight: 52
    radius: height / 2
    color: Theme.surfaceContainerHighest
    clip: true

    Rectangle {
        id: fill
        height: parent.height
        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
        radius: height / 2
        color: root.muted ? Theme.outline : Theme.primary
        Behavior on width {
            enabled: !mouse.pressed
            NumberAnimation {
                duration: Theme.anim.fast
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.anim.fast
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        function update(x) {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: event => {
            if (event.x < root.height)
                return;
            update(event.x);
        }
        onPositionChanged: event => {
            if (pressed && event.x >= 0)
                update(event.x);
        }
        onClicked: event => {
            if (event.x < root.height)
                root.iconClicked();
        }
        onWheel: event => root.moved(Math.max(0, Math.min(1, root.value + (event.angleDelta.y > 0 ? 0.05 : -0.05))))
    }

    MIcon {
        x: (root.height - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        size: 24
        fill: 1
        color: root.muted ? Theme.surface : Theme.onPrimary
    }
}
