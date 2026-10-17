// Всплывающие уведомления: стопкой справа внизу, над панелью задач,
// на экране с фокусом. Наведение мыши ставит таймер на паузу.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Ui.focusedScreen) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0 && !Ui.locked && Ui.panel === ""
    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: 12
        right: 12
    }
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pixel-shell:notifications"

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: Notifs.popups.slice().reverse()
            }

            NotificationCard {
                id: card
                required property var modelData
                Layout.fillWidth: true
                notification: modelData
                popup: true
                cardColor: Theme.surfaceContainer
                onClosed: Notifs.dismiss(modelData)

                opacity: 0
                scale: 0.9
                Component.onCompleted: {
                    opacity = 1;
                    scale = 1;
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim.normal
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.anim.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.anim.expressiveSpatial
                    }
                }

                HoverHandler {
                    id: hover
                }
                Timer {
                    interval: Notifs.timeout(card.modelData)
                    running: interval > 0 && !hover.hovered
                    onTriggered: Notifs.dismissPopup(card.modelData)
                }
            }
        }
    }
}
