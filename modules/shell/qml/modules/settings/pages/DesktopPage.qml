import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    title: "Рабочий стол и окна"

    Group {
        title: "Панель задач"
        SwitchItem {
            icon: "align_horizontal_center"
            title: "Значки по центру"
            subtitle: "Как на Pixel. Выключи — будут слева, рядом с лаунчером"
            checked: Settings.data.taskbarCentered
            onToggled: v => Settings.data.taskbarCentered = v
        }
        SwitchItem {
            icon: "more_horiz"
            title: "Индикатор рабочих столов"
            subtitle: "Точки воркспейсов рядом с кнопкой лаунчера"
            checked: Settings.data.showWorkspaces
            onToggled: v => Settings.data.showWorkspaces = v
        }
        SwitchItem {
            icon: "widgets"
            title: "Системный трей"
            subtitle: "Значки Steam, Telegram и других фоновых приложений"
            checked: Settings.data.showTray
            onToggled: v => Settings.data.showTray = v
        }
    }

    Group {
        title: "Закреплённые приложения"
        Repeater {
            model: Settings.data.pinnedApps
            ListItem {
                id: pin
                required property string modelData
                required property int index
                readonly property var entry: Apps.all.length ? Apps.byId(modelData) : null
                title: entry?.name ?? modelData
                subtitle: entry ? "" : "Не установлено"
                clickable: false
                appIcon: pin.entry?.icon ?? "application-x-executable"
                IconButton {
                    icon: "arrow_upward"
                    visible: pin.index > 0
                    onClicked: {
                        const a = [...Settings.data.pinnedApps];
                        [a[pin.index - 1], a[pin.index]] = [a[pin.index], a[pin.index - 1]];
                        Settings.data.pinnedApps = a;
                    }
                }
                IconButton {
                    icon: "close"
                    onClicked: Settings.unpin(pin.modelData)
                }
            }
        }
        ListItem {
            icon: "add"
            title: "Закрепить приложение"
            subtitle: "ПКМ по приложению в лаунчере или на панели задач"
            clickable: false
        }
    }

    Group {
        title: "Часы"
        SwitchItem {
            icon: "schedule"
            title: "24-часовой формат"
            checked: Settings.data.use24h
            onToggled: v => Settings.data.use24h = v
        }
        SwitchItem {
            icon: "timer"
            title: "Показывать секунды"
            checked: Settings.data.showSeconds
            onToggled: v => Settings.data.showSeconds = v
        }
        SwitchItem {
            icon: "calendar_today"
            title: "Показывать дату"
            checked: Settings.data.showDate
            onToggled: v => Settings.data.showDate = v
        }
    }

    Group {
        title: "Окна"
        SliderItem {
            icon: "rounded_corner"
            title: "Скругление углов"
            valueText: Settings.data.rounding + " px"
            from: 0
            to: 28
            stepSize: 1
            value: Settings.data.rounding
            onMoved: v => Settings.data.rounding = Math.round(v)
        }
        SliderItem {
            icon: "padding"
            title: "Отступ между окнами"
            valueText: Settings.data.gapsIn + " px"
            from: 0
            to: 24
            stepSize: 1
            value: Settings.data.gapsIn
            onMoved: v => Settings.data.gapsIn = Math.round(v)
        }
        SliderItem {
            icon: "fit_screen"
            title: "Отступ от краёв экрана"
            valueText: Settings.data.gapsOut + " px"
            from: 0
            to: 40
            stepSize: 1
            value: Settings.data.gapsOut
            onMoved: v => Settings.data.gapsOut = Math.round(v)
        }
        SliderItem {
            icon: "border_style"
            title: "Толщина рамки"
            valueText: Settings.data.borderSize + " px"
            from: 0
            to: 6
            stepSize: 1
            value: Settings.data.borderSize
            onMoved: v => Settings.data.borderSize = Math.round(v)
        }
        SliderItem {
            icon: "opacity"
            title: "Непрозрачность окон"
            valueText: Math.round(Settings.data.windowOpacity * 100) + "%"
            from: 0.6
            to: 1
            stepSize: 0.01
            value: Settings.data.windowOpacity
            onMoved: v => Settings.data.windowOpacity = Math.round(v * 100) / 100
        }
        SwitchItem {
            icon: "blur_on"
            title: "Размытие под окнами и панелями"
            subtitle: "Эффект матового стекла. Выключи, если важна каждая миллисекунда в играх"
            checked: Settings.data.blur
            onToggled: v => Settings.data.blur = v
        }
    }

    Group {
        title: "Анимации"
        ChoiceItem {
            icon: "animation"
            title: "Скорость анимаций оболочки"
            options: [
                {
                    value: 0.5,
                    label: "Быстро"
                },
                {
                    value: 1,
                    label: "Обычно"
                },
                {
                    value: 1.5,
                    label: "Плавно"
                },
                {
                    value: 0.01,
                    label: "Без анимаций"
                }
            ]
            current: Settings.data.animationScale
            onSelected: v => Settings.data.animationScale = v
        }
    }
}
