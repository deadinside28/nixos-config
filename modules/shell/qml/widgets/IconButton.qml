// Кнопка-значок M3. Варианты: standard | filled | tonal | outlined.
import QtQuick
import qs.common

Rectangle {
    id: root

    property string icon
    property string variant: "standard"
    property bool toggled: false
    property real iconSize: 24
    property color iconColor: {
        switch (variant) {
        case "filled":
            return toggled || !checkable ? Theme.onPrimary : Theme.primary;
        case "tonal":
            return toggled || !checkable ? Theme.onSecondaryContainer : Theme.onSurfaceVariant;
        default:
            return toggled ? Theme.primary : Theme.onSurfaceVariant;
        }
    }
    property bool checkable: false
    property string tooltip: ""
    signal clicked
    signal rightClicked

    implicitWidth: 40
    implicitHeight: 40
    radius: toggled && checkable ? Theme.radius.m : height / 2
    color: {
        switch (variant) {
        case "filled":
            return toggled || !checkable ? Theme.primary : Theme.surfaceContainerHighest;
        case "tonal":
            return toggled || !checkable ? Theme.secondaryContainer : Theme.surfaceContainerHighest;
        default:
            return "transparent";
        }
    }
    border.width: variant === "outlined" ? 1 : 0
    border.color: Theme.outlineVariant

    Behavior on radius {
        NumberAnimation {
            duration: Theme.anim.normal
            easing.type: Easing.OutBack
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fast
        }
    }

    MIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.iconColor
        fill: root.toggled ? 1 : 0
    }

    StateLayer {
        color: root.iconColor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
