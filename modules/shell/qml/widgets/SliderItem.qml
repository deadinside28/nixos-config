// Пункт со слайдером под заголовком.
import QtQuick
import QtQuick.Layouts
import qs.common

Rectangle {
    id: root

    readonly property bool groupItem: true
    property bool first: true
    property bool last: true

    property string icon: ""
    property string title
    property string valueText: ""
    property alias from: slider.from
    property alias to: slider.to
    property alias value: slider.value
    property alias stepSize: slider.stepSize
    property alias disabled: slider.disabled
    signal moved(real value)

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 28
    color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
    topLeftRadius: first ? 24 : 4
    topRightRadius: first ? 24 : 4
    bottomLeftRadius: last ? 24 : 4
    bottomRightRadius: last ? 24 : 4
    onVisibleChanged: parent?.relayout?.()

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 4

        RowLayout {
            spacing: 16
            MIcon {
                visible: root.icon !== ""
                icon: root.icon
                color: Theme.fgSurfaceVariant
            }
            MText {
                Layout.fillWidth: true
                text: root.title
                size: Theme.type.bodyL
            }
            MText {
                text: root.valueText
                color: Theme.fgSurfaceVariant
            }
        }
        MSlider {
            id: slider
            Layout.fillWidth: true
            onMoved: v => root.moved(v)
        }
    }
}
