// Один значок трея: ЛКМ — открыть, СКМ — второе действие, ПКМ — меню.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.common
import qs.widgets

Rectangle {
    id: root
    required property var item
    required property var bar
    // окно, относительно которого открывать меню (панель или всплывашка)
    property var menuWindow: bar

    implicitWidth: 34
    implicitHeight: 34
    radius: height / 2
    color: "transparent"

    IconImage {
        anchors.centerIn: parent
        implicitSize: 20
        source: {
            // Telegram и прочие отдают путь вида name?path=…
            const i = root.item.icon;
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
            const it = root.item;
            if (event.button === Qt.LeftButton && !it.onlyMenu)
                it.activate();
            else if (event.button === Qt.MiddleButton)
                it.secondaryActivate();
            else if (it.hasMenu) {
                // меню — со стороны рабочего стола
                const e = Bar.edge;
                const w = root.menuWindow;
                const p = root.mapToItem(w.contentItem, e === "left" ? root.width : 0, e === "top" ? root.height : 0);
                it.display(w, p.x, p.y);
            }
        }
        onWheel: event => root.item.scroll(event.angleDelta.y, false)
    }
}
