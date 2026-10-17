// Слайдер M3 Expressive (Android 16): толстый трек, вертикальная ручка
// с зазором по бокам, точка-ограничитель в конце неактивной части.
import QtQuick
import qs.common

Item {
    id: root

    property real from: 0
    property real to: 1
    property real value: 0
    property real stepSize: 0
    property bool disabled: false
    property string icon: ""
    readonly property bool pressed: mouse.pressed
    signal moved(real value)

    readonly property real ratio: to === from ? 0 : Math.max(0, Math.min(1, (value - from) / (to - from)))
    readonly property real trackHeight: 16
    readonly property real handleGap: 6

    implicitWidth: 200
    implicitHeight: 44
    opacity: disabled ? 0.38 : 1

    readonly property real handleX: ratio * (width - handle.width)

    // активная часть
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: Math.max(0, root.handleX - root.handleGap)
        height: root.trackHeight
        radius: height / 2
        topRightRadius: 2
        bottomRightRadius: 2
        color: Theme.primary
        visible: width > 0

        MIcon {
            visible: root.icon !== "" && parent.width > 40
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            icon: root.icon
            size: 14
            color: Theme.fgPrimary
        }
    }
    // неактивная часть
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX + handle.width + root.handleGap
        width: Math.max(0, root.width - x)
        height: root.trackHeight
        radius: height / 2
        topLeftRadius: 2
        bottomLeftRadius: 2
        color: Theme.secondaryContainer
        visible: width > 0

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 4
            radius: 2
            color: Theme.primary
        }
    }

    Rectangle {
        id: handle
        x: root.handleX
        anchors.verticalCenter: parent.verticalCenter
        width: mouse.pressed ? 2 : 4
        height: 44
        radius: 2
        color: Theme.primary
        Behavior on width {
            NumberAnimation {
                duration: Theme.anim.fast
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function update(x) {
            let r = Math.max(0, Math.min(1, x / width));
            let v = root.from + r * (root.to - root.from);
            if (root.stepSize > 0)
                v = Math.round(v / root.stepSize) * root.stepSize;
            root.moved(v);
        }
        onPressed: event => update(event.x)
        onPositionChanged: event => {
            if (pressed)
                update(event.x);
        }
        onWheel: event => {
            const step = root.stepSize > 0 ? root.stepSize : (root.to - root.from) / 50;
            root.moved(Math.max(root.from, Math.min(root.to, root.value + (event.angleDelta.y > 0 ? step : -step))));
        }
    }
}
