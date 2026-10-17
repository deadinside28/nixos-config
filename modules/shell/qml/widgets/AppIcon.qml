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

    // Не нашлось в теме — пробуем варианты имени: org.gnome.Nautilus →
    // nautilus, Google-chrome → google-chrome и т.п.
    readonly property string src: {
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.startsWith("file:") || icon.startsWith("image:"))
            return icon;
        const tail = icon.split(".").pop();
        const names = [icon, icon.toLowerCase(), tail, tail.toLowerCase(), icon.toLowerCase().replace(/[ _]/g, "-")];
        for (const n of names) {
            const p = Quickshell.iconPath(n, true);
            if (p)
                return p;
        }
        return "";
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
