// «Таблетка» статуса: раскладка, сеть, Bluetooth, звук, батарея, часы и
// дата. Клик — быстрые настройки, колесо — громкость, клик по раскладке —
// следующая раскладка. На боковой панели всё встаёт столбиком.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Rectangle {
    id: root
    property string screenName
    property bool vertical: false
    readonly property bool active: Ui.panel === "quicksettings"

    implicitHeight: vertical ? col.implicitHeight + 24 : 40
    implicitWidth: vertical ? 44 : col.implicitWidth + 28
    radius: vertical ? 22 : height / 2
    color: active ? Theme.primaryContainer : Theme.alpha(Theme.surfaceContainerHighest, 0.8)
    readonly property color fg: active ? Theme.fgPrimaryContainer : Theme.fgSurface

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fast
        }
    }

    StateLayer {
        color: root.fg
        onClicked: Ui.toggle("quicksettings", root.screenName)
        onWheel: event => Audio.setVolume(Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
    }

    GridLayout {
        id: col
        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 8
        columnSpacing: 10

        // Раскладка: свой клик — переключить
        Rectangle {
            visible: Settings.data.showKeyboardLayout && Keyboard.code !== ""
            Layout.alignment: Qt.AlignCenter
            implicitWidth: kb.implicitWidth + 12
            implicitHeight: 24
            radius: Theme.radius.s
            color: Theme.alpha(root.fg, 0.12)
            MText {
                id: kb
                anchors.centerIn: parent
                text: Keyboard.code
                color: root.fg
                size: Theme.type.labelM
                weight: Font.Bold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Keyboard.next()
            }
        }

        GridLayout {
            Layout.alignment: Qt.AlignCenter
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 6
            columnSpacing: 6
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
            visible: Settings.data.showDate && !root.vertical
            text: Time.dateShort
            color: root.fg
            size: Theme.type.labelL
            weight: Theme.strongWeight
        }
        MText {
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            // на боковой панели часы и минуты — друг под другом
            text: root.vertical ? Time.time.replace(":", "\n").replace(/ (AM|PM)$/, "") : Time.time
            color: root.fg
            size: Theme.type.labelL
            weight: Theme.strongWeight
            lineHeight: 0.9
        }
    }
}
