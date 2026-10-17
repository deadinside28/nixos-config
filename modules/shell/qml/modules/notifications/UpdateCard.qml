// Карточка обновления/пересборки системы в уведомлениях: этап, линейный
// прогресс, по нажатию — окно с подробностями и логом.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services

Rectangle {
    id: root
    property color cardColor: Theme.surfaceContainerHigh
    readonly property bool failed: SystemConfig.status === "failed"
    readonly property bool done: SystemConfig.status === "success"

    implicitHeight: col.implicitHeight + 32
    radius: Theme.radius.xl
    color: failed ? Theme.errorContainer : cardColor

    StateLayer {
        radius: root.radius
        onClicked: {
            Ui.panel = "";
            Ui.updateWindowOpen = true;
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: root.failed ? Theme.error : Theme.primaryContainer
                MIcon {
                    anchors.centerIn: parent
                    icon: root.failed ? "error" : root.done ? "check_circle" : "system_update_alt"
                    color: root.failed ? Theme.fgError : Theme.fgPrimaryContainer
                    fill: root.done || root.failed ? 1 : 0
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                MText {
                    Layout.fillWidth: true
                    text: SystemConfig.task || "Обновление системы"
                    weight: Theme.strongWeight
                    elide: Text.ElideRight
                    color: root.failed ? Theme.fgErrorContainer : Theme.fgSurface
                }
                MText {
                    Layout.fillWidth: true
                    text: SystemConfig.current ? SystemConfig.stage + " · " + SystemConfig.current : SystemConfig.stage
                    size: Theme.type.bodyS
                    color: root.failed ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                    elide: Text.ElideRight
                }
            }
            MText {
                visible: SystemConfig.running && SystemConfig.progress >= 0
                text: Math.round(SystemConfig.progress * 100) + "%"
                weight: Theme.strongWeight
                color: Theme.primary
            }
            IconButton {
                icon: "close"
                implicitWidth: 32
                implicitHeight: 32
                onClicked: SystemConfig.dismissCard()
            }
        }
        LinearProgress {
            Layout.fillWidth: true
            visible: SystemConfig.running
            value: SystemConfig.progress
        }
        MText {
            visible: !SystemConfig.running
            Layout.fillWidth: true
            text: root.done ? (Updates.count > 0 ? "Обновлено пакетов: " + Updates.count + ". Нажми, чтобы посмотреть лог" : "Нажми, чтобы посмотреть лог") : "Нажми, чтобы посмотреть, что пошло не так"
            size: Theme.type.bodyS
            color: root.failed ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
        }
    }
}
