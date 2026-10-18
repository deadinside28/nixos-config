import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

SettingsPage {
    title: "Питание и блокировка"

    readonly property var timeouts: [0, 60, 120, 300, 600, 900, 1800, 3600].map(s => ({
                value: s,
                label: s === 0 ? "Никогда" : s < 3600 ? (s / 60) + " мин" : "1 ч"
            }))

    Group {
        visible: Battery.present
        title: "Батарея"
        ListItem {
            icon: Battery.icon
            title: Math.round(Battery.percent * 100) + "%"
            subtitle: Battery.charging ? "Заряжается" : "От батареи"
            clickable: false
        }
    }

    Group {
        title: "При бездействии"
        ChoiceItem {
            icon: "lock_clock"
            title: "Блокировать экран через"
            options: timeouts
            current: Settings.data.lockTimeout
            onSelected: v => Settings.data.lockTimeout = v
        }
        ChoiceItem {
            icon: "monitor"
            title: "Выключать экран через"
            options: timeouts
            current: Settings.data.screenOffTimeout
            onSelected: v => Settings.data.screenOffTimeout = v
        }
        ChoiceItem {
            icon: "bedtime"
            title: "Переходить в сон через"
            options: timeouts
            current: Settings.data.suspendTimeout
            onSelected: v => Settings.data.suspendTimeout = v
        }
        SwitchItem {
            icon: "lock"
            title: "Блокировать перед сном"
            checked: Settings.data.lockBeforeSuspend
            onToggled: v => Settings.data.lockBeforeSuspend = v
        }
        SwitchItem {
            icon: "coffee"
            title: "Не засыпать сейчас"
            subtitle: "То же, что плитка «Без сна»: таймеры выше не срабатывают, пока включено"
            checked: Ui.caffeine
            onToggled: v => Ui.caffeine = v
        }
    }

    Group {
        title: "Действия"
        ListItem {
            icon: "lock"
            title: "Заблокировать"
            onClicked: Power.lock()
        }
        ListItem {
            icon: "bedtime"
            title: "Сон"
            onClicked: Power.suspend()
        }
        ListItem {
            icon: "restart_alt"
            title: "Перезагрузить"
            onClicked: Ui.open("power")
        }
        ListItem {
            icon: "power_settings_new"
            title: "Выключить"
            onClicked: Ui.open("power")
        }
    }
}
