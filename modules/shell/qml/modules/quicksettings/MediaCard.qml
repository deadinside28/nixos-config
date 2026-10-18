// Карточка плеера: обложка фоном, название, исполнитель, управление, ползунок.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

ClippingRectangle {
    id: root
    readonly property var player: Media.active

    Layout.fillWidth: true
    implicitHeight: 148
    radius: Theme.radius.xl
    color: Theme.surfaceContainerHighest

    Image {
        id: art
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: art
        visible: art.status === Image.Ready
        blurEnabled: true
        blur: 0.6
        blurMax: 48
        saturation: 0.3
    }
    // Слой цвета поверхности поверх размытой обложки: текст читается
    // на любой картинке, а оттенок обложки остаётся.
    Rectangle {
        anchors.fill: parent
        color: Theme.surfaceContainerHighest
        opacity: art.status === Image.Ready ? 0.72 : 0
    }

    readonly property color fg: Theme.fgSurface

    // позиция обновляется только пока карточка видна
    Timer {
        running: root.visible && (root.player?.isPlaying ?? false)
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        ClippingRectangle {
            Layout.preferredWidth: 72
            Layout.preferredHeight: 72
            Layout.alignment: Qt.AlignTop
            radius: Theme.radius.l
            color: Theme.primaryContainer
            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                icon: "music_note"
                color: Theme.fgPrimaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            MText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Ничего не играет"
                color: root.fg
                size: Theme.type.titleM
                weight: Theme.strongWeight
            }
            MText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || root.player?.identity || ""
                color: Theme.alpha(root.fg, 0.75)
            }
            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MIcon {
                    visible: Media.players.length > 1
                    icon: "swap_horiz"
                    size: 20
                    color: Theme.alpha(root.fg, 0.75)
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media.next()
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                IconButton {
                    icon: "skip_previous"
                    iconColor: root.fg
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.previous()
                }
                Rectangle {
                    implicitWidth: 56
                    implicitHeight: 40
                    radius: root.player?.isPlaying ? Theme.radius.m : 20
                    color: Theme.primary
                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.anim.normal
                            easing.type: Easing.OutBack
                        }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        fill: 1
                        color: Theme.fgPrimary
                    }
                    StateLayer {
                        color: Theme.fgPrimary
                        onClicked: root.player.togglePlaying()
                    }
                }
                IconButton {
                    icon: "skip_next"
                    iconColor: root.fg
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.next()
                }
            }
        }
    }

    // тонкая полоса прогресса снизу
    Rectangle {
        anchors.bottom: parent.bottom
        height: 3
        width: parent.width * ((root.player?.length ?? 0) > 0 ? root.player.position / root.player.length : 0)
        color: Theme.primary
        visible: root.player?.lengthSupported ?? false
    }
}
