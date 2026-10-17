// Обновление системы в панели: пока идёт — маленький круговой прогресс с
// процентом (нажатие открывает окно с логом); после — сколько пакетов
// обновилось, а во всплывашке — список «было → стало».
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.widgets
import qs.services

Rectangle {
    id: root
    required property var bar
    readonly property bool running: SystemConfig.running

    visible: Settings.data.showUpdates && (running || Updates.unseen)
    implicitWidth: bar.vertical ? 34 : row.implicitWidth + 20
    implicitHeight: bar.vertical ? row.implicitHeight + 16 : 34
    radius: Math.min(width, height) / 2
    color: running ? Theme.alpha(Theme.surfaceContainerHighest, 0.8) : Theme.tertiaryContainer

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: root.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 4
        columnSpacing: 6

        Item {
            Layout.alignment: Qt.AlignCenter
            implicitWidth: 20
            implicitHeight: 20
            CircularProgress {
                anchors.fill: parent
                visible: root.running
                thickness: 3
                value: SystemConfig.progress
            }
            MIcon {
                anchors.centerIn: parent
                visible: !root.running
                icon: "upgrade"
                size: 20
                color: Theme.fgTertiaryContainer
            }
        }
        MText {
            Layout.alignment: Qt.AlignCenter
            visible: !root.bar.vertical || !root.running
            text: root.running ? (SystemConfig.progress >= 0 ? Math.round(SystemConfig.progress * 100) + "%" : "") : Updates.count
            size: Theme.type.labelL
            weight: Font.DemiBold
            color: root.running ? Theme.fgSurface : Theme.fgTertiaryContainer
        }
    }

    StateLayer {
        onClicked: {
            if (root.running)
                Ui.updateWindowOpen = true;
            else
                popup.visible = !popup.visible;
        }
    }

    Tooltip {
        target: root
        bar: root.bar
        shown: hover.hovered && !popup.visible
        text: root.running ? SystemConfig.task + ": " + SystemConfig.stage : "Обновлено пакетов: " + Updates.count
    }
    HoverHandler {
        id: hover
    }

    PopupWindow {
        id: popup
        anchor.window: root.bar
        anchor.item: root
        anchor.edges: Bar.popupEdge
        anchor.gravity: Bar.popupEdge
        anchor.margins.top: Bar.edge === "bottom" ? -8 : 0
        anchor.margins.bottom: Bar.edge === "top" ? -8 : 0
        anchor.margins.left: Bar.edge === "right" ? -8 : 0
        anchor.margins.right: Bar.edge === "left" ? -8 : 0
        implicitWidth: 420
        implicitHeight: Math.min(560, content.implicitHeight + 32)
        color: "transparent"
        visible: false

        HyprlandFocusGrab {
            windows: [popup]
            active: popup.visible
            onCleared: popup.visible = false
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.xl
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MText {
                            text: "Что обновилось"
                            size: Theme.type.titleM
                            weight: Theme.strongWeight
                        }
                        MText {
                            text: "Поколение " + Updates.previous + " → " + Updates.generation + " · обновлено " + Updates.updated.length + ", новых " + (Updates.count - Updates.updated.length)
                            size: Theme.type.bodyS
                            color: Theme.fgSurfaceVariant
                        }
                    }
                    Button {
                        variant: "tonal"
                        implicitHeight: 32
                        text: "Просмотрено"
                        onClicked: {
                            Updates.markSeen();
                            popup.visible = false;
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: contentHeight
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: Updates.changes
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        implicitHeight: 52
                        radius: Theme.radius.s
                        topLeftRadius: index === 0 ? 16 : 4
                        topRightRadius: index === 0 ? 16 : 4
                        bottomLeftRadius: index === Updates.changes.length - 1 ? 16 : 4
                        bottomRightRadius: index === Updates.changes.length - 1 ? 16 : 4
                        color: Theme.surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12
                            MIcon {
                                icon: entry.modelData.kind === "added" ? "add_circle" : entry.modelData.kind === "removed" ? "remove_circle" : "arrow_circle_up"
                                size: 20
                                color: entry.modelData.kind === "removed" ? Theme.fgSurfaceVariant : Theme.primary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                MText {
                                    Layout.fillWidth: true
                                    text: entry.modelData.name
                                    weight: Theme.strongWeight
                                    elide: Text.ElideRight
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: entry.modelData.kind === "added" ? "новый · " + entry.modelData.to : entry.modelData.kind === "removed" ? "удалён · был " + entry.modelData.from : entry.modelData.from + "  →  " + entry.modelData.to
                                    size: Theme.type.bodyS
                                    font.family: Theme.monoFont
                                    color: Theme.fgSurfaceVariant
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
