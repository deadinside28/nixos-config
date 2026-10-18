// История буфера обмена (Super+V): поиск, клик — скопировать, ПКМ — удалить.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Overlay {
    id: root
    name: "clipboard"
    open: Ui.panel === "clipboard"
    onDismissed: Ui.close()

    property string query: ""
    property int current: 0
    readonly property var items: Clip.entries.filter(e => e.text.toLowerCase().includes(query.toLowerCase()))

    onOpenChanged: if (open) {
        Clip.refresh();
        search.text = "";
        current = 0;
        search.forceFocus();
    }

    function pick(i) {
        if (i < items.length) {
            Clip.copy(items[i]);
            Ui.close();
        }
    }

    Card {
        width: 560
        height: Math.min(620, root.height - 160)
        x: root.insetLeft + (root.width - root.insetLeft - root.insetRight - width) / 2
        y: (Bar.edge === "top" ? root.insetTop + 12 : Bar.vertical ? (root.height - height) / 2 : root.height - root.insetBottom - 12 - height) + root.slideY((1 - root.progress) * 40)
        opacity: root.progress
        color: Theme.panel

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: search
                    Layout.fillWidth: true
                    icon: "content_paste_search"
                    placeholder: "Поиск в буфере обмена"
                    onTextChanged: {
                        root.query = text;
                        root.current = 0;
                    }
                    onAccepted: root.pick(root.current)
                    onEscapePressed: Ui.close()
                    input.Keys.onDownPressed: root.current = Math.min(root.items.length - 1, root.current + 1)
                    input.Keys.onUpPressed: root.current = Math.max(0, root.current - 1)
                }
                IconButton {
                    implicitWidth: 56
                    implicitHeight: 56
                    variant: "tonal"
                    icon: "delete_sweep"
                    onClicked: Clip.wipe()
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.items
                currentIndex: root.current
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 56
                    radius: Theme.radius.l
                    color: index === root.current ? Theme.secondaryContainer : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 8
                        spacing: 12
                        MIcon {
                            icon: entry.modelData.image ? "image" : "notes"
                            color: Theme.fgSurfaceVariant
                        }
                        MText {
                            Layout.fillWidth: true
                            text: entry.modelData.text.replace(/\s+/g, " ")
                            color: entry.index === root.current ? Theme.fgSecondaryContainer : Theme.fgSurface
                        }
                        IconButton {
                            icon: "close"
                            iconSize: 18
                            onClicked: Clip.remove(entry.modelData)
                        }
                    }
                    StateLayer {
                        anchors.rightMargin: 48
                        onClicked: root.pick(entry.index)
                        onContainsMouseChanged: if (containsMouse)
                            root.current = entry.index
                    }
                }
            }

            MText {
                visible: root.items.length === 0
                Layout.alignment: Qt.AlignHCenter
                text: "Пусто"
                color: Theme.fgSurfaceVariant
            }
        }
    }
}
