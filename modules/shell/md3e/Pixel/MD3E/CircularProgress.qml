// Круговой индикатор прогресса M3: дуга прогресса, зазоры и трек.
// value < 0 — неопределённый: дуга растёт, сжимается и вращается.
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property real value: -1
    property real thickness: 8
    property color color: Theme.primary
    property color trackColor: Theme.secondaryContainer
    readonly property bool indeterminate: value < 0

    implicitWidth: 48
    implicitHeight: 48

    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        NumberAnimation {
            duration: Theme.anim.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.standard
        }
    }

    readonly property real r: (Math.min(width, height) - thickness) / 2
    // зазор между дугой и треком, в градусах (с учётом скруглённых концов)
    readonly property real gapDeg: (thickness * 1.5 + 4) / (2 * Math.PI * r) * 360

    // неопределённая анимация
    property real spin: 0
    property real phase: 0
    NumberAnimation on spin {
        running: root.indeterminate && root.visible
        from: 0
        to: 360
        duration: 1568
        loops: Animation.Infinite
    }
    SequentialAnimation on phase {
        running: root.indeterminate && root.visible
        loops: Animation.Infinite
        NumberAnimation {
            from: 0
            to: 1
            duration: 667
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            from: 1
            to: 0
            duration: 667
            easing.type: Easing.InOutCubic
        }
    }

    readonly property real sweep: indeterminate ? 20 + phase * 250 : shown * 360
    readonly property real start: indeterminate ? spin + phase * 140 - 90 : -90

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: false

        // трек — оставшаяся часть круга, с зазорами по обе стороны
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.indeterminate ? 0 : root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: root.start + root.sweep + (root.sweep > 0 ? root.gapDeg : 0)
                sweepAngle: Math.max(0, 360 - root.sweep - (root.sweep > 0 ? 2 * root.gapDeg : 0))
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.sweep > 0.5 ? root.thickness : 0
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.r
                radiusY: root.r
                startAngle: root.start
                sweepAngle: root.sweep
            }
        }
    }
}
