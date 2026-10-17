import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Клавиатура и мышь"

    readonly property var knownLayouts: [
        {
            value: "us",
            label: "English (US)"
        },
        {
            value: "ru",
            label: "Русская"
        },
        {
            value: "ua",
            label: "Українська"
        },
        {
            value: "by",
            label: "Беларуская"
        },
        {
            value: "kz",
            label: "Қазақша"
        },
        {
            value: "de",
            label: "Deutsch"
        },
        {
            value: "fr",
            label: "Français"
        },
        {
            value: "es",
            label: "Español"
        },
        {
            value: "pl",
            label: "Polski"
        },
        {
            value: "gb",
            label: "English (UK)"
        },
        {
            value: "jp",
            label: "日本語"
        }
    ]
    readonly property var layouts: Settings.data.kbLayout.split(",").map(s => s.trim()).filter(s => s)
    readonly property var options: Settings.data.kbOptions.split(",").map(s => s.trim()).filter(s => s)

    function setLayouts(list) {
        Settings.data.kbLayout = list.join(",");
    }
    function setOption(prefix, value) {
        const rest = options.filter(o => !o.startsWith(prefix));
        Settings.data.kbOptions = (value ? [...rest, value] : rest).join(",");
    }
    function hasOption(o) {
        return options.includes(o);
    }
    function layoutLabel(v) {
        return knownLayouts.find(l => l.value === v)?.label ?? v;
    }

    Group {
        title: "Раскладки"
        Repeater {
            model: page.layouts
            ListItem {
                id: lay
                required property string modelData
                required property int index
                icon: "language"
                title: page.layoutLabel(modelData)
                subtitle: index === 0 ? "Основная · " + modelData : modelData
                clickable: false
                IconButton {
                    visible: lay.index > 0
                    icon: "arrow_upward"
                    onClicked: {
                        const a = [...page.layouts];
                        [a[lay.index - 1], a[lay.index]] = [a[lay.index], a[lay.index - 1]];
                        page.setLayouts(a);
                    }
                }
                IconButton {
                    visible: page.layouts.length > 1
                    icon: "close"
                    onClicked: page.setLayouts(page.layouts.filter((_, i) => i !== lay.index))
                }
            }
        }
        ChoiceItem {
            icon: "add"
            title: "Добавить раскладку"
            options: page.knownLayouts.filter(l => !page.layouts.includes(l.value))
            current: ""
            onSelected: v => page.setLayouts([...page.layouts, v])
        }
        ChoiceItem {
            icon: "swap_horiz"
            title: "Переключение раскладки"
            options: [
                {
                    value: "grp:alt_shift_toggle",
                    label: "Alt + Shift"
                },
                {
                    value: "grp:ctrl_shift_toggle",
                    label: "Ctrl + Shift"
                },
                {
                    value: "grp:win_space_toggle",
                    label: "Super + Пробел"
                },
                {
                    value: "grp:caps_toggle",
                    label: "Caps Lock"
                },
                {
                    value: "grp:alt_space_toggle",
                    label: "Alt + Пробел"
                }
            ]
            current: page.options.find(o => o.startsWith("grp:")) ?? ""
            onSelected: v => page.setOption("grp:", v)
        }
        SwitchItem {
            icon: "keyboard_capslock"
            title: "Caps Lock работает как Escape"
            checked: page.hasOption("caps:escape")
            onToggled: v => page.setOption("caps:", v ? "caps:escape" : "")
        }
        SwitchItem {
            icon: "keyboard_alt"
            title: "Compose на правом Alt"
            subtitle: "Набор символов вроде « » — ≠ ё через последовательности клавиш"
            checked: page.hasOption("compose:ralt")
            onToggled: v => page.setOption("compose:", v ? "compose:ralt" : "")
        }
    }

    Group {
        title: "Повтор клавиш"
        SliderItem {
            icon: "hourglass_top"
            title: "Задержка перед повтором"
            valueText: Settings.data.repeatDelay + " мс"
            from: 150
            to: 1000
            stepSize: 25
            value: Settings.data.repeatDelay
            onMoved: v => Settings.data.repeatDelay = Math.round(v)
        }
        SliderItem {
            icon: "fast_forward"
            title: "Скорость повтора"
            valueText: Settings.data.repeatRate + " /с"
            from: 10
            to: 80
            stepSize: 1
            value: Settings.data.repeatRate
            onMoved: v => Settings.data.repeatRate = Math.round(v)
        }
    }

    Group {
        title: "Мышь"
        SliderItem {
            icon: "mouse"
            title: "Чувствительность"
            valueText: (Settings.data.mouseSensitivity > 0 ? "+" : "") + Settings.data.mouseSensitivity.toFixed(2)
            from: -1
            to: 1
            stepSize: 0.05
            value: Settings.data.mouseSensitivity
            onMoved: v => Settings.data.mouseSensitivity = Math.round(v * 100) / 100
        }
        SwitchItem {
            icon: "trending_up"
            title: "Ускорение указателя"
            subtitle: "Выключено — курсор двигается строго пропорционально, как любят в шутерах"
            checked: Settings.data.accelProfile === "adaptive"
            onToggled: v => Settings.data.accelProfile = v ? "adaptive" : "flat"
        }
        SwitchItem {
            icon: "swap_vert"
            title: "Естественная прокрутка"
            subtitle: "Содержимое движется вслед за пальцами, как на телефоне"
            checked: Settings.data.naturalScroll
            onToggled: v => Settings.data.naturalScroll = v
        }
    }

    Group {
        title: "Сочетания клавиш"
        Repeater {
            model: [["Super + Пробел", "Лаунчер"], ["Super + S", "Настройки"], ["Super + N", "Уведомления и быстрые настройки"], ["Super + V", "Буфер обмена"], ["Super + Tab", "Обзор"], ["Super + Shift + Q", "Меню питания"], ["Super + Alt + L", "Заблокировать"], ["Super + Q", "Закрыть окно"], ["Super + F / D", "Полный экран / развернуть"], ["Super + T / E / W / C", "Терминал / файлы / браузер / редактор"], ["Super + 1…4, G", "Рабочие столы основного монитора"], ["Super + F1…F4", "Рабочие столы второго монитора"], ["Super + M", "Мониторинг (btop)"], ["Super + Shift + S / A / D", "Скриншот области / экрана / окна"], ["Alt + F9 / F10", "Запись экрана без / с микрофоном"]]
            ListItem {
                id: sc
                required property var modelData
                title: modelData[1]
                clickable: false
                Rectangle {
                    implicitWidth: keyText.implicitWidth + 20
                    implicitHeight: 32
                    radius: Theme.radius.s
                    color: Theme.surfaceContainerHighest
                    MText {
                        id: keyText
                        anchors.centerIn: parent
                        text: sc.modelData[0]
                        font.family: Theme.monoFont
                        size: Theme.type.bodyS
                        color: Theme.onSurfaceVariant
                    }
                }
            }
        }
        ListItem {
            icon: "edit"
            title: "Изменить сочетания"
            subtitle: "modules/hyprland/binds.lua в конфиге NixOS"
            chevron: true
            onClicked: Apps.run(["xdg-open", Nix.flake + "/modules/hyprland/binds.lua"])
        }
    }
}
