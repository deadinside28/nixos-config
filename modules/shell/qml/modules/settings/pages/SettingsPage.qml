// Каркас страницы: крупный заголовок, прокрутка, колонка шириной до 780 px.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import Pixel.MD3E

Flickable {
    id: root

    property string title
    property string description: ""
    default property alias content: column.data
    property alias header: headerSlot.data

    contentWidth: width
    contentHeight: column.implicitHeight + 160
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    ColumnLayout {
        id: column
        width: Math.min(780, root.width - 64)
        x: (root.width - width) / 2
        y: 40
        spacing: 24

        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 8
            MText {
                Layout.fillWidth: true
                text: root.title
                size: Theme.type.displayS
                weight: Font.Normal
            }
            MText {
                Layout.fillWidth: true
                visible: root.description !== ""
                text: root.description
                color: Theme.fgSurfaceVariant
                size: Theme.type.bodyL
                wrapMode: Text.WordWrap
            }
            Item {
                id: headerSlot
                Layout.fillWidth: true
                implicitHeight: childrenRect.height
                visible: children.length > 0
            }
        }
    }

    // Колесо мыши — быстрее и плавнее, чем по умолчанию
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: event => {
            root.contentY = Math.max(0, Math.min(root.contentHeight - root.height, root.contentY - event.angleDelta.y * 1.2));
        }
    }
}
