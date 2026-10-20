// Панель задач в духе режима рабочего стола Pixel / Aluminium OS:
// в начале кнопка лаунчера и воркспейсы, по центру закреплённые и
// запущенные приложения, в конце трей, уведомления и «таблетка» статуса.
// Встаёт к любому краю экрана (Настройки → Рабочий стол и окна).
//
// Это элемент окна-хоста экрана (modules/frame/ScreenHost.qml), а не своё
// окно: у каждого окна оболочки свой GL-контекст и потоки драйвера. Место
// под панель резервирует Hyprland (reserved в правиле монитора,
// services/HyprConf.qml monitorsLua).
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Item {
    id: bar

    required property ShellScreen modelData
    // окно-хост: к нему привязаны меню трея
    required property var window

    readonly property bool vertical: Bar.vertical
    readonly property int barSize: Bar.size

    x: Bar.edge === "right" ? window.width - barSize : 0
    y: Bar.edge === "bottom" ? window.height - barSize : 0
    width: vertical ? barSize : window.width
    height: vertical ? window.height : barSize

    readonly property bool framed: Bar.frameOn(bar.modelData.name)

    // с рамкой фон панели рисует сама рамка (тот же цвет, без стыка)
    Rectangle {
        anchors.fill: parent
        visible: !bar.framed
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
