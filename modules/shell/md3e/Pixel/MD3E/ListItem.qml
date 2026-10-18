// Пункт настроек: значок, заголовок, подпись и что-нибудь справа
// (переключатель, стрелка, значение). Кладётся в Group.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    readonly property bool groupItem: true
    property bool first: true
    property bool last: true

    property string icon: ""
    // Что-то своё слева вместо значка (например, значок приложения оболочки)
    property Component leading: null
    property bool iconTinted: false
    property color iconBg: Theme.secondaryContainer
    property color iconFg: Theme.fgSecondaryContainer
    property string title
    property string subtitle: ""
    property bool clickable: true
    property bool chevron: false
    property bool selected: false
    property bool disabled: false
    default property alias trailing: trailingRow.data
    signal clicked

    readonly property color cardColor: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest

    Layout.fillWidth: true
    implicitHeight: Math.max(subtitle !== "" ? 72 : 60, row.implicitHeight + 24)
    color: selected ? Theme.secondaryContainer : cardColor
    topLeftRadius: first ? 24 : 4
    topRightRadius: first ? 24 : 4
    bottomLeftRadius: last ? 24 : 4
    bottomRightRadius: last ? 24 : 4
    opacity: disabled ? 0.5 : 1

    onVisibleChanged: parent?.relayout?.()

    Behavior on color {
        ColorAnimation {
            duration: Theme.anim.fast
        }
    }

    StateLayer {
        visible: root.clickable && !root.disabled
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 16

        Loader {
            active: root.leading !== null
            visible: active
            sourceComponent: root.leading
        }

        Rectangle {
            visible: root.icon !== ""
            Layout.preferredWidth: root.iconTinted ? 40 : 24
            Layout.preferredHeight: root.iconTinted ? 40 : 24
            radius: width / 2
            color: root.iconTinted ? root.iconBg : "transparent"
            MIcon {
                anchors.centerIn: parent
                icon: root.icon
                size: 24
                fill: root.selected ? 1 : 0
                color: root.iconTinted ? root.iconFg : (root.selected ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            MText {
                Layout.fillWidth: true
                text: root.title
                size: Theme.type.bodyL
                color: root.selected ? Theme.fgSecondaryContainer : Theme.fgSurface
            }
            MText {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                size: Theme.type.bodyM
                color: root.selected ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                wrapMode: Text.WordWrap
                maximumLineCount: 3
            }
        }

        RowLayout {
            id: trailingRow
            spacing: 12
        }

        MIcon {
            visible: root.chevron
            icon: "chevron_right"
            color: Theme.fgSurfaceVariant
        }
    }
}
