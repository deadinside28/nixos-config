// «Таблетка» статуса: сеть, Bluetooth, звук, батарея, часы и дата.
// Клик — быстрые настройки, колесо — громкость.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services

Rectangle {
    id: root
    property string screenName
    readonly property bool active: Ui.panel === "quicksettings"

    implicitHeight: 40
    implicitWidth: row.implicitWidth + 28
    radius: height / 2
    color: active ? Theme.primaryContainer : Theme.alpha(Theme.surfaceContainerHighest, 0.8)
    readonly property color fg: active ? Theme.fgPrimaryContainer : Theme.fgSurface

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fast
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        RowLayout {
            spacing: 6
            MIcon {
                icon: Net.icon
                size: 18
                fill: 1
                color: root.fg
            }
            MIcon {
                visible: Bt.enabled
                icon: Bt.icon
                size: 18
                color: root.fg
            }
            MIcon {
                icon: Audio.icon
                size: 18
                fill: 1
                color: root.fg
            }
            MIcon {
                visible: Audio.micMuted
                icon: "mic_off"
                size: 18
                color: root.fg
            }
            MIcon {
                visible: Ui.caffeine
                icon: "coffee"
                size: 18
                fill: 1
                color: root.fg
            }
            MIcon {
                visible: Battery.present
                icon: Battery.icon
                size: 18
                fill: 1
                color: root.fg
                rotation: 90
            }
        }

        MText {
            visible: Settings.data.showDate
            text: Time.dateShort
            color: root.fg
            size: Theme.type.labelL
            weight: Font.Medium
        }
        MText {
            text: Time.time
            color: root.fg
            size: Theme.type.labelL
            weight: Font.Medium
        }
    }

    StateLayer {
        color: root.fg
        onClicked: Ui.toggle("quicksettings", root.screenName)
        onWheel: event => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
