// Окно обновления системы: большой круговой индикатор M3 с процентом,
// этап, счётчики сборок и загрузок и живой лог Nix.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Scope {
    LazyLoader {
        active: Ui.updateWindowOpen

        FloatingWindow {
            id: win
            title: "Обновление системы"
            implicitWidth: 760
            implicitHeight: 640
            minimumSize: Qt.size(560, 480)
            color: Theme.surfaceContainer
            visible: true
            onVisibleChanged: if (!visible)
                Ui.updateWindowOpen = false

            readonly property bool running: SystemConfig.running
            readonly property bool failed: SystemConfig.status === "failed"
            readonly property bool done: SystemConfig.status === "success"
            property bool autoScroll: true

            // тикающие часы для «прошло времени»
            property date now: new Date()
            Timer {
                running: win.running
                interval: 1000
                repeat: true
                onTriggered: win.now = new Date()
            }
            function elapsed() {
                const end = win.running ? win.now : SystemConfig.finishedAt;
                const s = Math.max(0, Math.round((end - SystemConfig.startedAt) / 1000));
                return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
            }

            Shortcut {
                sequence: "Escape"
                onActivated: Ui.updateWindowOpen = false
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                // --- Шапка: круг + этап ----------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 24

                    Item {
                        implicitWidth: 132
                        implicitHeight: 132
                        CircularProgress {
                            anchors.fill: parent
                            thickness: 10
                            value: win.done ? 1 : win.failed ? Math.max(0, SystemConfig.progress) : SystemConfig.progress
                            color: win.failed ? Theme.error : Theme.primary
                        }
                        MText {
                            anchors.centerIn: parent
                            visible: SystemConfig.progress >= 0 || win.done
                            text: win.done ? "" : Math.round(SystemConfig.progress * 100) + "%"
                            size: Theme.type.headlineS
                            weight: Theme.strongWeight
                        }
                        MIcon {
                            anchors.centerIn: parent
                            visible: win.done || (win.failed && SystemConfig.progress < 0)
                            icon: win.done ? "check" : "close"
                            size: 48
                            color: win.done ? Theme.primary : Theme.error
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MText {
                            Layout.fillWidth: true
                            text: SystemConfig.task || "Обновление системы"
                            size: Theme.type.headlineS
                            elide: Text.ElideRight
                        }
                        MText {
                            Layout.fillWidth: true
                            text: SystemConfig.stage
                            size: Theme.type.bodyL
                            color: win.failed ? Theme.error : Theme.fgSurfaceVariant
                            wrapMode: Text.WordWrap
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: SystemConfig.current !== ""
                            text: SystemConfig.current
                            size: Theme.type.bodyS
                            font.family: Theme.monoFont
                            color: Theme.fgSurfaceVariant
                            elide: Text.ElideMiddle
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 8
                            Chip {
                                icon: "schedule"
                                text: win.elapsed()
                            }
                            Chip {
                                visible: SystemConfig.buildsTotal > 0
                                icon: "construction"
                                text: "Сборка " + SystemConfig.buildsDone + " / " + SystemConfig.buildsTotal
                            }
                            Chip {
                                visible: SystemConfig.fetchTotal > 0
                                icon: "download"
                                text: "Загрузка " + SystemConfig.fetchDone + " / " + SystemConfig.fetchTotal
                            }
                            Chip {
                                visible: win.done && Updates.count > 0
                                icon: "upgrade"
                                text: "Обновлено пакетов: " + Updates.count
                            }
                        }
                    }
                }

                // --- Лог -------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius.xl
                    color: Theme.surfaceContainerLowest
                    clip: true

                    ListView {
                        id: logView
                        anchors.fill: parent
                        anchors.margins: 16
                        model: SystemConfig.log
                        boundsBehavior: Flickable.StopAtBounds
                        reuseItems: true
                        delegate: MText {
                            required property string modelData
                            width: ListView.view.width
                            text: modelData
                            font.family: Theme.monoFont
                            size: Theme.type.bodyS
                            wrapMode: Text.WrapAnywhere
                            color: modelData.startsWith("▸") ? Theme.primary : /error|ошибка/i.test(modelData) ? Theme.error : modelData.startsWith("    ") ? Theme.fgSurfaceVariant : Theme.fgSurface
                            weight: modelData.startsWith("▸") ? Theme.strongWeight : Theme.fontWeight
                        }
                        onCountChanged: if (win.autoScroll)
                            Qt.callLater(positionViewAtEnd)
                        onMovementEnded: win.autoScroll = atYEnd
                    }
                    MText {
                        anchors.centerIn: parent
                        visible: logView.count === 0
                        text: "Лог появится, когда начнётся работа"
                        color: Theme.fgSurfaceVariant
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        visible: !win.autoScroll
                        variant: "tonal"
                        icon: "arrow_downward"
                        onClicked: {
                            win.autoScroll = true;
                            logView.positionViewAtEnd();
                        }
                    }
                }

                // --- Кнопки ----------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Button {
                        variant: "text"
                        icon: "content_copy"
                        text: "Скопировать лог"
                        onClicked: Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | wl-copy", "sh", SystemConfig.log.join("\n")])
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Button {
                        visible: win.running
                        variant: "tonal"
                        icon: "stop"
                        text: "Остановить"
                        onClicked: SystemConfig.cancel()
                    }
                    Button {
                        visible: win.failed
                        variant: "tonal"
                        icon: "refresh"
                        text: "Повторить"
                        onClicked: SystemConfig.retry()
                    }
                    Button {
                        text: win.running ? "Свернуть" : "Закрыть"
                        onClicked: Ui.updateWindowOpen = false
                    }
                }
            }

            component Chip: Rectangle {
                id: chip
                property string icon
                property string text
                implicitWidth: chipRow.implicitWidth + 24
                implicitHeight: 32
                radius: Theme.radius.s
                color: Theme.secondaryContainer
                RowLayout {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: 6
                    MIcon {
                        icon: chip.icon
                        size: 18
                        color: Theme.fgSecondaryContainer
                    }
                    MText {
                        text: chip.text
                        size: Theme.type.labelL
                        color: Theme.fgSecondaryContainer
                    }
                }
            }
        }
    }
}
