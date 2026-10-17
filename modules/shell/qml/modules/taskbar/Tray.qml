// Системный трей (StatusNotifierItem): Steam, Telegram и т.п.
// Видно первые несколько значков, остальные — под стрелкой во всплывающем
// окошке, как в Windows. Сколько показывать — в «Рабочий стол и окна».
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.common
import qs.widgets

GridLayout {
    id: root
    required property var bar
    flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 2
    columnSpacing: 2

    readonly property var items: SystemTray.items.values
    readonly property int limit: Math.max(0, Settings.data.trayVisible)
    readonly property var shown: items.slice(0, limit)
    readonly property var hidden: items.slice(limit)

    // Стрелка «ещё»
    Rectangle {
        id: more
        visible: root.hidden.length > 0
        implicitWidth: 34
        implicitHeight: 34
        radius: height / 2
        color: overflow.visible ? Theme.secondaryContainer : "transparent"
        MIcon {
            anchors.centerIn: parent
            icon: Bar.edge === "top" ? "expand_more" : Bar.edge === "left" ? "chevron_right" : Bar.edge === "right" ? "chevron_left" : "expand_less"
            size: 20
            color: overflow.visible ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
        }
        StateLayer {
            onClicked: overflow.visible = !overflow.visible
        }
    }

    Repeater {
        model: root.shown
        TrayIcon {
            required property var modelData
            item: modelData
            bar: root.bar
        }
    }

    PopupWindow {
        id: overflow
        anchor.window: root.bar
        anchor.item: more
        anchor.edges: Bar.popupEdge
        anchor.gravity: Bar.popupEdge
        anchor.margins.top: Bar.edge === "bottom" ? -8 : 0
        anchor.margins.bottom: Bar.edge === "top" ? -8 : 0
        anchor.margins.left: Bar.edge === "right" ? -8 : 0
        anchor.margins.right: Bar.edge === "left" ? -8 : 0
        implicitWidth: grid.implicitWidth + 16
        implicitHeight: grid.implicitHeight + 16
        color: "transparent"
        visible: false

        HyprlandFocusGrab {
            windows: [overflow]
            active: overflow.visible
            onCleared: overflow.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.l
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)

            GridLayout {
                id: grid
                anchors.centerIn: parent
                columns: Math.min(4, Math.max(1, root.hidden.length))
                rowSpacing: 2
                columnSpacing: 2
                Repeater {
                    model: root.hidden
                    TrayIcon {
                        required property var modelData
                        item: modelData
                        bar: root.bar
                        menuWindow: overflow
                    }
                }
            }
        }
    }
}
