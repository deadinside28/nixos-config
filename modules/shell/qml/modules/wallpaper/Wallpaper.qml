// Обои на фоновом слое каждого экрана, со сменой через плавный переход.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

PanelWindow {
    id: root
    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "pixel-shell:wallpaper"
    color: Theme.surfaceDim

    // Под живыми обоями Wallpaper Engine (они на слое bottom, выше) лежит
    // их превью — его видно, пока linux-wallpaperengine запускается.
    readonly property string source: Wallpapers.image

    property Image current: a
    onSourceChanged: {
        const next = current === a ? b : a;
        next.source = source ? "file://" + source : "";
    }

    Image {
        id: a
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        opacity: root.current === a ? 1 : 0
        onStatusChanged: if (status === Image.Ready && root.current !== a)
            root.current = a
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.extraSlow
                easing.type: Easing.InOutQuad
            }
        }
    }
    Image {
        id: b
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        opacity: root.current === b ? 1 : 0
        onStatusChanged: if (status === Image.Ready && root.current !== b)
            root.current = b
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.extraSlow
                easing.type: Easing.InOutQuad
            }
        }
    }

    Component.onCompleted: a.source = source ? "file://" + source : ""
}
