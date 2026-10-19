// Значок файла или папки. Папки — свои, в цвете темы (как в «Файлах» на
// Pixel), а не синие из темы значков; у известных папок внутри символ.
// Файлы — значок по типу из темы (Files.iconFor).
import QtQuick
import qs.common
import qs.services
import Pixel.MD3E

Item {
    id: root
    property string name: ""
    property string path: ""
    property bool isDir: false
    property real size: 40

    implicitWidth: size
    implicitHeight: size

    readonly property string home: Settings.home
    readonly property string inner: !isDir ? "" : ({
            [home]: "home",
            [home + "/Desktop"]: "desktop_windows",
            [home + "/Documents"]: "description",
            [home + "/Downloads"]: "download",
            [home + "/Pictures"]: "image",
            [home + "/Music"]: "music_note",
            [home + "/Videos"]: "movie",
            [home + "/Public"]: "public",
            [home + "/Templates"]: "note_stack",
            [home + "/Games"]: "stadia_controller",
            [home + "/AppImages"]: "apps"
        })[path] ?? ""

    MIcon {
        visible: root.isDir
        anchors.centerIn: parent
        icon: "folder"
        fill: 1
        size: root.size * 1.08
        color: Theme.primary
    }
    MIcon {
        visible: root.inner !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.size * 0.06
        icon: root.inner
        fill: 1
        size: root.size * 0.42
        color: Theme.fgPrimary
    }
    AppIcon {
        visible: !root.isDir
        anchors.fill: parent
        styled: false
        icon: Files.iconFor(root.name, root.path, false)
    }
}
