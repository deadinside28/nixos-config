// Плитка приложения в сетке лаунчера. ПКМ — закрепить/открепить на панели.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets

Item {
    id: root
    required property var app
    property bool highlighted: false
    signal launch

    implicitHeight: 108
    readonly property bool pinned: Settings.data.pinnedApps.includes(app.id)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.radius.l
        color: root.highlighted ? Theme.secondaryContainer : "transparent"

        StateLayer {
            id: state
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => {
                if (event.button === Qt.RightButton)
                    root.pinned ? Settings.unpin(root.app.id) : Settings.pin(root.app.id);
                else
                    root.launch();
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 8

            AppIcon {
                Layout.alignment: Qt.AlignHCenter
                size: 48
                icon: root.app.icon
                scale: state.pressed ? 0.9 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.anim.fast
                        easing.type: Easing.OutBack
                    }
                }

                MIcon {
                    visible: root.pinned
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -4
                    icon: "keep"
                    size: 16
                    fill: 1
                    color: Theme.primary
                }
            }
            MText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.app.name
                size: Theme.type.bodyS
                color: root.highlighted ? Theme.onSecondaryContainer : Theme.onSurface
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }
    }
}
