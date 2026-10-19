// Быстрые настройки и центр уведомлений — выезжают справа снизу при клике
// по часам. Сверху плитки и слайдеры, под ними уведомления.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services
import qs.modules.notifications
import Pixel.MD3E

Overlay {
    id: root
    name: "quicksettings"
    open: Ui.panel === "quicksettings"
    onDismissed: Ui.close()

    property bool mixerOpen: false
    property bool brightOpen: false

    // Идёт ли запись экрана — проверяем, пока панель открыта.

    ColumnLayout {
        id: stack
        width: 460
        // У «таблетки» статуса: она в конце панели
        x: Bar.edge === "left" ? root.insetLeft + 12 : root.width - root.insetRight - 12 - width
        // Шторка всегда на одном месте — сверху, уведомления растут под ней
        // и не двигают её, сколько бы их ни было.
        y: root.insetTop + 12 + root.slideY((1 - root.progress) * 40)
        opacity: root.progress
        spacing: 12

        // --- Быстрые настройки --------------------------------------------
        Card {
            id: qsCard
            Layout.fillWidth: true
            implicitHeight: qsCol.implicitHeight + 32
            color: Theme.panel

            ColumnLayout {
                id: qsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                // Заголовок: дата и кнопки
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    spacing: 4

                    ColumnLayout {
                        spacing: 0
                        MText {
                            text: Time.time
                            size: Theme.type.headlineM
                            weight: Font.Normal
                        }
                        MText {
                            text: Time.dateLong.charAt(0).toUpperCase() + Time.dateLong.slice(1)
                            color: Theme.fgSurfaceVariant
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    MText {
                        visible: Battery.present
                        text: Math.round(Battery.percent * 100) + "%"
                        color: Theme.fgSurfaceVariant
                        Layout.rightMargin: 8
                    }
                    IconButton {
                        icon: "lock"
                        variant: "tonal"
                        onClicked: {
                            Ui.close();
                            Ui.locked = true;
                        }
                    }
                    IconButton {
                        icon: "settings"
                        variant: "tonal"
                        onClicked: Ui.openSettings("")
                    }
                    IconButton {
                        icon: "power_settings_new"
                        variant: "filled"
                        onClicked: Ui.open("power")
                    }
                }

                // Слайдеры
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    PillSlider {
                        Layout.fillWidth: true
                        icon: Audio.icon
                        muted: Audio.muted
                        value: Audio.volume
                        onMoved: v => Audio.setVolume(v)
                        onIconClicked: Audio.toggleMute()
                    }
                    IconButton {
                        implicitWidth: 52
                        implicitHeight: 52
                        variant: "tonal"
                        checkable: true
                        toggled: root.mixerOpen
                        icon: "tune"
                        onClicked: root.mixerOpen = !root.mixerOpen
                    }
                }

                // Микшер: громкость каждого приложения, как в Windows
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.mixerOpen
                    implicitHeight: mixCol.implicitHeight + 24
                    radius: Theme.radius.xl * 0.8
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: mixCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        anchors.leftMargin: 16
                        spacing: 4

                        Repeater {
                            model: ScriptModel {
                                values: Audio.appKeys
                            }
                            AppVolumeRow {
                                required property string modelData
                                Layout.fillWidth: true
                                compact: true
                                app: Audio.appByKey(modelData)
                            }
                        }
                        MText {
                            visible: Audio.apps.length === 0
                            Layout.topMargin: 4
                            Layout.bottomMargin: 4
                            text: "Сейчас ничего не играет"
                            color: Theme.fgSurfaceVariant
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            variant: "text"
                            icon: "settings"
                            text: "Настройки звука"
                            onClicked: Ui.openSettings("sound")
                        }
                    }
                }
                // Яркость — как звук: общий слайдер и раскрывашка по мониторам
                RowLayout {
                    Layout.fillWidth: true
                    visible: Brightness.available && Settings.data.qsShowBrightness
                    spacing: 8
                    PillSlider {
                        Layout.fillWidth: true
                        icon: "brightness_6"
                        value: Brightness.value
                        onMoved: v => Brightness.set(v)
                    }
                    IconButton {
                        visible: Brightness.names.length > 1
                        implicitWidth: 52
                        implicitHeight: 52
                        variant: "tonal"
                        checkable: true
                        toggled: root.brightOpen
                        icon: "desktop_windows"
                        onClicked: root.brightOpen = !root.brightOpen
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.brightOpen && Brightness.available && Settings.data.qsShowBrightness
                    implicitHeight: brightCol.implicitHeight + 24
                    radius: Theme.radius.xl * 0.8
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: brightCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        anchors.leftMargin: 16
                        spacing: 4

                        Repeater {
                            model: ScriptModel {
                                values: Brightness.names
                            }
                            RowLayout {
                                id: brow
                                required property string modelData
                                readonly property real level: Brightness.valueFor(modelData)
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    radius: 16
                                    color: brow.modelData === Ui.activeScreen ? Theme.primaryContainer : Theme.secondaryContainer
                                    MIcon {
                                        anchors.centerIn: parent
                                        icon: brow.modelData === "backlight" ? "laptop" : "monitor"
                                        size: 18
                                        color: brow.modelData === Ui.activeScreen ? Theme.fgPrimaryContainer : Theme.fgSecondaryContainer
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    RowLayout {
                                        Layout.fillWidth: true
                                        MText {
                                            Layout.fillWidth: true
                                            text: Brightness.label(brow.modelData)
                                            size: Theme.type.bodyM
                                            elide: Text.ElideRight
                                        }
                                        MText {
                                            text: Math.round(brow.level * 100) + "%"
                                            color: Theme.fgSurfaceVariant
                                            size: Theme.type.bodyS
                                        }
                                    }
                                    MSlider {
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        value: brow.level
                                        onMoved: v => Brightness.set(v, brow.modelData)
                                    }
                                }
                            }
                        }
                        Button {
                            Layout.alignment: Qt.AlignRight
                            variant: "text"
                            icon: "settings"
                            text: "Настройки экрана"
                            onClicked: Ui.openSettings("display")
                        }
                    }
                }

                // Плитки — состав и порядок из «Настройки → Быстрые настройки»
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    Repeater {
                        model: Settings.data.qsTiles.filter(id => QsTiles.byId(id))
                        Tile {
                            id: tile
                            required property string modelData
                            readonly property var t: QsTiles.byId(modelData)
                            icon: t.icon()
                            label: t.label
                            sublabel: t.sub()
                            active: t.active()
                            hasDetails: !!t.details
                            onToggled: t.toggle()
                            onDetails: t.details()
                        }
                    }
                }

                MediaCard {
                    visible: Media.hasPlayer && Settings.data.qsShowMedia
                }
            }
        }

        // --- Уведомления (под шторкой) --------------------------------------------------
        Card {
            id: notifCard
            Layout.fillWidth: true
            visible: Notifs.count > 0 || !SystemConfig.cardDismissed
            // сколько влезет под шторкой
            implicitHeight: Math.min(notifCol.implicitHeight + 32, Math.max(180, root.height - root.insetTop - root.insetBottom - 36 - qsCard.height))
            color: Theme.panel

            ColumnLayout {
                id: notifCol
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    MText {
                        Layout.fillWidth: true
                        text: "Уведомления"
                        size: Theme.type.titleM
                        weight: Theme.strongWeight
                    }
                    Button {
                        variant: "tonal"
                        implicitHeight: 32
                        visible: Notifs.count > 0
                        text: "Очистить все"
                        onClicked: Notifs.clearAll()
                    }
                }

                // Обновление системы — первой карточкой
                UpdateCard {
                    Layout.fillWidth: true
                    visible: !SystemConfig.cardDismissed
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: contentHeight
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: ScriptModel {
                        values: Notifs.list
                    }
                    delegate: NotificationCard {
                        required property var modelData
                        width: ListView.view.width
                        notification: modelData
                        cardColor: Theme.surfaceContainerHigh
                        onClosed: Notifs.dismiss(modelData)
                    }
                }
            }
        }

    }
}
