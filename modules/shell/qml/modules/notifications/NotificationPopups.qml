// Всплывающие уведомления: стопкой справа внизу, над панелью задач,
// на экране с фокусом. Наведение мыши ставит таймер на паузу.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services
import Pixel.MD3E

// Элемент окна-хоста экрана (modules/frame/ScreenHost.qml), а не своё
// окно: хост пропускает мышь только в область карточек.
Item {
    id: root

    // Монитор и угол — «Настройки → Уведомления»
    readonly property string screenName: Settings.data.notifScreen === "focused" ? Ui.focusedScreen : Settings.data.notifScreen === "primary" ? (Quickshell.screens[0]?.name ?? "") : Settings.data.notifScreen
    readonly property string pos: Settings.data.notifPosition !== "auto" ? Settings.data.notifPosition : (Bar.edge === "top" ? "top-" : "bottom-") + (Bar.edge === "left" ? "left" : "right")
    readonly property bool atTop: pos.startsWith("top")
    readonly property bool showUpdate: !SystemConfig.popupHidden && !SystemConfig.cardDismissed && !Ui.updateWindowOpen
    readonly property bool hostShown: (Notifs.popups.length > 0 || showUpdate) && !Ui.locked && Ui.panel === ""
    readonly property bool takesInput: true
    // экран, которого нет (монитор отключили), — первый
    readonly property string hostScreen: Hosts.items[screenName] ? screenName : (Quickshell.screens[0]?.name ?? "")
    parent: hostShown ? Hosts.items[hostScreen] ?? null : null
    visible: hostShown
    z: 2
    width: 400
    height: Math.max(1, column.implicitHeight)
    // угол со стороны «таблетки» статуса, место под панелью задач — сбоку
    x: pos.endsWith("left") ? Bar.inset(hostScreen, "left") + 12 : (parent?.width ?? 0) - Bar.inset(hostScreen, "right") - 12 - width
    y: atTop ? Bar.inset(hostScreen, "top") + 12 : (parent?.height ?? 0) - Bar.inset(hostScreen, "bottom") - 12 - height
    Component.onCompleted: Hosts.addFloater(root)
    Component.onDestruction: Hosts.removeFloater(root)

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 8

        // Прогресс обновления системы — у края экрана, над обычными
        UpdateCard {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            visible: root.showUpdate && root.atTop
            cardColor: Theme.surfaceContainer
        }

        Repeater {
            model: ScriptModel {
                // новые — ближе к краю экрана
                values: root.atTop ? Notifs.popups : Notifs.popups.slice().reverse()
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

        UpdateCard {
            Layout.fillWidth: true
            visible: root.showUpdate && !root.atTop
            cardColor: Theme.surfaceContainer
        }
    }
}
