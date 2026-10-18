// Кружок уведомлений: число непрочитанных или значок «Не беспокоить».
import QtQuick
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Rectangle {
    id: root
    property string screenName
    readonly property int count: Notifs.count

    visible: count > 0 || Settings.data.dnd
    implicitWidth: Math.max(34, label.implicitWidth + 20)
    implicitHeight: 34
    radius: height / 2
    color: Settings.data.dnd ? Theme.surfaceContainerHighest : Theme.primaryContainer

    MIcon {
        anchors.centerIn: parent
        visible: Settings.data.dnd
        icon: "do_not_disturb_on"
        size: 20
        fill: 1
        color: Theme.fgSurfaceVariant
    }
    MText {
        id: label
        anchors.centerIn: parent
        visible: !Settings.data.dnd
        text: root.count > 99 ? "99+" : root.count
        color: Theme.fgPrimaryContainer
        size: Theme.type.labelL
        weight: Font.DemiBold
    }

    StateLayer {
        onClicked: Ui.toggle("quicksettings", root.screenName)
    }
}
