// Линейный индикатор прогресса M3 Expressive: активная полоса, зазор,
// трек и точка-ограничитель в конце. value < 0 — неопределённый режим
// (две полосы бегут по треку).
import QtQuick

Item {
    id: root
    property real value: -1
    property real thickness: 4
    property color color: Theme.primary
    property color trackColor: Theme.secondaryContainer
    readonly property bool indeterminate: value < 0
    readonly property real gap: 4

    implicitWidth: 200
    implicitHeight: thickness

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        NumberAnimation {
            duration: Theme.anim.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.standard
        }
    }

    // --- определённый --------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: !root.indeterminate

        Rectangle {
            width: root.shown * parent.width
            height: parent.height
            radius: height / 2
            color: root.color
            visible: width > 0.5
        }
        Rectangle {
            x: root.shown * parent.width + (root.shown > 0 ? root.gap : 0)
            width: Math.max(0, parent.width - x)
            height: parent.height
            radius: height / 2
            color: root.trackColor
            visible: width > 0
        }
        // точка-ограничитель
        Rectangle {
            x: parent.width - width
            width: root.thickness
            height: width
            radius: width / 2
            color: root.color
            visible: root.shown < 0.98
        }
    }

    // --- неопределённый ------------------------------------------------------
    Item {
        id: ind
        anchors.fill: parent
        visible: root.indeterminate
        clip: true
        property real t: 0
        NumberAnimation on t {
            running: ind.visible
            from: 0
            to: 1
            duration: 1750
            loops: Animation.Infinite
        }
        // две «змейки» по классическим кривым Material
        readonly property real h1: Math.max(0, Math.min(1, (t - 0) / 0.6))
        readonly property real t1: Math.max(0, Math.min(1, (t - 0.15) / 0.55))
        readonly property real h2: Math.max(0, Math.min(1, (t - 0.45) / 0.45))
        readonly property real t2: Math.max(0, Math.min(1, (t - 0.6) / 0.4))
        function ease(x) {
            return 1 - Math.pow(1 - x, 2.4);
        }
        readonly property real a1: ease(t1) * width * 1.2 - width * 0.1
        readonly property real b1: ease(h1) * width * 1.2 - width * 0.1
        readonly property real a2: ease(t2) * width * 1.2 - width * 0.1
        readonly property real b2: ease(h2) * width * 1.2 - width * 0.1

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.trackColor
        }
        Rectangle {
            x: ind.a1
            width: Math.max(0, ind.b1 - ind.a1)
            height: parent.height
            radius: height / 2
            color: root.color
        }
        Rectangle {
            x: ind.a2
            width: Math.max(0, ind.b2 - ind.a2)
            height: parent.height
            radius: height / 2
            color: root.color
        }
    }
}
