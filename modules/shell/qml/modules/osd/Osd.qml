// Индикатор громкости (и яркости) при изменении — таблетка над панелью
// задач по центру экрана с фокусом, как в Aluminium OS.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

PanelWindow {
    id: root

    property string kind: "volume"
    property bool shown: false
    property bool ready: false

    screen: Quickshell.screens.find(s => s.name === Ui.focusedScreen) ?? Quickshell.screens[0]
    visible: shown || pill.opacity > 0
    anchors.bottom: Bar.edge !== "top"
    anchors.top: Bar.edge === "top"
    margins.bottom: 24
    margins.top: 24
    exclusionMode: ExclusionMode.Normal
    implicitWidth: 340
    implicitHeight: 64
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pixel-shell:osd"
    // OSD не должен перехватывать мышь
    mask: Region {}

    function show(k) {
        if (!ready || Ui.locked || Ui.panel === "quicksettings")
            return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }
    // не показывать OSD на значениях, пришедших при старте
    Timer {
        running: true
        interval: 1500
        onTriggered: root.ready = true
    }

    // Смена устройства вывода (подключились наушники) меняет громкость и
    // mute сама по себе — это не повод показывать индикатор
    Timer {
        id: sinkSwitch
        interval: 600
    }
    Connections {
        target: Audio
        function onSinkChanged() {
            sinkSwitch.restart();
        }
        function onVolumeChanged() {
            if (!sinkSwitch.running)
                root.show("volume");
        }
        function onMutedChanged() {
            if (!sinkSwitch.running)
                root.show("volume");
        }
    }
    Connections {
        target: Brightness
        function onChangedByUser() {
            root.show("brightness");
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceContainerHigh
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.9
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.anim.normal
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.anim.normal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.anim.expressiveSpatial
            }
        }

        readonly property real value: root.kind === "volume" ? Audio.volume : Brightness.value

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 24
            spacing: 16
            MIcon {
                icon: root.kind === "volume" ? Audio.icon : "brightness_6"
                fill: 1
                color: Theme.primary
            }
            Rectangle {
                Layout.fillWidth: true
                height: 8
                radius: 4
                color: Theme.secondaryContainer
                Rectangle {
                    height: parent.height
                    radius: 4
                    width: parent.width * Math.min(1, pill.value)
                    color: root.kind === "volume" && Audio.muted ? Theme.outline : Theme.primary
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.anim.fast
                        }
                    }
                }
            }
            MText {
                Layout.preferredWidth: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(pill.value * 100)
                size: Theme.type.labelL
                weight: Theme.strongWeight
            }
        }
    }
}
