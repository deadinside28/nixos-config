// Контекстное меню приложения на панели задач.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.widgets
import qs.services

PopupWindow {
    id: root
    required property var item
    required property Item anchorItem
    required property var bar

    readonly property var entry: item.entry
    readonly property bool pinned: entry ? Settings.data.pinnedApps.includes(entry.id) : false

    anchor.window: bar
    anchor.item: anchorItem
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.margins.top: -6
    implicitWidth: 260
    implicitHeight: col.implicitHeight + 16
    color: "transparent"
    visible: false

    function show() {
        visible = true;
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.visible
        onCleared: root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.l
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.6)

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 8
            spacing: 0

            RowLayout {
                Layout.margins: 8
                spacing: 12
                AppIcon {
                    size: 28
                    icon: root.entry?.icon ?? root.item.appId ?? ""
                }
                MText {
                    Layout.fillWidth: true
                    text: root.entry?.name ?? root.item.appId ?? ""
                    size: Theme.type.titleS
                    weight: Font.Medium
                }
            }

            Repeater {
                model: root.entry?.actions ?? []
                MenuRow {
                    required property var modelData
                    icon: "arrow_outward"
                    text: modelData.name
                    onClicked: {
                        Apps.run(modelData.command);
                        root.visible = false;
                    }
                }
            }

            MenuRow {
                visible: root.entry !== null
                icon: "add"
                text: "Новое окно"
                onClicked: {
                    Apps.launch(root.entry);
                    root.visible = false;
                }
            }
            MenuRow {
                visible: root.entry !== null
                icon: root.pinned ? "keep_off" : "keep"
                text: root.pinned ? "Открепить" : "Закрепить на панели"
                onClicked: {
                    root.pinned ? Settings.unpin(root.entry.id) : Settings.pin(root.entry.id);
                    root.visible = false;
                }
            }
            MenuRow {
                visible: root.item.windows.length > 0
                icon: "close"
                text: root.item.windows.length > 1 ? "Закрыть все окна" : "Закрыть"
                onClicked: {
                    for (const w of root.item.windows)
                        w.close();
                    root.visible = false;
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: mrow
        property string icon
        property string text
        signal clicked
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.radius.m
        color: "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            MIcon {
                icon: mrow.icon
                size: 20
                color: Theme.fgSurfaceVariant
            }
            MText {
                Layout.fillWidth: true
                text: mrow.text
            }
        }
        StateLayer {
            onClicked: mrow.clicked()
        }
    }
}
