// «Начать запись?» как на Pixel: что записывать (весь экран, область,
// окно), звук — и кнопка «Начать». Последний выбор запоминается, его же
// берёт быстрый запуск по Alt+F10.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Overlay {
    id: root
    name: "record"
    dim: true
    open: Ui.panel === "record"
    onDismissed: Ui.close()

    // монитор: тот, где открыта панель
    property string monitor: Ui.activeScreen
    onOpenChanged: if (open)
        monitor = Ui.activeScreen

    function start() {
        const d = Settings.data;
        const area = d.recArea === "screen" ? "screen:" + root.monitor : d.recArea;
        Ui.close();
        // дать панели исчезнуть, чтобы она не попала в кадр и не мешала slurp
        Quickshell.execDetached(["sh", "-c", 'sleep 0.45; exec pixel-record "$1" "$2"', "sh", area, d.recAudio]);
    }

    Card {
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 56
        scale: 0.92 + 0.08 * root.progress
        opacity: root.progress
        color: Theme.panel

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 28
            spacing: 18

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 56
                implicitHeight: 56
                radius: 28
                color: Theme.primaryContainer
                MIcon {
                    anchors.centerIn: parent
                    icon: "screen_record"
                    fill: 1
                    color: Theme.fgPrimaryContainer
                }
            }
            MText {
                Layout.alignment: Qt.AlignHCenter
                text: "Начать запись?"
                size: Theme.type.headlineS
            }

            Section {
                text: "Что записывать"
            }
            Choice {
                options: [
                    {
                        value: "screen",
                        icon: "desktop_windows",
                        label: "Весь экран",
                        sub: Quickshell.screens.length > 1 ? root.monitor : "Всё, что на экране"
                    },
                    {
                        value: "area",
                        icon: "screenshot_region",
                        label: "Область",
                        sub: "Выделишь мышью после нажатия «Начать»"
                    },
                    {
                        value: "window",
                        icon: "web_asset",
                        label: "Окно",
                        sub: "Активное окно"
                    }
                ]
                current: Settings.data.recArea
                onSelected: v => Settings.data.recArea = v
            }
            // Какой монитор, если их несколько
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: 52
                visible: Settings.data.recArea === "screen" && Quickshell.screens.length > 1
                spacing: 8
                Repeater {
                    model: Quickshell.screens
                    Rectangle {
                        id: mc
                        required property var modelData
                        readonly property bool on: root.monitor === modelData.name
                        implicitHeight: 32
                        implicitWidth: mt.implicitWidth + 24
                        radius: Theme.radius.s
                        color: on ? Theme.secondaryContainer : "transparent"
                        border.width: on ? 0 : 1
                        border.color: Theme.outlineVariant
                        MText {
                            id: mt
                            anchors.centerIn: parent
                            text: mc.modelData.name
                            size: Theme.type.labelL
                            color: mc.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                        StateLayer {
                            radius: mc.radius
                            onClicked: root.monitor = mc.modelData.name
                        }
                    }
                }
            }

            Section {
                text: "Звук"
            }
            SegmentedButtons {
                Layout.fillWidth: true
                options: [
                    {
                        value: "none",
                        label: "Без звука",
                        icon: "volume_off"
                    },
                    {
                        value: "system",
                        label: "Системный",
                        icon: "volume_up"
                    },
                    {
                        value: "mic",
                        label: "+ микрофон",
                        icon: "mic"
                    }
                ]
                current: Settings.data.recAudio
                onSelected: v => Settings.data.recAudio = v
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Button {
                    variant: "text"
                    icon: "settings"
                    text: "Качество"
                    onClicked: Ui.openSettings("display")
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    variant: "text"
                    text: "Отмена"
                    onClicked: Ui.close()
                }
                Button {
                    icon: "fiber_manual_record"
                    text: "Начать"
                    onClicked: root.start()
                }
            }
        }
        Keys.onReturnPressed: root.start()
    }

    component Section: MText {
        size: Theme.type.labelL
        weight: Theme.strongWeight
        color: Theme.primary
        Layout.bottomMargin: -8
    }
    component Choice: ColumnLayout {
        id: ch
        property var options: []
        property string current
        signal selected(string value)
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: ch.options
            Rectangle {
                id: opt
                required property var modelData
                readonly property bool on: ch.current === modelData.value
                Layout.fillWidth: true
                implicitHeight: 60
                radius: 30
                color: on ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 16
                    MIcon {
                        icon: opt.modelData.icon
                        color: opt.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MText {
                            text: opt.modelData.label
                            color: opt.on ? Theme.fgSecondaryContainer : Theme.fgSurface
                        }
                        MText {
                            Layout.fillWidth: true
                            text: opt.modelData.sub
                            size: Theme.type.bodyS
                            color: opt.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                    }
                    MIcon {
                        visible: opt.on
                        icon: "check_circle"
                        fill: 1
                        color: Theme.fgSecondaryContainer
                    }
                }
                StateLayer {
                    radius: opt.radius
                    onClicked: ch.selected(opt.modelData.value)
                }
            }
        }
    }
}
