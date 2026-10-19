import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

SettingsPage {
    id: page
    title: "Подключённые устройства"

    Component.onCompleted: {
        Bt.discover(true);
        Bt.diagnose();
    }
    Component.onDestruction: Bt.discover(false)

    // Адаптера не видно: объяснить почему и предложить, что сделать
    Group {
        visible: !Bt.available
        title: "Адаптер не найден"
        ListItem {
            visible: Bt.diag.service !== "" && Bt.diag.service !== "active"
            icon: "settings_power"
            title: "Служба Bluetooth не запущена"
            subtitle: "Если в «Система → Службы» выключен Bluetooth — включи его и нажми «Применить». Иначе запусти службу здесь"
            Button {
                text: "Запустить"
                variant: "tonal"
                onClicked: Bt.startService()
            }
        }
        ListItem {
            visible: Bt.diag.hardBlocked
            icon: "airplanemode_active"
            title: "Адаптер выключен переключателем"
            subtitle: "Аппаратная блокировка: кнопка или режим «в самолёте» на ноутбуке, либо Bluetooth выключен в BIOS"
            clickable: false
        }
        ListItem {
            visible: Bt.diag.service === "active" && Bt.diag.hci.length > 0
            icon: "restart_alt"
            title: "Система видит " + Bt.diag.hci.join(", ") + ", оболочка — нет"
            subtitle: "Служба Bluetooth запустилась позже оболочки. Перезапуск оболочки подхватит адаптер, окна не закроются"
            Button {
                text: "Перезапустить"
                variant: "tonal"
                onClicked: Quickshell.execDetached(["systemctl", "--user", "restart", "pixel-shell.service"])
            }
        }
        ListItem {
            visible: Bt.diag.service === "active" && Bt.diag.hci.length === 0
            icon: "usb"
            title: "Ядро не видит ни одного адаптера"
            subtitle: "Переподключи USB-адаптер в другой порт (лучше прямо в плату, без хаба). Если не поможет — пришли вывод «journalctl -k | grep -i blue»"
            clickable: false
        }
        ListItem {
            icon: "refresh"
            title: "Проверить снова"
            onClicked: Bt.diagnose()
        }
    }

    Group {
        visible: Bt.available
        SwitchItem {
            icon: "bluetooth"
            title: "Bluetooth"
            subtitle: Bt.blocked ? "Заблокирован (rfkill) — включи, чтобы снять блокировку" : Bt.enabled ? "Видим как «" + (Bt.adapter?.name ?? "") + "»" : "Выключен"
            checked: Bt.enabled
            onToggled: v => Bt.setEnabled(v)
        }
        // Несколько адаптеров (встроенный и USB) — выбрать рабочий
        ChoiceItem {
            visible: Bt.adapters.length > 1
            icon: "settings_bluetooth"
            title: "Адаптер"
            options: Bt.adapters.map(a => ({
                        value: a.adapterId,
                        label: Bt.adapterLabel(a) + (a.enabled ? "" : " (выключен)")
                    }))
            current: Bt.adapter?.adapterId
            onSelected: v => Bt.chooseAdapter(Bt.adapters.find(a => a.adapterId === v))
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
