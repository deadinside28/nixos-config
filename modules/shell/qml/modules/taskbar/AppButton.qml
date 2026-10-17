// Значок приложения на панели: точка-индикатор снизу (шире — если окно
// в фокусе), клик запускает или переключает окна, ПКМ — меню.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.widgets
import qs.services

Item {
    id: root
    required property var item
    required property var bar

    readonly property var windows: item.windows
    readonly property bool running: windows.length > 0
    readonly property bool focused: windows.some(w => w.activated)
    readonly property string name: item.entry?.name ?? item.appId ?? ""

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        id: bg
        anchors.centerIn: parent
        width: 44
        height: 44
        radius: Theme.radius.m
        color: root.focused ? Theme.alpha(Theme.fgSurface, 0.08) : "transparent"

        StateLayer {
            id: state
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: event => {
                if (event.button === Qt.RightButton)
                    menu.show();
                else if (event.button === Qt.MiddleButton)
                    root.launch();
                else
                    root.activate();
            }
        }
    }

    AppIcon {
        id: icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        size: 32
        icon: root.item.entry?.icon ?? root.item.appId ?? ""
        scale: state.pressed ? 0.88 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    // индикатор запущенного окна
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        height: 4
        radius: 2
        width: root.focused ? 16 : (root.running ? 6 : 0)
        opacity: root.running ? 1 : 0
        color: root.focused ? Theme.primary : Theme.fgSurfaceVariant
        Behavior on width {
            NumberAnimation {
                duration: Theme.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.anim.expressiveSpatial
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.fast
            }
        }
    }

    Tooltip {
        target: root
        bar: root.bar
        text: root.name
        shown: state.containsMouse && !menu.visible
    }

    AppMenu {
        id: menu
        item: root.item
        anchorItem: root
        bar: root.bar
    }

    function launch() {
        if (item.entry)
            Apps.launch(item.entry);
    }

    function activate() {
        if (!running) {
            launch();
            return;
        }
        // Несколько окон — по кругу, начиная со следующего за активным.
        const i = windows.findIndex(w => w.activated);
        const next = windows[(i + 1) % windows.length];
        next.activate();
    }
}
