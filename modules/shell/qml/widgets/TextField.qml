// Поле ввода в виде «таблетки», как строка поиска на Pixel.
import QtQuick
import QtQuick.Layouts
import qs.common

Rectangle {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property color fieldColor: Theme.surfaceContainerHighest
    signal accepted
    signal escapePressed

    implicitHeight: 56
    implicitWidth: 300
    radius: height / 2
    color: fieldColor
    border.width: input.activeFocus && root.radius < 20 ? 2 : 0
    border.color: Theme.primary

    function forceFocus() {
        input.forceActiveFocus();
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.icon ? 16 : 24
        anchors.rightMargin: 16
        spacing: 12

        MIcon {
            visible: root.icon !== ""
            icon: root.icon
            color: Theme.onSurfaceVariant
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.onSurface
                selectionColor: Theme.alpha(Theme.primary, 0.4)
                selectedTextColor: Theme.onSurface
                font.family: Theme.font
                font.pixelSize: Theme.type.bodyL
                echoMode: root.password ? TextInput.Password : TextInput.Normal
                clip: true
                onAccepted: root.accepted()
                Keys.onEscapePressed: root.escapePressed()
            }

            MText {
                anchors.fill: parent
                visible: input.text === ""
                text: root.placeholder
                color: Theme.onSurfaceVariant
                size: Theme.type.bodyL
            }
        }

        MIcon {
            visible: input.text !== "" && !root.password
            icon: "close"
            size: 20
            color: Theme.onSurfaceVariant
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: input.text = ""
            }
        }
    }
}
