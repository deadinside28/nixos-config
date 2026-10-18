// Слой состояния M3: подсветка при наведении/нажатии и рябь от точки клика.
// Кладётся внутрь любого прямоугольника; радиус берётся у родителя.
import QtQuick

MouseArea {
    id: root

    property color color: Theme.fgSurface
    property real radius: parent?.radius ?? 0
    property bool disabled: false
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    anchors.fill: parent
    hoverEnabled: true
    enabled: !disabled
    cursorShape: disabled ? Qt.ArrowCursor : Qt.PointingHandCursor

    onPressed: event => {
        ripple.x = event.x - ripple.width / 2;
        ripple.y = event.y - ripple.height / 2;
        rippleAnim.restart();
    }

    Rectangle {
        id: clip
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Theme.alpha(root.color, root.pressed ? Theme.pressOpacity : root.containsMouse ? Theme.hoverOpacity : 0)
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim.fast
            }
        }

        Rectangle {
            id: ripple
            width: Math.max(root.width, root.height) * 2.2
            height: width
            radius: width / 2
            color: root.color
            opacity: 0
            scale: 0
        }
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation {
            target: ripple
            property: "scale"
            from: 0
            to: 1
            duration: Theme.anim.slow
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation {
                target: ripple
                property: "opacity"
                to: 0.10
                duration: 60
            }
            NumberAnimation {
                target: ripple
                property: "opacity"
                to: 0
                duration: Theme.anim.slow
            }
        }
    }
}
