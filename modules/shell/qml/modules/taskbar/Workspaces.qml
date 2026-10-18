// Воркспейсы экрана — «точки страниц», как на Android: текущий — вытянутая
// таблетка, занятые — заметные точки, пустые — бледные.
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.common
import qs.services
import Pixel.MD3E

Rectangle {
    id: root
    property string screenName
    readonly property var list: Hypr.workspacesFor(screenName)
    readonly property int activeId: Hypr.activeWorkspaceFor(screenName)?.id ?? -1

    implicitHeight: vertical ? row.implicitHeight + 20 : 32
    implicitWidth: vertical ? 32 : row.implicitWidth + 20
    radius: height / 2
    color: Theme.alpha(Theme.surfaceContainerHighest, 0.7)
    property bool shown: true
    property bool vertical: false
    visible: shown && list.length > 1

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: root.list

            Rectangle {
                id: dot
                required property var modelData
                readonly property bool active: modelData.id === root.activeId
                readonly property bool occupied: (modelData.toplevels?.values?.length ?? 0) > 0

                property real len: active ? 24 : 8
                implicitWidth: root.vertical ? 8 : len
                implicitHeight: root.vertical ? len : 8
                radius: 4
                color: active ? Theme.primary : Theme.alpha(Theme.fgSurfaceVariant, occupied ? 0.75 : 0.3)

                Behavior on len {
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

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(dot.modelData.id)
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            const i = root.list.findIndex(w => w.id === root.activeId);
            const next = root.list[Math.max(0, Math.min(root.list.length - 1, i + (event.angleDelta.y > 0 ? -1 : 1)))];
            if (next)
                Hypr.focusWorkspace(next.id);
        }
    }
}
