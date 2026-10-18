import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Quickshell.Io
import Pixel.MD3E

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

    // --- Сочетания клавиш ----------------------------------------------
    // Стандартные бинды — из ~/.config/hypr/binds.lua (его собирает Nix),
    // их можно выключать. Свои — в Settings.data.userBinds → hypr/shell/binds.lua.
    property var defaultBinds: []
    FileView {
        path: Settings.configDir + "/hypr/binds.lua"
        printErrors: false
        onLoaded: page.defaultBinds = page.parseBinds(text())
    }

    function keyOf(expr) {
        // mainMod .. " + Q"  →  SUPER + Q;  "ALT + Tab" → ALT + Tab
        return expr.replace(/mainMod\s*\.\.\s*/g, '"SUPER" .. ').replace(/"\s*\.\.\s*"/g, "").replace(/"/g, "").replace(/\s+/g, " ").trim();
    }
    function describe(dsp) {
        const m = (re) => dsp.match(re);
        let r;
        if (m(/hyprctl kill/))
            return "Убить окно щелчком";
        if (m(/settings open style/))
            return "Обои и стиль";
        if ((r = m(/exec_cmd\("pixel-shell ([a-z]+) ([a-z]+)/)))
            return ({
                    launcher: "Лаунчер",
                    clipboard: "Буфер обмена",
                    settings: "Настройки",
                    quicksettings: "Быстрые настройки",
                    overview: "Обзор",
                    power: "Меню питания",
                    lock: "Заблокировать",
                    record: "Запись экрана: выбрать, что записывать",
                    files: "Файлы",
                    lens: "Обвести и найти",
                    translate: "Перевести экран",
                    brightness: r[2] === "up" ? "Ярче" : "Темнее",
                    media: "Плеер: " + r[2]
                })[r[1]] ?? ("Оболочка: " + r[1]);
        if ((r = m(/exec_cmd\("pixel-screenshot (\w+)/)))
            return ({
                    area: "Скриншот области",
                    full: "Скриншот экрана",
                    window: "Скриншот окна"
                })[r[1]];
        if (m(/record toggle/))
            return "Запись экрана: выбрать, что записывать";
        if (m(/pixel-record/))
            return "Запись экрана сразу (как в прошлый раз)";
        if (m(/wpctl set-volume.*\+/))
            return "Громче";
        if (m(/wpctl set-volume.*-/))
            return "Тише";
        if (m(/set-mute @DEFAULT_AUDIO_SOURCE/))
            return "Выключить микрофон";
        if (m(/set-mute/))
            return "Без звука";
        if ((r = m(/exec_cmd\("([^"]+)"/)))
            return "Запуск: " + r[1].split(" ")[0];
        if (m(/window\.close/))
            return "Закрыть окно";
        if (m(/window\.float/))
            return "Плавающее окно";
        if (m(/fullscreen\(\{ mode = 1/))
            return "Развернуть";
        if (m(/fullscreen/))
            return "Полный экран";
        if (m(/togglesplit/))
            return "Сменить направление деления";
        if (m(/cycle_next/))
            return "Следующее окно";
        if (m(/window\.drag/))
            return "Перетащить окно мышью";
        if (m(/window\.resize/))
            return "Размер окна мышью";
        if ((r = m(/toggle_special\("(\w+)"/)))
            return r[1] === "monitor" ? "Мониторинг (btop)" : "Особый стол " + r[1];
        if ((r = m(/window\.move\(\{ workspace = "?([^"} ]+)/)))
            return /^r?\+/.test(r[1]) ? "Окно на следующий стол" : /^r?-/.test(r[1]) ? "Окно на предыдущий стол" : "Окно на стол " + r[1];
        if ((r = m(/window\.move\(\{ direction = "(\w+)/)))
            return "Сдвинуть окно: " + ({
                    left: "влево",
                    right: "вправо",
                    up: "вверх",
                    down: "вниз"
                })[r[1]];
        if ((r = m(/focus\(\{ workspace = "?([^"} ]+)/)))
            return /^[mre]?\+/.test(r[1]) ? "Следующий стол" : /^[mre]?-/.test(r[1]) ? "Предыдущий стол" : /empty/.test(r[1]) ? "Пустой стол" : "Стол " + r[1];
        if ((r = m(/focus\(\{ direction = "(\w+)/)))
            return "Фокус " + ({
                    left: "влево",
                    right: "вправо",
                    up: "вверх",
                    down: "вниз"
                })[r[1]];
        return dsp.replace(/^hl\.dsp\./, "");
    }
    function parseBinds(text) {
        const out = [];
        for (const line of text.split("\n")) {
            const r = line.match(/^hl\.bind\((.+?),\s*(hl\.dsp\..*)\)\s*$/);
            if (!r)
                continue;
            const key = keyOf(r[1]);
            out.push({
                key,
                what: describe(r[2])
            });
        }
        return out;
    }

    property string bindFilter: ""
    readonly property var shownDefaults: defaultBinds.filter(b => !bindFilter || (b.key + " " + b.what).toLowerCase().includes(bindFilter.toLowerCase()))

    Group {
        title: "Свои сочетания"
        Repeater {
            model: Settings.data.userBinds ?? []
            ListItem {
                id: ub
                required property var modelData
                required property int index
                icon: "keyboard_command_key"
                title: page.actionLabel(modelData)
                clickable: false
                KeyChip {
                    text: HyprConf.bindKey(ub.modelData)
                }
                IconButton {
                    icon: "delete"
                    onClicked: Settings.data.userBinds = Settings.data.userBinds.filter((_, i) => i !== ub.index)
                }
            }
        }

        // Новое сочетание
        Rectangle {
            readonly property bool groupItem: true
            property bool first: false
            property bool last: false
            Layout.fillWidth: true
            implicitHeight: addCol.implicitHeight + 32
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4

            ColumnLayout {
                id: addCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                MText {
                    text: "Новое сочетание"
                    size: Theme.type.titleS
                    weight: Theme.strongWeight
                }

                // Захват сочетания
                Rectangle {
                    id: capture
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 26
                    color: activeFocus ? Theme.primaryContainer : Theme.surfaceContainerHighest
                    border.width: activeFocus ? 2 : 0
                    border.color: Theme.primary
                    focus: false
                    property string mods: ""
                    property string key: ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 16
                        MIcon {
                            icon: "keyboard"
                            color: capture.activeFocus ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                        }
                        MText {
                            Layout.fillWidth: true
                            text: capture.key ? (capture.mods ? capture.mods + " + " : "") + capture.key : (capture.activeFocus ? "Нажми сочетание клавиш…" : "Нажми здесь и затем сочетание клавиш")
                            color: capture.activeFocus ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                            size: Theme.type.bodyL
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: capture.forceActiveFocus()
                    }
                    Keys.onPressed: event => {
                        const names = {
                            [Qt.Key_Space]: "space",
                            [Qt.Key_Return]: "Return",
                            [Qt.Key_Enter]: "Return",
                            [Qt.Key_Escape]: "Escape",
                            [Qt.Key_Tab]: "Tab",
                            [Qt.Key_Backspace]: "BackSpace",
                            [Qt.Key_Delete]: "Delete",
                            [Qt.Key_Left]: "Left",
                            [Qt.Key_Right]: "Right",
                            [Qt.Key_Up]: "Up",
                            [Qt.Key_Down]: "Down",
                            [Qt.Key_Home]: "Home",
                            [Qt.Key_End]: "End",
                            [Qt.Key_PageUp]: "Prior",
                            [Qt.Key_PageDown]: "Next",
                            [Qt.Key_Print]: "Print",
                            [Qt.Key_Insert]: "Insert",
                            [Qt.Key_Minus]: "minus",
                            [Qt.Key_Equal]: "equal",
                            [Qt.Key_Comma]: "comma",
                            [Qt.Key_Period]: "period",
                            [Qt.Key_Slash]: "slash",
                            [Qt.Key_Semicolon]: "semicolon",
                            [Qt.Key_Apostrophe]: "apostrophe",
                            [Qt.Key_BracketLeft]: "bracketleft",
                            [Qt.Key_BracketRight]: "bracketright",
                            [Qt.Key_Backslash]: "backslash",
                            [Qt.Key_QuoteLeft]: "grave"
                        };
                        const k = event.key;
                        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].includes(k))
                            return;
                        let name = names[k];
                        if (!name && k >= Qt.Key_A && k <= Qt.Key_Z)
                            name = String.fromCharCode(k);
                        if (!name && k >= Qt.Key_0 && k <= Qt.Key_9)
                            name = String.fromCharCode(k);
                        if (!name && k >= Qt.Key_F1 && k <= Qt.Key_F24)
                            name = "F" + (k - Qt.Key_F1 + 1);
                        if (!name)
                            return;
                        const m = [];
                        if (event.modifiers & Qt.MetaModifier)
                            m.push("SUPER");
                        if (event.modifiers & Qt.ControlModifier)
                            m.push("CONTROL");
                        if (event.modifiers & Qt.AltModifier)
                            m.push("ALT");
                        if (event.modifiers & Qt.ShiftModifier)
                            m.push("SHIFT");
                        capture.mods = m.join(" + ");
                        capture.key = name;
                        capture.focus = false;
                        event.accepted = true;
                    }
                }

                ChoiceItem {
                    id: actionChoice
                    property string value: "exec"
                    icon: "bolt"
                    title: "Действие"
                    options: page.actions
                    current: value
                    onSelected: v => value = v
                }
                ChoiceItem {
                    id: appChoice
                    visible: actionChoice.value === "app"
                    property string value: ""
                    icon: "apps"
                    title: "Приложение"
                    options: Apps.all.map(a => ({
                                value: a.id,
                                label: a.name
                            }))
                    current: value
                    onSelected: v => value = v
                }
                ChoiceItem {
                    id: shellChoice
                    visible: actionChoice.value === "shell"
                    property string value: "launcher toggle"
                    icon: "space_dashboard"
                    title: "Что открыть"
                    options: page.shellActions
                    current: value
                    onSelected: v => value = v
                }
                TextField {
                    id: argField
                    Layout.fillWidth: true
                    visible: ["exec", "workspace", "movetows", "focus"].includes(actionChoice.value)
                    implicitHeight: 48
                    icon: actionChoice.value === "exec" ? "terminal" : "tag"
                    placeholder: ({
                            exec: "Команда, например: firefox --new-window",
                            workspace: "Номер стола",
                            movetows: "Номер стола",
                            focus: "left / right / up / down"
                        })[actionChoice.value] ?? ""
                }
                RowLayout {
                    Layout.fillWidth: true
                    MText {
                        Layout.fillWidth: true
                        visible: page.conflict !== ""
                        text: page.conflict
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }
                    Item {
                        Layout.fillWidth: page.conflict === ""
                    }
                    Button {
                        text: "Добавить"
                        icon: "add"
                        disabled: !capture.key
                        onClicked: {
                            const a = actionChoice.value;
                            const arg = a === "app" ? appChoice.value : a === "shell" ? shellChoice.value : argField.text;
                            Settings.data.userBinds = [...(Settings.data.userBinds ?? []), {
                                    mods: capture.mods,
                                    key: capture.key,
                                    action: a,
                                    arg
                                }];
                            capture.key = "";
                            capture.mods = "";
                            argField.text = "";
                        }
                    }
                }
            }
        }
    }

    readonly property string conflict: {
        const k = (capture.mods ? capture.mods + " + " : "") + capture.key;
        if (!capture.key)
            return "";
        const norm = x => x.toLowerCase().replace(/\bctrl\b/g, "control");
        const d = defaultBinds.find(b => norm(b.key) === norm(k) && !Settings.data.disabledBinds.includes(b.key));
        return d ? "Уже занято: «" + d.what + "». Выключи стандартное ниже, чтобы переназначить." : "";
    }

    readonly property var actions: [
        {
            value: "exec",
            label: "Выполнить команду"
        },
        {
            value: "app",
            label: "Открыть приложение"
        },
        {
            value: "shell",
            label: "Открыть панель оболочки"
        },
        {
            value: "close",
            label: "Закрыть окно"
        },
        {
            value: "float",
            label: "Плавающее окно вкл/выкл"
        },
        {
            value: "fullscreen",
            label: "Полный экран"
        },
        {
            value: "maximize",
            label: "Развернуть"
        },
        {
            value: "pin",
            label: "Закрепить окно на всех столах"
        },
        {
            value: "workspace",
            label: "Перейти на стол…"
        },
        {
            value: "movetows",
            label: "Отправить окно на стол…"
        },
        {
            value: "focus",
            label: "Фокус в сторону…"
        }
    ]
    readonly property var shellActions: [
        {
            value: "launcher toggle",
            label: "Лаунчер"
        },
        {
            value: "quicksettings toggle",
            label: "Быстрые настройки"
        },
        {
            value: "settings toggle",
            label: "Настройки"
        },
        {
            value: "overview toggle",
            label: "Обзор"
        },
        {
            value: "clipboard toggle",
            label: "Буфер обмена"
        },
        {
            value: "power toggle",
            label: "Меню питания"
        },
        {
            value: "lock lock",
            label: "Заблокировать"
        },
        {
            value: "theme toggle",
            label: "Тёмная/светлая тема"
        },
        {
            value: "wallpaper random",
            label: "Случайные обои"
        },
        {
            value: "notifications dnd",
            label: "Не беспокоить вкл/выкл"
        }
    ]
    function actionLabel(b) {
        const a = actions.find(x => x.value === b.action)?.label ?? b.action;
        if (b.action === "app")
            return "Открыть " + (Apps.byId(b.arg)?.name ?? b.arg);
        if (b.action === "shell")
            return shellActions.find(x => x.value === b.arg)?.label ?? b.arg;
        if (b.action === "exec")
            return "Команда: " + b.arg;
        if (["workspace", "movetows", "focus"].includes(b.action))
            return a.replace("…", " " + b.arg);
        return a;
    }

    Group {
        title: "Стандартные сочетания"
        TextField {
            Layout.fillWidth: true
            implicitHeight: 48
            icon: "search"
            placeholder: "Найти сочетание или действие"
            onTextChanged: page.bindFilter = text
        }
        Repeater {
            model: page.shownDefaults
            SwitchItem {
                id: db
                required property var modelData
                title: modelData.what
                checked: !Settings.data.disabledBinds.includes(modelData.key)
                onToggled: v => Settings.data.disabledBinds = v ? Settings.data.disabledBinds.filter(k => k !== modelData.key) : [...Settings.data.disabledBinds, modelData.key]
                KeyChip {
                    text: db.modelData.key
                }
            }
        }
    }

    component KeyChip: Rectangle {
        property alias text: keyText.text
        implicitWidth: keyText.implicitWidth + 20
        implicitHeight: 32
        radius: Theme.radius.s
        color: Theme.surfaceContainerHighest
        MText {
            id: keyText
            anchors.centerIn: parent
            font.family: Theme.monoFont
            size: Theme.type.bodyS
            color: Theme.fgSurfaceVariant
        }
    }
}
