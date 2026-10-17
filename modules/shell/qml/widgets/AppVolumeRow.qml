// Строка микшера: значок и имя приложения, слайдер, процент, «без звука».
// Как микшер громкости в Windows, только в Material 3.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.services

RowLayout {
    id: root
    required property var app
    property bool compact: false

    spacing: compact ? 12 : 16

    Item {
        Layout.preferredWidth: root.compact ? 32 : 40
        Layout.preferredHeight: root.compact ? 32 : 40
        AppIcon {
            anchors.fill: parent
            icon: root.app.icon
            opacity: root.app.muted ? 0.4 : 1
        }
        Rectangle {
            visible: root.app.nodes.length > 1
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -4
            width: 18
            height: 18
            radius: 9
            color: Theme.secondaryContainer
            MText {
                anchors.centerIn: parent
                text: root.app.nodes.length
                size: Theme.type.labelS
                color: Theme.fgSecondaryContainer
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            MText {
                Layout.fillWidth: true
                text: root.app.name
                size: root.compact ? Theme.type.bodyM : Theme.type.bodyL
            }
            MText {
                text: root.app.muted ? "Без звука" : Math.round(root.app.volume * 100) + "%"
                color: Theme.fgSurfaceVariant
                size: Theme.type.bodyS
            }
        }
        MSlider {
            Layout.fillWidth: true
            implicitHeight: root.compact ? 32 : 44
            value: root.app.volume
            disabled: root.app.muted
            onMoved: v => Audio.setAppVolume(root.app, v)
        }
    }

    IconButton {
        icon: root.app.muted ? "volume_off" : "volume_up"
        variant: root.app.muted ? "tonal" : "standard"
        onClicked: Audio.toggleAppMute(root.app)
    }
}
