// Плитка быстрых настроек Android 16: слева значок в отдельной зоне
// (клик — вкл/выкл), справа подпись (клик — подробности). Включённая
// плитка заливается основным цветом и скругляется сильнее.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets

Rectangle {
    id: root

    property string icon
    property string label
    property string sublabel: ""
    property bool active: false
    property bool hasDetails: false
    signal toggled
    signal details

    readonly property color fg: active ? Theme.onPrimary : Theme.onSurface
    readonly property color fgVariant: active ? Theme.alpha(Theme.onPrimary, 0.8) : Theme.onSurfaceVariant

    Layout.fillWidth: true
    implicitHeight: 72
    radius: active ? height / 2 : Theme.radius.xl * 0.8
    color: active ? Theme.primary : Theme.surfaceContainerHighest

    Behavior on radius {
        NumberAnimation {
            duration: Theme.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.expressiveSpatial
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fast
        }
    }

    StateLayer {
        color: root.fg
        onClicked: root.hasDetails ? root.details() : root.toggled()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: root.active ? 24 : Theme.radius.l
            color: root.hasDetails ? (root.active ? Theme.alpha(Theme.onPrimary, 0.16) : Theme.alpha(Theme.onSurface, 0.08)) : "transparent"
            Behavior on radius {
                NumberAnimation {
                    duration: Theme.anim.normal
                }
            }
            MIcon {
                anchors.centerIn: parent
                icon: root.icon
                fill: root.active ? 1 : 0
                color: root.fg
            }
            StateLayer {
                visible: root.hasDetails
                color: root.fg
                onClicked: root.toggled()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            MText {
                Layout.fillWidth: true
                text: root.label
                color: root.fg
                size: Theme.type.titleS
                weight: Font.Medium
            }
            MText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sublabel
                color: root.fgVariant
                size: Theme.type.bodyS
            }
        }

        MIcon {
            visible: root.hasDetails
            icon: "chevron_right"
            size: 20
            color: root.fgVariant
        }
    }
}
