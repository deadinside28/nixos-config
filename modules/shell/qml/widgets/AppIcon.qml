// Значок приложения из темы иконок с запасным вариантом.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common

Item {
    id: root
    property string icon: ""
    property real size: 40

    implicitWidth: size
    implicitHeight: size

    readonly property string src: {
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.startsWith("file:") || icon.startsWith("image:"))
            return icon;
        return Quickshell.iconPath(icon, true);
    }

    IconImage {
        id: img
        anchors.fill: parent
        source: root.src
        visible: root.src !== "" && status !== Image.Error
        asynchronous: true
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !img.visible
        radius: width / 2
        color: Theme.primaryContainer
        MIcon {
            anchors.centerIn: parent
            icon: "apps"
            size: root.size * 0.55
            color: Theme.fgPrimaryContainer
        }
    }
}
