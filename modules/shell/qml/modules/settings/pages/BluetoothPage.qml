import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Подключённые устройства"
    description: Bt.available ? "" : "Bluetooth-адаптер не найден. Если он есть, проверь, что служба bluetooth включена в «Система → Службы»."

    Component.onCompleted: Bt.discover(true)
    Component.onDestruction: Bt.discover(false)

    Group {
        visible: Bt.available
        SwitchItem {
            icon: "bluetooth"
            title: "Bluetooth"
            subtitle: Bt.enabled ? "Видим как «" + (Bt.adapter?.name ?? "") + "»" : "Выключен"
            checked: Bt.enabled
            onToggled: v => Bt.setEnabled(v)
        }
    }

    Group {
        title: "Сохранённые устройства"
        visible: Bt.enabled && Bt.paired.length > 0
        Repeater {
            model: Bt.paired
            DeviceItem {}
        }
    }

    Group {
        title: Bt.adapter?.discovering ? "Поиск устройств…" : "Доступные устройства"
        visible: Bt.enabled
        Repeater {
            model: Bt.available_
            DeviceItem {}
        }
        ListItem {
            visible: Bt.available_.length === 0
            icon: "bluetooth_searching"
            title: "Устройства не найдены"
            subtitle: "Переведи устройство в режим сопряжения"
            clickable: false
        }
    }

    component DeviceItem: ListItem {
        id: dev
        required property var modelData
        icon: Bt.deviceIcon(modelData)
        iconTinted: true
        iconBg: modelData.connected ? Theme.primaryContainer : Theme.surfaceContainerHighest
        iconFg: modelData.connected ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
        title: modelData.name || modelData.address
        subtitle: {
            const d = modelData;
            if (d.pairing)
                return "Сопряжение…";
            if (d.state === 3)
                return "Подключение…";
            if (d.connected)
                return "Подключено" + (d.batteryAvailable ? " · батарея " + Math.round(d.battery * 100) + "%" : "");
            return d.paired ? "Не подключено" : "Нажми для сопряжения";
        }
        onClicked: {
            const d = modelData;
            if (!d.paired && !d.bonded) {
                d.trusted = true;
                d.pair();
            } else if (d.connected)
                d.disconnect();
            else
                d.connect();
        }

        IconButton {
            visible: dev.modelData.paired || dev.modelData.bonded
            icon: "delete"
            onClicked: dev.modelData.forget()
        }
    }
}
