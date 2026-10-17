// Панель задач в духе режима рабочего стола Pixel / Aluminium OS:
// в начале кнопка лаунчера и воркспейсы, по центру закреплённые и
// запущенные приложения, в конце трей, уведомления и «таблетка» статуса.
// Встаёт к любому краю экрана (Настройки → Рабочий стол и окна).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.widgets
import qs.services

PanelWindow {
    id: bar

    required property ShellScreen modelData
    screen: modelData

    readonly property bool vertical: Bar.vertical
    readonly property int barSize: Bar.size

    anchors {
        bottom: Bar.edge !== "top"
        top: Bar.edge !== "bottom"
        left: Bar.edge !== "right"
        right: Bar.edge !== "left"
    }
    implicitHeight: barSize
    implicitWidth: barSize
    exclusiveZone: barSize
    color: "transparent"
    WlrLayershell.namespace: "pixel-shell:taskbar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: Theme.panel

        // тонкая линия со стороны рабочего стола
        Rectangle {
            color: Theme.alpha(Theme.outlineVariant, 0.5)
            width: bar.vertical ? 1 : parent.width
            height: bar.vertical ? parent.height : 1
            x: Bar.edge === "left" ? parent.width - 1 : 0
            y: Bar.edge === "bottom" ? 0 : Bar.edge === "top" ? parent.height - 1 : 0
        }
    }

    // Начало: лаунчер и воркспейсы
    GridLayout {
        id: start
        flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 8
        columnSpacing: 8
        x: bar.vertical ? (bar.width - width) / 2 : 12
        y: bar.vertical ? 12 : (bar.height - height) / 2

        LauncherButton {
            Layout.alignment: Qt.AlignCenter
            screenName: bar.modelData.name
        }
        Workspaces {
            Layout.alignment: Qt.AlignCenter
            shown: Settings.data.showWorkspaces
            vertical: bar.vertical
            screenName: bar.modelData.name
        }
    }

    // Приложения
    AppStrip {
        id: apps
        bar: bar
        readonly property real startEnd: bar.vertical ? start.y + start.height + 16 : start.x + start.width + 16
        readonly property real centered: bar.vertical ? (bar.height - height) / 2 : (bar.width - width) / 2
        // не заезжать на трей и часы в конце панели
        readonly property real endStart: (bar.vertical ? end.y : end.x) - 16 - (bar.vertical ? height : width)
        readonly property real pos: Math.max(startEnd, Math.min(Settings.data.taskbarCentered ? centered : startEnd, endStart))
        x: bar.vertical ? (bar.width - width) / 2 : pos
        y: bar.vertical ? pos : (bar.height - height) / 2
        Behavior on x {
            enabled: !bar.vertical
            NumberAnimation {
                duration: Theme.anim.normal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: bar.vertical
            NumberAnimation {
                duration: Theme.anim.normal
                easing.type: Easing.OutCubic
            }
        }
    }

    // Конец: трей, уведомления, статус
    GridLayout {
        id: end
        flow: bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 8
        columnSpacing: 8
        x: bar.vertical ? (bar.width - width) / 2 : bar.width - width - 12
        y: bar.vertical ? bar.height - height - 12 : (bar.height - height) / 2

        UpdatesPill {
            Layout.alignment: Qt.AlignCenter
            bar: bar
        }
        Tray {
            Layout.alignment: Qt.AlignCenter
            visible: Settings.data.showTray && hasItems
            bar: bar
        }
        NotificationPill {
            Layout.alignment: Qt.AlignCenter
            screenName: bar.modelData.name
        }
        StatusPill {
            Layout.alignment: Qt.AlignCenter
            vertical: bar.vertical
            screenName: bar.modelData.name
        }
    }
}
