// Поверхность панели: скруглённая, с мягкой тенью M3.
import QtQuick
import QtQuick.Effects
import qs.common

Item {
    id: root
    property color color: Theme.surfaceContainer
    property real radius: Theme.radius.xl
    property bool shadow: true
    default property alias content: inner.data

    // клики внутри карточки не должны закрывать оверлей
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: event => event.accepted = true
    }

    RectangularShadow {
        anchors.fill: bg
        visible: root.shadow
        radius: bg.radius
        blur: 24
        spread: 0
        offset.y: 6
        color: Theme.alpha(Theme.shadow, Theme.dark ? 0.5 : 0.22)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.color
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
