import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.common
import qs.widgets
import qs.services

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

    Group {
        title: "Приложения"
        visible: true

        Repeater {
            model: Audio.playbackStreams
            Rectangle {
                id: stream
                required property var modelData
                readonly property bool groupItem: true
                property bool first: true
                property bool last: true
                Layout.fillWidth: true
                implicitHeight: 88
                color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                topLeftRadius: first ? 24 : 4
                topRightRadius: first ? 24 : 4
                bottomLeftRadius: last ? 24 : 4
                bottomRightRadius: last ? 24 : 4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 16
                    AppIcon {
                        size: 36
                        icon: Audio.streamIcon(stream.modelData)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MText {
                            Layout.fillWidth: true
                            text: Audio.streamName(stream.modelData)
                            size: Theme.type.bodyL
                        }
                        MSlider {
                            Layout.fillWidth: true
                            value: stream.modelData.audio?.volume ?? 0
                            onMoved: v => {
                                stream.modelData.audio.muted = false;
                                stream.modelData.audio.volume = v;
                            }
                        }
                    }
                    IconButton {
                        icon: stream.modelData.audio?.muted ? "volume_off" : "volume_up"
                        toggled: stream.modelData.audio?.muted ?? false
                        onClicked: stream.modelData.audio.muted = !stream.modelData.audio.muted
                    }
                }
            }
        }

        ListItem {
            visible: Audio.playbackStreams.length === 0
            icon: "music_off"
            title: "Сейчас ничего не воспроизводит звук"
            clickable: false
        }
    }

    Group {
        title: "Дополнительно"
        ListItem {
            icon: "equalizer"
            title: "Микшер PipeWire"
            subtitle: "Профили устройств, маршрутизация, каналы"
            chevron: true
            onClicked: Apps.run(["pavucontrol"])
        }
    }
}
