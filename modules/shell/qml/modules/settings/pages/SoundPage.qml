import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

SettingsPage {
    id: page
    title: "Звук"

    Group {
        title: "Выход"
        SliderItem {
            icon: Audio.icon
            title: "Громкость"
            valueText: Audio.muted ? "Без звука" : Math.round(Audio.volume * 100) + "%"
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
        }
        SwitchItem {
            icon: "volume_off"
            title: "Без звука"
            checked: Audio.muted
            onToggled: Audio.toggleMute()
        }
        ChoiceItem {
            icon: "speaker"
            title: "Устройство вывода"
            options: Audio.sinks.map(n => ({
                        value: n.id,
                        label: Audio.nodeName(n)
                    }))
            current: Audio.sink?.id
            onSelected: v => Pipewire.preferredDefaultAudioSink = Audio.sinks.find(n => n.id === v)
        }
    }

    Group {
        title: "Вход"
        SliderItem {
            icon: Audio.micMuted ? "mic_off" : "mic"
            title: "Чувствительность микрофона"
            valueText: Audio.micMuted ? "Выключен" : Math.round(Audio.micVolume * 100) + "%"
            value: Audio.micVolume
            onMoved: v => Audio.setMicVolume(v)
        }
        SwitchItem {
            icon: "mic_off"
            title: "Выключить микрофон"
            checked: Audio.micMuted
            onToggled: Audio.toggleMicMute()
        }
        ChoiceItem {
            icon: "mic"
            title: "Устройство ввода"
            options: Audio.sources.map(n => ({
                        value: n.id,
                        label: Audio.nodeName(n)
                    }))
            current: Audio.source?.id
            onSelected: v => Pipewire.preferredDefaultAudioSource = Audio.sources.find(n => n.id === v)
        }
    }

    // Профиль карты: HDMI или аналоговый выход, A2DP или гарнитура
    Group {
        title: "Профили устройств"
        visible: Audio.cards.length > 0
        Repeater {
            model: Audio.cards
            ChoiceItem {
                required property var modelData
                icon: /hdmi|displayport/i.test(modelData.name) ? "tv" : /bluetooth|headset|наушник/i.test(modelData.name) ? "headphones" : "speaker_group"
                title: modelData.name
                options: modelData.profiles
                current: modelData.current
                onSelected: v => Audio.setProfile(modelData, v)
            }
        }
    }
    Component.onCompleted: Audio.refreshCards()

    Group {
        title: "Громкость приложений"

        Repeater {
            model: ScriptModel {
                values: Audio.appKeys
            }
            Rectangle {
                id: app
                required property string modelData
                readonly property var entry: Audio.appByKey(modelData)
                readonly property bool groupItem: true
                property bool first: true
                property bool last: true
                Layout.fillWidth: true
                implicitHeight: col.implicitHeight + 24
                color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                topLeftRadius: first ? 24 : 4
                topRightRadius: first ? 24 : 4
                bottomLeftRadius: last ? 24 : 4
                bottomRightRadius: last ? 24 : 4

                ColumnLayout {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    anchors.rightMargin: 12
                    spacing: 4

                    AppVolumeRow {
                        Layout.fillWidth: true
                        app: app.entry
                    }

                    // Вывод на другое устройство — только когда их больше одного
                    RowLayout {
                        visible: Audio.sinks.length > 1
                        Layout.leftMargin: 56
                        spacing: 8
                        MIcon {
                            icon: "speaker"
                            size: 18
                            color: Theme.fgSurfaceVariant
                        }
                        Repeater {
                            model: Audio.sinks
                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool sel: Audio.appSinkId(app.entry) === modelData.id
                                implicitHeight: 32
                                implicitWidth: chipText.implicitWidth + 24
                                radius: Theme.radius.s
                                color: sel ? Theme.secondaryContainer : "transparent"
                                border.width: sel ? 0 : 1
                                border.color: Theme.outlineVariant
                                MText {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: Audio.nodeName(chip.modelData)
                                    size: Theme.type.labelL
                                    color: chip.sel ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                                    width: Math.min(implicitWidth, 220)
                                }
                                StateLayer {
                                    onClicked: Audio.moveApp(app.entry, chip.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        ListItem {
            visible: Audio.apps.length === 0
            icon: "music_off"
            title: "Сейчас ничего не воспроизводит звук"
            clickable: false
        }
    }
}
