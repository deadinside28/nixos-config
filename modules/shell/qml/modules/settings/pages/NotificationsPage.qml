import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Quickshell

SettingsPage {
    title: "Уведомления"

    Group {
        SwitchItem {
            icon: "do_not_disturb_on"
            title: "Не беспокоить"
            subtitle: "Уведомления копятся в центре, но не всплывают. Важные (critical) всё равно покажутся"
            checked: Settings.data.dnd
            onToggled: v => Settings.data.dnd = v
        }
        SwitchItem {
            icon: "notifications_active"
            title: "Всплывающие уведомления"
            subtitle: "Карточки справа внизу над панелью задач"
            checked: Settings.data.notifPopups
            onToggled: v => Settings.data.notifPopups = v
        }
        ChoiceItem {
            icon: "timer"
            title: "Сколько показывать"
            options: [3000, 5000, 6000, 8000, 10000, 15000].map(ms => ({
                        value: ms,
                        label: (ms / 1000) + " с"
                    }))
            current: Settings.data.notifTimeout
            onSelected: v => Settings.data.notifTimeout = v
        }
    }

    Group {
        title: "История"
        ListItem {
            icon: "notifications"
            title: Notifs.count > 0 ? "Уведомлений в центре: " + Notifs.count : "Центр уведомлений пуст"
            subtitle: "Открывается кликом по часам на панели задач или Super+N"
            clickable: false
            Button {
                visible: Notifs.count > 0
                variant: "tonal"
                text: "Очистить"
                onClicked: Notifs.clearAll()
            }
        }
        ListItem {
            icon: "science"
            title: "Проверить"
            subtitle: "Отправить тестовое уведомление"
            onClicked: Quickshell.execDetached(["notify-send", "-a", "Настройки", "-i", "preferences-system", "Проверка уведомлений", "Если ты это видишь — всё работает."])
        }
    }
}
