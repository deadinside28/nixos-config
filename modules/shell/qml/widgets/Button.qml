// Кнопка M3 с текстом. Варианты: filled | tonal | outlined | text | danger.
import QtQuick
import QtQuick.Layouts
import qs.common

Rectangle {
    id: root

    property string text
    property string icon: ""
    property string variant: "filled"
    property bool disabled: false
    signal clicked

    readonly property color fg: {
        if (disabled)
            return Theme.alpha(Theme.onSurface, 0.38);
        switch (variant) {
        case "filled":
            return Theme.onPrimary;
        case "tonal":
            return Theme.onSecondaryContainer;
        case "danger":
            return Theme.onError;
        default:
            return Theme.primary;
        }
    }

    implicitHeight: 40
    implicitWidth: row.implicitWidth + (variant === "text" ? 24 : 48)
    radius: height / 2
    color: {
        if (variant === "text" || variant === "outlined")
            return "transparent";
        if (disabled)
            return Theme.alpha(Theme.onSurface, 0.12);
        switch (variant) {
        case "filled":
            return Theme.primary;
        case "tonal":
            return Theme.secondaryContainer;
        case "danger":
            return Theme.error;
        }
        return "transparent";
    }
    border.width: variant === "outlined" ? 1 : 0
    border.color: Theme.outline

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        MIcon {
            visible: root.icon !== ""
            icon: root.icon
            size: 18
            color: root.fg
        }
        MText {
            text: root.text
            color: root.fg
            size: Theme.type.labelL
            weight: Font.Medium
        }
    }

    StateLayer {
        color: root.fg
        disabled: root.disabled
        onClicked: root.clicked()
    }
}
