import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Quickshell.Networking

SettingsPage {
    id: page
    title: "Сеть и интернет"

    property var expandedNet: null
    property string failed: ""

    Component.onCompleted: Net.scan(true)
    Component.onDestruction: Net.scan(false)

    Group {
        ListItem {
            visible: Net.wiredDevice !== null
            icon: "lan"
            iconTinted: true
            iconBg: Net.wiredConnected ? Theme.primaryContainer : Theme.surfaceContainerHighest
            iconFg: Net.wiredConnected ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
            title: "Ethernet"
            subtitle: Net.wiredConnected ? "Подключено" + (Net.wiredDevice.linkSpeed > 0 ? " · " + Net.wiredDevice.linkSpeed + " Мбит/с" : "") : (Net.wiredDevice?.hasLink ? "Кабель подключён" : "Кабель не подключён")
            clickable: false
        }
        SwitchItem {
            visible: Net.hasWifi
            icon: "wifi"
            title: "Wi‑Fi"
            subtitle: Net.wifiEnabled ? (Net.activeWifi ? "Подключено к " + Net.activeWifi.name : "Ищет сети…") : "Выключен"
            checked: Net.wifiEnabled
            onToggled: v => Net.setWifi(v)
        }
        ListItem {
            visible: !Net.hasWifi && Net.wiredDevice === null
            icon: "signal_disconnected"
            title: "Сетевых устройств нет"
            subtitle: "NetworkManager не нашёл ни Wi‑Fi, ни Ethernet"
            clickable: false
        }
    }

    Group {
        title: "Доступные сети"
        visible: Net.hasWifi && Net.wifiEnabled

        Repeater {
            model: Net.networks

            Rectangle {
                id: net
                required property var modelData
                required property int index
                readonly property bool groupItem: true
                property bool first: index === 0
                property bool last: index === Net.networks.length - 1
                readonly property bool open: page.expandedNet === modelData
                readonly property bool secured: Net.secured(modelData)

                Layout.fillWidth: true
                implicitHeight: 72 + (open ? details.implicitHeight + 16 : 0)
                color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                topLeftRadius: first ? 24 : 4
                topRightRadius: first ? 24 : 4
                bottomLeftRadius: last ? 24 : 4
                bottomRightRadius: last ? 24 : 4
                clip: true

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: Theme.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Connections {
                    target: net.modelData
                    function onConnectionFailed(reason) {
                        page.failed = net.modelData.name;
                        page.expandedNet = net.modelData;
                    }
                }

                Item {
                    width: parent.width
                    height: 72
                    StateLayer {
                        topLeftRadius: net.topLeftRadius
                        topRightRadius: net.topRightRadius
                        onClicked: {
                            const n = net.modelData;
                            if (!n.connected && (n.known || !net.secured)) {
                                n.connect();
                                page.expandedNet = null;
                            } else {
                                page.expandedNet = net.open ? null : n;
                                page.failed = "";
                            }
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 16
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: net.modelData.connected ? Theme.primaryContainer : "transparent"
                            MIcon {
                                anchors.centerIn: parent
                                icon: Net.signalIcon(net.modelData.signalStrength)
                                fill: 1
                                color: net.modelData.connected ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                            }
                            MIcon {
                                visible: net.secured
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                icon: "lock"
                                size: 14
                                fill: 1
                                color: Theme.onSurfaceVariant
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            MText {
                                Layout.fillWidth: true
                                text: net.modelData.name
                                size: Theme.type.bodyL
                            }
                            MText {
                                Layout.fillWidth: true
                                text: net.modelData.stateChanging ? "Подключение…" : net.modelData.connected ? "Подключено" : page.failed === net.modelData.name ? "Не удалось подключиться" : net.modelData.known ? "Сохранена" : net.secured ? "Защищена" : "Открытая"
                                color: page.failed === net.modelData.name ? Theme.error : net.modelData.connected ? Theme.primary : Theme.onSurfaceVariant
                            }
                        }
                        MIcon {
                            visible: net.modelData.connected || net.modelData.known
                            icon: "settings"
                            color: Theme.onSurfaceVariant
                        }
                    }
                }

                ColumnLayout {
                    id: details
                    visible: net.open
                    y: 72
                    x: 20
                    width: parent.width - 40
                    spacing: 12

                    TextField {
                        id: psk
                        visible: !net.modelData.connected && net.secured
                        Layout.fillWidth: true
                        implicitHeight: 52
                        password: !showPass.checked
                        icon: "key"
                        placeholder: "Пароль сети"
                        onVisibleChanged: if (visible)
                            forceFocus()
                        onAccepted: if (text.length >= 8) {
                            net.modelData.connectWithPsk(text);
                            page.failed = "";
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        RowLayout {
                            visible: psk.visible
                            MSwitch {
                                id: showPass
                                onToggled: v => checked = v
                            }
                            MText {
                                text: "Показать пароль"
                                color: Theme.onSurfaceVariant
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Button {
                            visible: net.modelData.known
                            variant: "text"
                            text: "Забыть"
                            onClicked: {
                                net.modelData.forget();
                                page.expandedNet = null;
                            }
                        }
                        Button {
                            visible: net.modelData.connected
                            variant: "tonal"
                            text: "Отключиться"
                            onClicked: {
                                net.modelData.disconnect();
                                page.expandedNet = null;
                            }
                        }
                        Button {
                            visible: !net.modelData.connected
                            text: "Подключиться"
                            disabled: psk.visible && psk.text.length < 8
                            onClicked: {
                                if (psk.visible)
                                    net.modelData.connectWithPsk(psk.text);
                                else
                                    net.modelData.connect();
                                page.failed = "";
                            }
                        }
                    }
                }
            }
        }

        ListItem {
            visible: Net.networks.length === 0
            icon: "wifi_find"
            title: "Поиск сетей…"
            clickable: false
        }
    }

    Group {
        title: "Дополнительно"
        ListItem {
            icon: "settings_ethernet"
            title: "Расширенные параметры сети"
            subtitle: "Статический IP, DNS, VPN, точка доступа — редактор соединений NetworkManager"
            chevron: true
            onClicked: Apps.run(["nm-connection-editor"])
        }
        SwitchItem {
            icon: "public"
            title: "Проверка доступа в интернет"
            subtitle: "Определять «сеть без интернета» и порталы входа"
            checked: Networking.connectivityCheckEnabled
            disabled: !Networking.canCheckConnectivity
            onToggled: v => Networking.connectivityCheckEnabled = v
        }
    }
}
