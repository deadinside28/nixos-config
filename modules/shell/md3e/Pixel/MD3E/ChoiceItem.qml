// Пункт-выбор: показывает текущее значение, по клику раскрывается списком
// вариантов с радиокнопками прямо внутри группы (как диалог выбора на Pixel,
// только без диалога).
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    readonly property bool groupItem: true
    property bool first: true
    property bool last: true

    property string icon: ""
    property string title
    // [{ value, label, sublabel? }] или массив строк
    property var options: []
    property var current
    property bool expanded: false
    property int maxVisible: 8
    signal selected(var value)

    readonly property var opts: options.map(o => typeof o === "object" ? o : {
                value: o,
                label: String(o)
            })
    readonly property var currentOpt: opts.find(o => o.value === current)

    Layout.fillWidth: true
    implicitHeight: header.height + (expanded ? list.height + 8 : 0)
    color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
    topLeftRadius: first ? 24 : 4
    topRightRadius: first ? 24 : 4
    bottomLeftRadius: last ? 24 : 4
    bottomRightRadius: last ? 24 : 4
    clip: true
    onVisibleChanged: parent?.relayout?.()

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.anim.emphasizedDecel
        }
    }

    Item {
        id: header
        width: parent.width
        height: 72

        StateLayer {
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomLeftRadius: root.expanded ? 0 : root.bottomLeftRadius
            bottomRightRadius: root.expanded ? 0 : root.bottomRightRadius
            onClicked: root.expanded = !root.expanded
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 16
            MIcon {
                visible: root.icon !== ""
                icon: root.icon
                color: Theme.fgSurfaceVariant
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                MText {
                    Layout.fillWidth: true
                    text: root.title
                    size: Theme.type.bodyL
                }
                MText {
                    Layout.fillWidth: true
                    text: root.currentOpt?.label ?? (root.current !== undefined && root.current !== "" ? String(root.current) : "Не выбрано")
                    color: Theme.primary
                }
            }
            MIcon {
                icon: "expand_more"
                color: Theme.fgSurfaceVariant
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.anim.normal
                    }
                }
            }
        }
    }

    ListView {
        id: list
        anchors.top: header.bottom
        x: 8
        width: parent.width - 16
        height: Math.min(contentHeight, root.maxVisible * 52)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: root.expanded ? root.opts : []

        delegate: Rectangle {
            id: opt
            required property var modelData
            readonly property bool sel: modelData.value === root.current
            width: list.width
            height: 52
            radius: Theme.radius.l
            color: sel ? Theme.alpha(Theme.primary, 0.12) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: "transparent"
                    border.width: 2
                    border.color: opt.sel ? Theme.primary : Theme.fgSurfaceVariant
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: Theme.primary
                        visible: opt.sel
                    }
                }
                MText {
                    Layout.fillWidth: true
                    text: opt.modelData.label
                    size: Theme.type.bodyL
                }
                MText {
                    visible: !!opt.modelData.sublabel
                    text: opt.modelData.sublabel ?? ""
                    color: Theme.fgSurfaceVariant
                }
            }
            StateLayer {
                onClicked: {
                    root.selected(opt.modelData.value);
                    root.expanded = false;
                }
            }
        }
    }
}
