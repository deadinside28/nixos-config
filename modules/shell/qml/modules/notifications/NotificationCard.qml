// Карточка уведомления M3: значок приложения, заголовок, текст, картинка,
// кнопки действий, быстрый ответ. Смахивается вбок.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Item {
    id: root
    required property var notification
    property bool popup: false
    property color cardColor: Theme.surfaceContainerHigh
    signal closed

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    property bool expanded: false

    implicitHeight: card.implicitHeight
    clip: false

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: col.implicitHeight + 32
        radius: Theme.radius.xl
        color: root.critical ? Theme.errorContainer : root.cardColor
        opacity: 1 - Math.min(1, Math.abs(x) / width) * 0.8

        Behavior on x {
            enabled: !drag.active
            NumberAnimation {
                duration: Theme.anim.normal
                easing.type: Easing.OutCubic
            }
        }

        DragHandler {
            id: drag
            yAxis.enabled: false
            onActiveChanged: {
                if (!active) {
                    if (Math.abs(card.x) > card.width * 0.35)
                        root.closed();
                    else
                        card.x = 0;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.MiddleButton) {
                    root.closed();
                    return;
                }
                const def = root.notification.actions.find(a => a.identifier === "default");
                if (def) {
                    def.invoke();
                    root.closed();
                } else {
                    root.expanded = !root.expanded;
                }
            }
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignTop

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 20
                        visible: root.notification.image !== ""
                        color: "transparent"
                        Image {
                            anchors.fill: parent
                            source: root.notification.image
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        visible: root.notification.image === ""
                        color: root.critical ? Theme.error : Theme.primaryContainer
                        AppIcon {
                            anchors.centerIn: parent
                            size: 24
                            icon: Notifs.icon(root.notification)
                            visible: icon !== ""
                        }
                        MIcon {
                            anchors.centerIn: parent
                            visible: Notifs.icon(root.notification) === ""
                            icon: root.critical ? "priority_high" : "notifications"
                            fill: 1
                            color: root.critical ? Theme.fgError : Theme.fgPrimaryContainer
                        }
                    }
                    // маленький значок приложения поверх картинки
                    AppIcon {
                        visible: root.notification.image !== "" && !root.notification.image.startsWith("image://icon/") && Notifs.icon(root.notification) !== ""
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: -2
                        size: 18
                        icon: Notifs.icon(root.notification)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MText {
                            text: root.notification.appName || "Уведомление"
                            size: Theme.type.labelM
                            color: root.critical ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }
                    MText {
                        Layout.fillWidth: true
                        text: root.notification.summary
                        size: Theme.type.titleS
                        weight: Theme.strongWeight
                        color: root.critical ? Theme.fgErrorContainer : Theme.fgSurface
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    MText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: root.notification.body
                        textFormat: Text.StyledText
                        size: Theme.type.bodyM
                        color: root.critical ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                        wrapMode: Text.Wrap
                        maximumLineCount: root.expanded ? 12 : 3
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }

                IconButton {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 32
                    implicitHeight: 32
                    iconSize: 18
                    icon: "close"
                    onClicked: root.closed()
                }
            }

            // Действия
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 52
                spacing: 8
                visible: actions.count > 0
                Repeater {
                    id: actions
                    model: root.notification.actions.filter(a => a.identifier !== "default" && a.text)
                    Button {
                        required property var modelData
                        variant: "tonal"
                        implicitHeight: 34
                        text: modelData.text
                        onClicked: {
                            modelData.invoke();
                            root.closed();
                        }
                    }
                }
            }

            // Быстрый ответ (Telegram и т.п.)
            TextField {
                id: reply
                Layout.fillWidth: true
                Layout.leftMargin: 52
                visible: root.notification.hasInlineReply
                implicitHeight: 44
                icon: "reply"
                placeholder: root.notification.inlineReplyPlaceholder || "Ответить"
                onAccepted: {
                    if (text.trim() !== "") {
                        root.notification.sendInlineReply(text);
                        root.closed();
                    }
                }
            }
        }
    }
}
