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
import Pixel.MD3E

// Видимые значки — в общей «таблетке», как остальные блоки панели.
Rectangle {
    id: root
    required property var bar
    implicitWidth: row.implicitWidth + (bar.vertical ? 8 : 12)
    implicitHeight: row.implicitHeight + (bar.vertical ? 12 : 8)
    radius: Math.min(width, height) / 2
    color: Theme.alpha(Theme.surfaceContainerHighest, 0.8)
    readonly property bool hasItems: items.length > 0

    readonly property var items: SystemTray.items.values
    readonly property int limit: Math.max(0, Settings.data.trayVisible)
    readonly property var shown: items.slice(0, limit)
    readonly property var hidden: items.slice(limit)

    GridLayout {
    id: row
    anchors.centerIn: parent
    flow: root.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: 2
    columnSpacing: 2

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
        implicitWidth: list.implicitWidth + 16
        implicitHeight: list.implicitHeight + 16
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

            // Скрытые значки — столбиком, с названиями
            ColumnLayout {
                id: list
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: root.hidden
                    TrayIcon {
                        required property var modelData
                        Layout.fillWidth: true
                        item: modelData
                        bar: root.bar
                        menuWindow: overflow
                        labeled: true
                    }
                }
            }
        }
    }
}
