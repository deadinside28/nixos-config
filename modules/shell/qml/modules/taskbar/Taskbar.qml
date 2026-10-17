// Панель задач в духе режима рабочего стола Pixel / Aluminium OS:
// слева кнопка лаунчера и воркспейсы, по центру закреплённые и запущенные
// приложения, справа трей, уведомления и «таблетка» статуса с часами.
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

    readonly property int barHeight: 56

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: barHeight
    exclusiveZone: barHeight
    color: "transparent"
    WlrLayershell.namespace: "pixel-shell:taskbar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.surfaceContainer, 0.86)

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: Theme.alpha(Theme.outlineVariant, 0.5)
        }
    }

    // Левая часть
    RowLayout {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        LauncherButton {
            screenName: bar.modelData.name
        }

        Workspaces {
            shown: Settings.data.showWorkspaces
            screenName: bar.modelData.name
        }
    }

    // Приложения
    AppStrip {
        id: apps
        bar: bar
        anchors.verticalCenter: parent.verticalCenter
        x: Settings.data.taskbarCentered ? Math.max(left.x + left.width + 16, (parent.width - width) / 2) : left.x + left.width + 16
        Behavior on x {
            NumberAnimation {
                duration: Theme.anim.normal
                easing.type: Easing.OutCubic
            }
        }
    }

    // Правая часть
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Tray {
            visible: Settings.data.showTray
            bar: bar
        }

        NotificationPill {
            screenName: bar.modelData.name
        }

        StatusPill {
            screenName: bar.modelData.name
        }
    }
}
