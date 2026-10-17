// Меню питания: затемнение и крупные кнопки по центру, как на Pixel.
// Опасные действия требуют второго нажатия.
import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services

Overlay {
    id: root
    name: "power"
    dim: true
    open: Ui.panel === "power"
    onDismissed: Ui.close()

    property string armed: ""
    onOpenChanged: armed = ""

    readonly property var actions: [
        {
            id: "lock",
            icon: "lock",
            label: "Блокировка",
            run: () => Power.lock(),
            confirm: false
        },
        {
            id: "suspend",
            icon: "bedtime",
            label: "Сон",
            run: () => Power.suspend(),
            confirm: false
        },
        {
            id: "logout",
            icon: "logout",
            label: "Выйти",
            run: () => Power.logout(),
            confirm: true
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: "Перезагрузка",
            run: () => Power.reboot(),
            confirm: true
        },
        {
            id: "poweroff",
            icon: "power_settings_new",
            label: "Выключение",
            run: () => Power.poweroff(),
            confirm: true
        }
    ]

    Card {
        anchors.centerIn: parent
        width: row.implicitWidth + 48
        height: row.implicitHeight + 48
        scale: 0.9 + 0.1 * root.progress
        opacity: root.progress
        color: Theme.surfaceContainer

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: root.actions

                ColumnLayout {
                    id: act
                    required property var modelData
                    readonly property bool isArmed: root.armed === modelData.id
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 96
                        implicitHeight: 96
                        radius: act.isArmed ? 48 : Theme.radius.xl
                        color: act.isArmed ? Theme.error : act.modelData.id === "poweroff" ? Theme.primary : Theme.secondaryContainer
                        Behavior on radius {
                            NumberAnimation {
                                duration: Theme.anim.normal
                                easing.type: Easing.OutBack
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.anim.fast
                            }
                        }
                        MIcon {
                            anchors.centerIn: parent
                            icon: act.modelData.icon
                            size: 36
                            fill: 1
                            color: act.isArmed ? Theme.fgError : act.modelData.id === "poweroff" ? Theme.fgPrimary : Theme.fgSecondaryContainer
                        }
                        StateLayer {
                            onClicked: {
                                if (act.modelData.confirm && !act.isArmed) {
                                    root.armed = act.modelData.id;
                                    return;
                                }
                                Ui.close();
                                act.modelData.run();
                            }
                        }
                    }
                    MText {
                        Layout.alignment: Qt.AlignHCenter
                        text: act.isArmed ? "Ещё раз" : act.modelData.label
                        color: act.isArmed ? Theme.error : Theme.fgSurface
                        weight: Theme.strongWeight
                    }
                }
            }
        }
    }
}
