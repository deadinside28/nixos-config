// Быстрые настройки и центр уведомлений — выезжают справа снизу при клике
// по часам. Сверху уведомления, ниже плитки и слайдеры, как на Pixel.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services
import qs.modules.notifications

Overlay {
    id: root
    name: "quicksettings"
    open: Ui.panel === "quicksettings"
    onDismissed: Ui.close()

    property bool mixerOpen: false

    // Идёт ли запись экрана — проверяем, пока панель открыта.
    Process {
        id: recCheck
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => Ui.recording = code === 0
    }
    Timer {
        running: root.open
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: recCheck.running = true
    }

    ColumnLayout {
        id: stack
        width: 420
        // У «таблетки» статуса: она в конце панели
        x: (Bar.edge === "left" ? root.insetLeft + 12 : root.width - root.insetRight - 12 - width) + root.slideX((1 - root.progress) * 40)
        y: (Bar.edge === "top" ? root.insetTop + 12 : root.height - root.insetBottom - 12 - height) + root.slideY((1 - root.progress) * 40)
        opacity: root.progress
        spacing: 12

        // --- Уведомления --------------------------------------------------
        Card {
            id: notifCard
            Layout.fillWidth: true
            visible: Notifs.count > 0
            implicitHeight: Math.min(440, notifCol.implicitHeight + 32)
            color: Theme.surfaceContainer

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
                        text: "Очистить все"
                        onClicked: Notifs.clearAll()
                    }
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

        // --- Быстрые настройки --------------------------------------------
        Card {
            Layout.fillWidth: true
            implicitHeight: qsCol.implicitHeight + 32
            color: Theme.surfaceContainer

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
                            model: Audio.apps
                            AppVolumeRow {
                                required property var modelData
                                Layout.fillWidth: true
                                compact: true
                                app: modelData
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
                PillSlider {
                    Layout.fillWidth: true
                    visible: Brightness.available
                    icon: "brightness_6"
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                }

                // Плитки
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    Tile {
                        icon: Net.icon
                        label: Net.wiredConnected ? "Ethernet" : "Интернет"
                        sublabel: Net.label
                        active: Net.online || Net.wifiEnabled
                        hasDetails: true
                        onToggled: if (Net.hasWifi)
                            Net.setWifi(!Net.wifiEnabled)
                        onDetails: Ui.openSettings("network")
                    }
                    Tile {
                        icon: Bt.icon
                        label: "Bluetooth"
                        sublabel: Bt.label
                        active: Bt.enabled
                        hasDetails: true
                        onToggled: Bt.setEnabled(!Bt.enabled)
                        onDetails: Ui.openSettings("bluetooth")
                    }
                    Tile {
                        icon: Settings.data.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                        label: "Не беспокоить"
                        sublabel: Settings.data.dnd ? "Включено" : "Выключено"
                        active: Settings.data.dnd
                        onToggled: Settings.data.dnd = !Settings.data.dnd
                    }
                    Tile {
                        icon: "nightlight"
                        label: "Ночной режим"
                        sublabel: Settings.data.nightLight ? Settings.data.nightTemp + " K" : "Выключен"
                        active: Settings.data.nightLight
                        onToggled: NightLight.toggle()
                    }
                    Tile {
                        icon: "contrast"
                        label: "Тёмная тема"
                        sublabel: Settings.data.darkMode ? "Включена" : "Выключена"
                        active: Settings.data.darkMode
                        onToggled: Settings.data.darkMode = !Settings.data.darkMode
                    }
                    Tile {
                        icon: Audio.micMuted ? "mic_off" : "mic"
                        label: "Микрофон"
                        sublabel: Audio.micMuted ? "Выключен" : Math.round(Audio.micVolume * 100) + "%"
                        active: !Audio.micMuted && Audio.source !== null
                        onToggled: Audio.toggleMicMute()
                    }
                    Tile {
                        icon: "coffee"
                        label: "Без сна"
                        sublabel: Ui.caffeine ? "Экран не гаснет" : "Выключено"
                        active: Ui.caffeine
                        onToggled: Ui.caffeine = !Ui.caffeine
                    }
                    Tile {
                        icon: Ui.recording ? "stop_circle" : "screen_record"
                        label: "Запись экрана"
                        sublabel: Ui.recording ? "Идёт запись" : "Без микрофона"
                        active: Ui.recording
                        onToggled: {
                            Quickshell.execDetached(["pixel-record", Ui.activeScreen]);
                            Ui.close();
                        }
                    }
                    Tile {
                        icon: "screenshot_region"
                        label: "Скриншот"
                        sublabel: "Область"
                        onToggled: {
                            Ui.close();
                            Quickshell.execDetached(["sh", "-c", "sleep 0.4; pixel-screenshot area"]);
                        }
                    }
                    Tile {
                        icon: "content_paste"
                        label: "Буфер обмена"
                        sublabel: "История"
                        onToggled: Ui.open("clipboard")
                    }
                }

                MediaCard {
                    visible: Media.hasPlayer
                }
            }
        }
    }
}
