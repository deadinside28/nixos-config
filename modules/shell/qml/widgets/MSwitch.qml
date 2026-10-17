// Переключатель M3: трек 52×32, бегунок растёт при включении и несёт галочку.
import QtQuick
import qs.common

Item {
    id: root

    property bool checked: false
    property bool disabled: false
    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 32
    opacity: disabled ? 0.38 : 1

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim.fast
            }
        }

        Rectangle {
            id: thumb
            property real size: mouse.pressed ? 28 : root.checked ? 24 : 16
            width: size
            height: size
            radius: size / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - 4 : (mouse.pressed ? 2 : 8)
            color: root.checked ? Theme.fgPrimary : Theme.outline

            Behavior on x {
                NumberAnimation {
                    duration: Theme.anim.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.anim.expressiveSpatial
                }
            }
            Behavior on size {
                NumberAnimation {
                    duration: Theme.anim.fast
                }
            }

            MIcon {
                anchors.centerIn: parent
                icon: "check"
                size: 16
                weight: 600
                color: Theme.fgPrimaryContainer
                opacity: root.checked ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim.fast
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6
        enabled: !root.disabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
