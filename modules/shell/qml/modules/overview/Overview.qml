// Обзор (Super+Tab): воркспейсы экрана сверху «столами», ниже — окна
// выбранного стола живыми миниатюрами. Клик по окну — фокус, по столу —
// переход, колесо/стрелки — листать столы.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.widgets
import qs.services

Overlay {
    id: root
    name: "overview"
    dim: true
    open: Ui.panel === "overview"
    onDismissed: Ui.close()

    readonly property string screenName: Ui.activeScreen
    readonly property var workspaces: Hypr.workspacesFor(screenName)
    property int selected: -1
    readonly property var ws: workspaces.find(w => w.id === selected) ?? Hypr.activeWorkspaceFor(screenName)
    readonly property var windows: ws ? ws.toplevels.values : []

    onOpenChanged: if (open) {
        Hyprland.refreshToplevels();
        selected = Hypr.activeWorkspaceFor(screenName)?.id ?? -1;
        focusItem.forceActiveFocus();
    }

    Item {
        id: focusItem
        anchors.fill: parent
        Keys.onLeftPressed: root.step(-1)
        Keys.onRightPressed: root.step(1)
        Keys.onReturnPressed: {
            Hypr.focusWorkspace(root.selected);
            Ui.close();
        }
    }

    function step(d) {
        const i = workspaces.findIndex(w => w.id === selected);
        const n = workspaces[Math.max(0, Math.min(workspaces.length - 1, i + d))];
        if (n)
            selected = n.id;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        anchors.bottomMargin: 56 + 40
        spacing: 32
        opacity: root.progress
        scale: 0.96 + 0.04 * root.progress

        // Столы
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            Repeater {
                model: root.workspaces
                Rectangle {
                    id: desk
                    required property var modelData
                    readonly property bool sel: modelData.id === root.selected
                    width: 200
                    height: 120
                    radius: Theme.radius.l
                    color: sel ? Theme.primaryContainer : Theme.alpha(Theme.surfaceContainerHigh, 0.9)
                    border.width: modelData.active ? 2 : 0
                    border.color: Theme.primary

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected = desk.modelData.id
                        onDoubleClicked: {
                            Hypr.focusWorkspace(desk.modelData.id);
                            Ui.close();
                        }
                    }

                    Flow {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 6
                        Repeater {
                            model: desk.modelData.toplevels.values.slice(0, 8)
                            AppIcon {
                                required property var modelData
                                size: 28
                                icon: Apps.forWindow(modelData.wayland?.appId ?? modelData.lastIpcObject?.class)?.icon ?? (modelData.wayland?.appId ?? "")
                            }
                        }
                    }
                    MText {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        text: "Стол " + desk.modelData.name
                        size: Theme.type.labelM
                        color: desk.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                    }
                }
            }
        }

        // Окна выбранного стола
        Flow {
            id: flow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            readonly property int count: Math.max(1, root.windows.length)
            readonly property real cols: Math.ceil(Math.sqrt(count))
            readonly property real tileW: Math.min(560, (width - spacing * (cols - 1)) / cols)

            Repeater {
                model: root.windows
                Item {
                    id: win
                    required property var modelData
                    readonly property var tl: modelData.wayland
                    width: flow.tileW
                    height: width * 0.62 + 36

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8
                        RowLayout {
                            spacing: 8
                            AppIcon {
                                size: 22
                                icon: Apps.forWindow(win.tl?.appId)?.icon ?? win.tl?.appId ?? ""
                            }
                            MText {
                                Layout.fillWidth: true
                                text: win.modelData.title
                                color: "white"
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radius.l
                            color: Theme.surfaceContainerHigh
                            border.width: win.modelData.activated ? 3 : 0
                            border.color: Theme.primary
                            clip: true

                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 3
                                captureSource: root.open ? win.tl : null
                                live: true
                                constraintSize: Qt.size(width, height)
                            }
                            StateLayer {
                                color: "white"
                                onClicked: {
                                    win.tl?.activate();
                                    Ui.close();
                                }
                            }
                            IconButton {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                variant: "tonal"
                                icon: "close"
                                onClicked: win.tl?.close()
                            }
                        }
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.step(event.angleDelta.y > 0 ? -1 : 1)
    }
}
