// Группа пунктов в стиле Android 16: элементы стоят «стопкой» с зазором
// в 2 px, у крайних большие скругления, у внутренних — маленькие.
// Дети расставляют свои углы сами (см. ListItem.first/last).
import QtQuick
import QtQuick.Layouts
import qs.common

ColumnLayout {
    id: root
    property string title: ""
    default property alias items: column.data

    Layout.fillWidth: true
    spacing: 8

    MText {
        visible: root.title !== ""
        Layout.leftMargin: 20
        Layout.topMargin: 8
        text: root.title
        color: Theme.primary
        size: Theme.type.labelL
        weight: Font.Medium
    }

    ColumnLayout {
        id: column
        Layout.fillWidth: true
        spacing: 2

        // Пересчитать, кто первый и кто последний среди видимых.
        function relayout() {
            const vis = [];
            for (let i = 0; i < children.length; i++) {
                const c = children[i];
                if (c.visible && c.groupItem === true)
                    vis.push(c);
            }
            for (let i = 0; i < vis.length; i++) {
                vis[i].first = i === 0;
                vis[i].last = i === vis.length - 1;
            }
        }
        onChildrenChanged: Qt.callLater(relayout)
        Component.onCompleted: Qt.callLater(relayout)
    }
}
