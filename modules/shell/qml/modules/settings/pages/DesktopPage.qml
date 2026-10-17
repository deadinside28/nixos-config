import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Quickshell

SettingsPage {
    title: "Рабочий стол и окна"

    Group {
        title: "Панель задач"

        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: false
            Layout.fillWidth: true
            implicitHeight: 88
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 8
                MText {
                    text: "Положение"
                    size: Theme.type.bodyL
                }
                SegmentedButtons {
                    Layout.fillWidth: true
                    options: [
                        {
                            value: "bottom",
                            label: "Снизу",
                            icon: "align_vertical_bottom"
                        },
                        {
                            value: "top",
                            label: "Сверху",
                            icon: "align_vertical_top"
                        },
                        {
                            value: "left",
                            label: "Слева",
                            icon: "align_horizontal_left"
                        },
                        {
                            value: "right",
                            label: "Справа",
                            icon: "align_horizontal_right"
                        }
                    ]
                    current: Settings.data.taskbarPosition
                    onSelected: v => Settings.data.taskbarPosition = v
                }
            }
        }

        // На каких экранах: переключатель на каждый монитор
        Repeater {
            model: Quickshell.screens
            SwitchItem {
                id: scr
                required property var modelData
                readonly property var list: Settings.data.taskbarScreens
                readonly property bool on: list.length === 0 || list.includes(modelData.name)
                icon: "desktop_windows"
                title: "Показывать на " + modelData.name
                subtitle: (modelData.model || "") + " · " + modelData.width + "×" + modelData.height
                checked: on
                // последний включённый экран выключить нельзя
                disabled: on && Quickshell.screens.filter(s => list.length === 0 || list.includes(s.name)).length <= 1
                onToggled: v => {
                    let names = list.length === 0 ? Quickshell.screens.map(s => s.name) : [...list];
                    names = v ? [...new Set([...names, modelData.name])] : names.filter(n => n !== modelData.name);
                    // все экраны — храним как «пусто», чтобы новые мониторы тоже получали панель
                    Settings.data.taskbarScreens = names.length === Quickshell.screens.length ? [] : names;
                }
            }
        }
        SwitchItem {
            icon: "keyboard"
            title: "Раскладка клавиатуры"
            subtitle: "Значок языка у часов; клик по нему — следующая раскладка"
            checked: Settings.data.showKeyboardLayout
            onToggled: v => Settings.data.showKeyboardLayout = v
        }
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
        ChoiceItem {
            icon: "more_up"
            title: "Значков трея на панели"
            options: [0, 1, 2, 3, 4, 5, 6, 99].map(n => ({
                        value: n,
                        label: n === 0 ? "Все под стрелкой" : n === 99 ? "Все на панели" : String(n)
                    }))
            current: Settings.data.trayVisible
            onSelected: v => Settings.data.trayVisible = v
        }
        SwitchItem {
            icon: "widgets"
            title: "Системный трей"
            subtitle: "Значки Steam, Telegram и других фоновых приложений"
            checked: Settings.data.showTray
            onToggled: v => Settings.data.showTray = v
        }
        SwitchItem {
            icon: "upgrade"
            title: "Обновления системы"
            subtitle: "Прогресс обновления и сколько пакетов обновилось — с версиями"
            checked: Settings.data.showUpdates
            onToggled: v => Settings.data.showUpdates = v
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
        SliderItem {
            icon: "opacity"
            title: "Плотность панелей"
            valueText: Math.round(Settings.data.panelOpacity * 100) + "%"
            from: 0.5
            to: 1
            stepSize: 0.01
            value: Settings.data.panelOpacity
            disabled: !Settings.data.blur
            onMoved: v => Settings.data.panelOpacity = Math.round(v * 100) / 100
        }
    }

    Group {
        title: "Плавность и производительность"
        SwitchItem {
            icon: "animation"
            title: "Анимации окон"
            subtitle: "Пружины Material 3 при открытии, перемещении и смене рабочих столов"
            checked: Settings.data.hyprAnimations
            onToggled: v => Settings.data.hyprAnimations = v
        }
        SliderItem {
            icon: "blur_on"
            title: "Проходы размытия"
            valueText: Settings.data.blurPasses
            from: 1
            to: 4
            stepSize: 1
            value: Settings.data.blurPasses
            disabled: !Settings.data.blur
            onMoved: v => Settings.data.blurPasses = Math.round(v)
        }
        SliderItem {
            icon: "lens_blur"
            title: "Сила размытия"
            valueText: Settings.data.blurSize
            from: 2
            to: 12
            stepSize: 1
            value: Settings.data.blurSize
            disabled: !Settings.data.blur
            onMoved: v => Settings.data.blurSize = Math.round(v)
        }
        SwitchItem {
            icon: "layers"
            title: "Размывать только обои"
            subtitle: "Под окнами видно обои, а не другие окна. Намного легче для видеокарты — особенно с живыми обоями"
            checked: Settings.data.blurXray
            disabled: !Settings.data.blur
            onToggled: v => Settings.data.blurXray = v
        }
        SwitchItem {
            icon: "shadow"
            title: "Тени окон"
            checked: Settings.data.shadows
            onToggled: v => Settings.data.shadows = v
        }
    }

    Group {
        title: "Анимации оболочки"
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
