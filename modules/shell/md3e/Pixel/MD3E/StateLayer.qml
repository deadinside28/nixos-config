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
        ripple.px = event.x;
        ripple.py = event.y;
        ripple.active = false;
        ripple.active = true;
    }

    Rectangle {
        id: clip
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: Theme.alpha(root.color, root.pressed ? Theme.pressOpacity : root.containsMouse ? Theme.hoverOpacity : 0)
        clip: ripple.active

        Behavior on color {
            ColorAnimation {
                duration: Theme.anim.fast
            }
        }

        // Круг ряби создаётся только на время анимации. Скруглённый
        // прямоугольник большого радиуса дорог сам по себе — даже
        // невидимый он держит геометрию (и кеш программной отрисовки),
        // около 4 МБ на штуку, а StateLayer есть почти в каждом пункте,
        // кнопке и карточке.
        Loader {
            id: ripple
            property real px
            property real py
            active: false
            sourceComponent: Rectangle {
                id: circle
                readonly property real d: Math.max(root.width, root.height) * 2.2
                x: ripple.px - d / 2
                y: ripple.py - d / 2
                width: d
                height: d
                radius: d / 2
                color: root.color
                opacity: 0
                scale: 0
                ParallelAnimation {
                    running: true
                    onFinished: ripple.active = false
                    NumberAnimation {
                        target: circle
                        property: "scale"
                        from: 0
                        to: 1
                        duration: Theme.anim.slow
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: circle
                            property: "opacity"
                            to: 0.10
                            duration: 60
                        }
                        NumberAnimation {
                            target: circle
                            property: "opacity"
                            to: 0
                            duration: Theme.anim.slow
                        }
                    }
                }
            }
        }
    }
}
