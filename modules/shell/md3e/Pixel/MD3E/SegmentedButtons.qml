// Группа связанных кнопок M3 Expressive: выбранная — залитая и скруглённая
// сильнее, остальные — тональные.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    // [{ value, label, icon? }]
    property var options: []
    property var current
    signal selected(var value)

    spacing: 2

    Repeater {
        model: root.options

        Rectangle {
            id: seg
            required property var modelData
            required property int index
            readonly property bool active: modelData.value === root.current
            readonly property bool isFirst: index === 0
            readonly property bool isLast: index === root.options.length - 1

            Layout.fillWidth: true
            implicitHeight: 40
            implicitWidth: segRow.implicitWidth + 32
            color: active ? Theme.primary : Theme.secondaryContainer
            readonly property real outer: active ? height / 2 : 20
            readonly property real inner: active ? height / 2 : 6
            topLeftRadius: isFirst ? outer : inner
            bottomLeftRadius: isFirst ? outer : inner
            topRightRadius: isLast ? outer : inner
            bottomRightRadius: isLast ? outer : inner

            Behavior on color {
                ColorAnimation {
                    duration: Theme.anim.fast
                }
            }

            RowLayout {
                id: segRow
                anchors.centerIn: parent
                spacing: 6
                MIcon {
                    visible: !!seg.modelData.icon || seg.active
                    icon: seg.modelData.icon ?? "check"
                    size: 18
                    color: seg.active ? Theme.fgPrimary : Theme.fgSecondaryContainer
                }
                MText {
                    text: seg.modelData.label
                    size: Theme.type.labelL
                    weight: Theme.strongWeight
                    color: seg.active ? Theme.fgPrimary : Theme.fgSecondaryContainer
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(seg.modelData.value)
            }
        }
    }
}
