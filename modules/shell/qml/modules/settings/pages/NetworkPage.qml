import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Quickshell.Networking
import Pixel.MD3E

SettingsPage {
    id: page
    title: "Сеть и интернет"

    property var expandedNet: null
    property string failed: ""

    Component.onCompleted: {
        Net.scan(true);
        NetConn.refresh();
    }
    Component.onDestruction: Net.scan(false)

    Group {
        ListItem {
            visible: Net.wiredDevice !== null
            icon: "lan"
            iconTinted: true
            iconBg: Net.wiredConnected ? Theme.primaryContainer : Theme.surfaceContainerHighest
            iconFg: Net.wiredConnected ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
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
                                color: net.modelData.connected ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                            }
                            MIcon {
                                visible: net.secured
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                icon: "lock"
                                size: 14
                                fill: 1
                                color: Theme.fgSurfaceVariant
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
                                color: page.failed === net.modelData.name ? Theme.error : net.modelData.connected ? Theme.primary : Theme.fgSurfaceVariant
                            }
                        }
                        MIcon {
                            visible: net.modelData.connected || net.modelData.known
                            icon: "settings"
                            color: Theme.fgSurfaceVariant
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
                                color: Theme.fgSurfaceVariant
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

    // --- Соединения (вместо nm-connection-editor) --------------------------
    property string openConn: ""
    property bool showService: false
    readonly property var shownConns: NetConn.connections.filter(c => page.showService || !NetConn.isService(c))

    Group {
        title: "Соединения"

        Repeater {
            model: ScriptModel {
                values: page.shownConns.map(c => c.uuid)
            }
            Rectangle {
                id: conn
                required property string modelData
                required property int index
                readonly property var c: NetConn.connections.find(x => x.uuid === modelData) ?? ({})
                readonly property var d: NetConn.details[modelData] ?? null
                readonly property bool open: page.openConn === modelData
                readonly property bool groupItem: true
                property bool first: index === 0
                property bool last: index === page.shownConns.length - 1
                // черновик правок
                property string method: "auto"
                property string addr: ""
                property string gw: ""
                property string dns: ""
                property string ip6: "auto"
                function resetDraft() {
                    if (!d)
                        return;
                    method = d["ipv4.method"] === "manual" ? "manual" : "auto";
                    addr = (d["ipv4.addresses"] ?? "").split(",")[0].trim();
                    gw = d["ipv4.gateway"] === "--" ? "" : (d["ipv4.gateway"] ?? "");
                    dns = (d["ipv4.dns"] ?? "").replace(/^--$/, "");
                    ip6 = d["ipv6.method"] === "disabled" || d["ipv6.method"] === "ignore" ? "disabled" : "auto";
                }
                onDChanged: resetDraft()
                readonly property bool dirty: d !== null && (method !== (d["ipv4.method"] === "manual" ? "manual" : "auto") || (method === "manual" && (addr !== (d["ipv4.addresses"] ?? "").split(",")[0].trim() || gw !== (d["ipv4.gateway"] === "--" ? "" : d["ipv4.gateway"] ?? ""))) || dns !== (d["ipv4.dns"] ?? "").replace(/^--$/, "") || ip6 !== (d["ipv6.method"] === "disabled" || d["ipv6.method"] === "ignore" ? "disabled" : "auto"))

                Layout.fillWidth: true
                implicitHeight: 72 + (open ? editor.implicitHeight + 16 : 0)
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

                Item {
                    width: parent.width
                    height: 72
                    StateLayer {
                        topLeftRadius: conn.topLeftRadius
                        topRightRadius: conn.topRightRadius
                        onClicked: {
                            page.openConn = conn.open ? "" : conn.modelData;
                            if (!conn.open)
                                return;
                            NetConn.load(conn.modelData);
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 16
                        spacing: 16
                        Rectangle {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            radius: 20
                            color: conn.c.active ? Theme.primaryContainer : Theme.surfaceContainerHighest
                            MIcon {
                                anchors.centerIn: parent
                                icon: NetConn.typeIcons[conn.c.type] ?? "settings_ethernet"
                                color: conn.c.active ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            MText {
                                Layout.fillWidth: true
                                text: conn.c.name ?? ""
                                size: Theme.type.bodyL
                                elide: Text.ElideRight
                            }
                            MText {
                                Layout.fillWidth: true
                                text: (NetConn.typeNames[conn.c.type] ?? conn.c.type) + (conn.c.active ? " · подключено" + (conn.c.device ? " (" + conn.c.device + ")" : "") : "")
                                size: Theme.type.bodyM
                                color: conn.c.active ? Theme.primary : Theme.fgSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                        MIcon {
                            icon: conn.open ? "expand_less" : "expand_more"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }

                ColumnLayout {
                    id: editor
                    visible: conn.open
                    y: 72
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12

                    // Сейчас: адрес, шлюз, DNS, MAC
                    GridLayout {
                        Layout.fillWidth: true
                        visible: conn.c.active && conn.d !== null
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 4
                        Repeater {
                            model: conn.d ? [["IP-адрес", NetConn.multi(conn.d, "IP4.ADDRESS").join(", ")], ["Шлюз", conn.d["IP4.GATEWAY"] ?? ""], ["DNS", NetConn.multi(conn.d, "IP4.DNS").join(", ")], ["IPv6", NetConn.multi(conn.d, "IP6.ADDRESS").filter(a => !a.startsWith("fe80")).join(", ")]].filter(r => r[1] && r[1] !== "--") : []
                            delegate: RowLayout {
                                required property var modelData
                                Layout.columnSpan: 2
                                Layout.fillWidth: true
                                MText {
                                    Layout.preferredWidth: 120
                                    text: modelData[0]
                                    color: Theme.fgSurfaceVariant
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: modelData[1]
                                    font.family: Theme.monoFont
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }

                    SwitchRow {
                        Layout.fillWidth: true
                        text: "Подключаться автоматически"
                        checked: conn.c.autoconnect ?? false
                        onToggled: v => NetConn.modify(Object.assign({}, conn.c, {
                            active: false
                        }), {
                            "connection.autoconnect": v ? "yes" : "no"
                        })
                    }
                    SwitchRow {
                        Layout.fillWidth: true
                        visible: conn.d !== null && conn.c.type !== "loopback"
                        text: "Лимитное подключение"
                        sub: "Приложения будут экономить трафик"
                        checked: conn.d?.["connection.metered"] === "yes"
                        onToggled: v => NetConn.modify(Object.assign({}, conn.c, {
                            active: false
                        }), {
                            "connection.metered": v ? "yes" : "no"
                        })
                    }

                    // IPv4
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: conn.d !== null && ["802-3-ethernet", "802-11-wireless"].includes(conn.c.type)
                        spacing: 8
                        MText {
                            text: "Адрес IPv4"
                            weight: Theme.strongWeight
                        }
                        SegmentedButtons {
                            Layout.fillWidth: true
                            options: [
                                {
                                    value: "auto",
                                    label: "Автоматически (DHCP)"
                                },
                                {
                                    value: "manual",
                                    label: "Вручную"
                                }
                            ]
                            current: conn.method
                            onSelected: v => conn.method = v
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: conn.method === "manual"
                            spacing: 8
                            TextField {
                                Layout.fillWidth: true
                                implicitHeight: 48
                                icon: "lan"
                                placeholder: "Адрес/маска, напр. 192.168.1.50/24"
                                text: conn.addr
                                onTextChanged: conn.addr = text
                            }
                            TextField {
                                Layout.fillWidth: true
                                implicitHeight: 48
                                icon: "router"
                                placeholder: "Шлюз, напр. 192.168.1.1"
                                text: conn.gw
                                onTextChanged: conn.gw = text
                            }
                        }
                        TextField {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            icon: "dns"
                            placeholder: conn.method === "manual" ? "DNS через запятую, напр. 1.1.1.1, 8.8.8.8" : "Свои DNS (необязательно), напр. 1.1.1.1, 8.8.8.8"
                            text: conn.dns
                            onTextChanged: conn.dns = text
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: true
                            Repeater {
                                model: [["Cloudflare", "1.1.1.1, 1.0.0.1"], ["Google", "8.8.8.8, 8.8.4.4"], ["Quad9", "9.9.9.9, 149.112.112.112"], ["AdGuard", "94.140.14.14, 94.140.15.15"], ["От провайдера", ""]]
                                delegate: Rectangle {
                                    id: dchip
                                    required property var modelData
                                    readonly property bool sel: conn.dns.replace(/\s/g, "") === modelData[1].replace(/\s/g, "")
                                    implicitHeight: 32
                                    implicitWidth: dtext.implicitWidth + 24
                                    radius: Theme.radius.s
                                    color: sel ? Theme.secondaryContainer : "transparent"
                                    border.width: sel ? 0 : 1
                                    border.color: Theme.outlineVariant
                                    MText {
                                        id: dtext
                                        anchors.centerIn: parent
                                        text: dchip.modelData[0]
                                        size: Theme.type.labelL
                                        color: dchip.sel ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                                    }
                                    StateLayer {
                                        onClicked: conn.dns = dchip.modelData[1]
                                    }
                                }
                            }
                        }
                        MText {
                            text: "IPv6"
                            weight: Theme.strongWeight
                        }
                        SegmentedButtons {
                            Layout.fillWidth: true
                            options: [
                                {
                                    value: "auto",
                                    label: "Автоматически"
                                },
                                {
                                    value: "disabled",
                                    label: "Выключен"
                                }
                            ]
                            current: conn.ip6
                            onSelected: v => conn.ip6 = v
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        visible: NetConn.lastError !== "" && conn.open
                        text: NetConn.lastError
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                        spacing: 8
                        Button {
                            variant: "text"
                            icon: "delete"
                            text: "Удалить"
                            visible: conn.c.type !== "loopback"
                            onClicked: {
                                NetConn.remove(conn.modelData);
                                page.openConn = "";
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Button {
                            variant: "tonal"
                            text: conn.c.active ? "Отключить" : "Подключить"
                            onClicked: conn.c.active ? NetConn.down(conn.modelData) : NetConn.up(conn.modelData)
                        }
                        Button {
                            visible: conn.dirty
                            icon: "check"
                            text: "Сохранить"
                            onClicked: {
                                const dnsList = conn.dns.split(/[\s,]+/).filter(x => x).join(",");
                                const props = {
                                    "ipv4.method": conn.method,
                                    "ipv4.dns": dnsList,
                                    "ipv4.ignore-auto-dns": dnsList ? "yes" : "no",
                                    "ipv6.method": conn.ip6 === "disabled" ? "disabled" : "auto"
                                };
                                if (conn.method === "manual") {
                                    props["ipv4.addresses"] = conn.addr.includes("/") ? conn.addr : conn.addr + "/24";
                                    props["ipv4.gateway"] = conn.gw;
                                } else {
                                    props["ipv4.addresses"] = "";
                                    props["ipv4.gateway"] = "";
                                }
                                NetConn.modify(conn.c, props);
                            }
                        }
                    }
                }
            }
        }

        SwitchItem {
            icon: "device_hub"
            title: "Показывать служебные"
            subtitle: "Мосты Docker, loopback и другие виртуальные интерфейсы"
            checked: page.showService
            onToggled: v => page.showService = v
        }
    }

    // Точка доступа Wi‑Fi
    Group {
        title: "Точка доступа"
        visible: Net.hasWifi
        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: true
            Layout.fillWidth: true
            implicitHeight: hsCol.implicitHeight + 32
            radius: 24
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            ColumnLayout {
                id: hsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 8
                MText {
                    Layout.fillWidth: true
                    text: "Раздать интернет по Wi‑Fi. Пока точка доступа включена, Wi‑Fi-адаптер не подключается к другим сетям."
                    color: Theme.fgSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: hsName
                        Layout.fillWidth: true
                        implicitHeight: 48
                        icon: "wifi_tethering"
                        placeholder: "Имя сети"
                        text: Nix.hostname
                    }
                    TextField {
                        id: hsPass
                        Layout.fillWidth: true
                        implicitHeight: 48
                        icon: "key"
                        placeholder: "Пароль (от 8 символов)"
                        password: true
                    }
                    Button {
                        text: "Включить"
                        disabled: hsName.text === "" || hsPass.text.length < 8
                        onClicked: NetConn.hotspot(hsName.text, hsPass.text)
                    }
                }
            }
        }
    }

    component SwitchRow: RowLayout {
        id: sw
        property string text
        property string sub: ""
        property bool checked
        signal toggled(bool v)
        Layout.fillWidth: true
        ColumnLayout {
            spacing: 0
            MText {
                text: sw.text
            }
            MText {
                visible: sw.sub !== ""
                text: sw.sub
                size: Theme.type.bodyS
                color: Theme.fgSurfaceVariant
            }
        }
        Item {
            Layout.fillWidth: true
        }
        MSwitch {
            checked: sw.checked
            onToggled: v => sw.toggled(v)
        }
    }

    Group {
        title: "Дополнительно"
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
