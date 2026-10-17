// Системный трей (StatusNotifierItem): Steam, Telegram и т.п.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.widgets

RowLayout {
    id: root
    required property var bar
    spacing: 2

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: trayItem
            required property SystemTrayItem modelData
            implicitWidth: 34
            implicitHeight: 34
            radius: height / 2
            color: "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: 20
                source: {
                    // Telegram и прочие отдают путь вида name?path=…
                    const i = trayItem.modelData.icon;
                    if (i.includes("?path=")) {
                        const [name, path] = i.split("?path=");
                        return `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
                    }
                    return i;
                }
            }

            StateLayer {
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    const item = trayItem.modelData;
                    if (event.button === Qt.LeftButton && !item.onlyMenu)
                        item.activate();
                    else if (event.button === Qt.MiddleButton)
                        item.secondaryActivate();
                    else if (item.hasMenu) {
                        const p = trayItem.mapToItem(root.bar.contentItem, 0, 0);
                        item.display(root.bar, p.x, p.y - 4);
                    }
                }
                onWheel: event => trayItem.modelData.scroll(event.angleDelta.y, false)
            }
        }
    }
}
