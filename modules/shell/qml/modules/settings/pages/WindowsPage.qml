import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Окна и тайлинг"
    description: "Как Hyprland расставляет окна, куда переходит фокус и свои правила для отдельных приложений."

    property int editing: -1

    // --- Раскладка ----------------------------------------------------------
    Group {
        title: "Раскладка окон"
        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: false
            Layout.fillWidth: true
            implicitHeight: lcol.implicitHeight + 28
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4
            ColumnLayout {
                id: lcol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 10
                // Общий режим для всех рабочих столов (services/WindowModes.qml)
                SegmentedButtons {
                    Layout.fillWidth: true
                    options: WindowModes.presets
                    current: WindowModes.globalPreset
                    onSelected: v => WindowModes.setGlobal(v)
                }
                MText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.fgSurfaceVariant
                    text: ({
                            scrolling: "Окна стоят колонками в бесконечной горизонтальной ленте, которая прокручивается.",
                            dwindle: "Каждое новое окно делит место пополам с текущим — классический тайлинг.",
                            master: "Одно большое главное окно, остальные — стопкой рядом.",
                            mixed: "Окна стоят по раскладке «" + WindowModes.presetInfo(Settings.data.layout).label + "», а приложения из списка «Плавающие приложения» ниже плавают.",
                            floating: "Все окна плавают: свободное место и размер, как в обычных системах. Возврат в тайлинг вернёт окна на места, а плавающие запомнят своё."
                        })[WindowModes.globalPreset] ?? ""
                }
                MText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.fgSurfaceVariant
                    size: Theme.type.bodyS
                    text: "Super + Shift + Пробел — следующий режим для текущего рабочего стола; Super + Alt + Пробел — сделать плавающим одно окно."
                }
            }
        }

        // Лента
        SliderItem {
            visible: Settings.data.layout === "scrolling"
            icon: "width"
            title: "Ширина колонки по умолчанию"
            valueText: Math.round(Settings.data.scrollColumnWidth * 100) + "% экрана"
            from: 0.2
            to: 1
            stepSize: 0.05
            value: Settings.data.scrollColumnWidth
            onMoved: v => Settings.data.scrollColumnWidth = Math.round(v * 100) / 100
        }
        SwitchItem {
            visible: Settings.data.layout === "scrolling"
            icon: "fullscreen"
            title: "Одно окно — на весь экран"
            subtitle: "Если на рабочем столе одна колонка, она растягивается на всю ширину"
            checked: Settings.data.scrollFullscreenOne
            onToggled: v => Settings.data.scrollFullscreenOne = v
        }
        ChoiceItem {
            visible: Settings.data.layout === "scrolling"
            icon: "center_focus_strong"
            title: "Окно в фокусе"
            options: [
                {
                    value: 0,
                    label: "Ставить по центру экрана"
                },
                {
                    value: 1,
                    label: "Подвигать ленту ровно настолько, чтобы окно влезло"
                }
            ]
            current: Settings.data.scrollFocusFit
            onSelected: v => Settings.data.scrollFocusFit = v
        }
        SwitchItem {
            visible: Settings.data.layout === "scrolling"
            icon: "swipe_right"
            title: "Прокручивать ленту к окну в фокусе"
            checked: Settings.data.scrollFollowFocus
            onToggled: v => Settings.data.scrollFollowFocus = v
        }
        // Мозаика
        SwitchItem {
            visible: Settings.data.layout === "dwindle"
            icon: "splitscreen"
            title: "Сохранять направление деления"
            subtitle: "Деление не меняется, когда окна закрываются и открываются"
            checked: Settings.data.dwindlePreserveSplit
            onToggled: v => Settings.data.dwindlePreserveSplit = v
        }
        SwitchItem {
            visible: Settings.data.layout === "dwindle"
            icon: "ads_click"
            title: "Делить по положению курсора"
            subtitle: "Новое окно встаёт с той стороны, где курсор"
            checked: Settings.data.dwindleSmartSplit
            onToggled: v => Settings.data.dwindleSmartSplit = v
        }
        // Главное окно
        SliderItem {
            visible: Settings.data.layout === "master"
            icon: "width_normal"
            title: "Размер главного окна"
            valueText: Math.round(Settings.data.masterMfact * 100) + "%"
            from: 0.2
            to: 0.9
            stepSize: 0.05
            value: Settings.data.masterMfact
            onMoved: v => Settings.data.masterMfact = Math.round(v * 100) / 100
        }
        ChoiceItem {
            visible: Settings.data.layout === "master"
            icon: "add_to_queue"
            title: "Новое окно"
            options: [
                {
                    value: "slave",
                    label: "В стопку"
                },
                {
                    value: "master",
                    label: "Становится главным"
                },
                {
                    value: "inherit",
                    label: "Как окно в фокусе"
                }
            ]
            current: Settings.data.masterNewStatus
            onSelected: v => Settings.data.masterNewStatus = v
        }
        ChoiceItem {
            visible: Settings.data.layout === "master"
            icon: "align_horizontal_left"
            title: "Где главное окно"
            options: [
                {
                    value: "left",
                    label: "Слева"
                },
                {
                    value: "right",
                    label: "Справа"
                },
                {
                    value: "top",
                    label: "Сверху"
                },
                {
                    value: "bottom",
                    label: "Снизу"
                },
                {
                    value: "center",
                    label: "По центру"
                }
            ]
            current: Settings.data.masterOrientation
            onSelected: v => Settings.data.masterOrientation = v
        }
    }


    // --- Режимы отдельных рабочих столов ---------------------------------
    Group {
        id: wsGroup
        title: "Свой режим рабочего стола"
        // Открытые столы и те, у которых уже есть свой режим
        readonly property var ids: {
            const set = {};
            for (const w of Hyprland.workspaces.values)
                if (w.id > 0)
                    set[w.id] = true;
            for (const k in Settings.data.workspaceModes ?? {})
                set[k] = true;
            return Object.keys(set).map(Number).sort((a, b) => a - b);
        }
        Repeater {
            model: wsGroup.ids
            ChoiceItem {
                required property var modelData
                required property int index
                first: index === 0
                last: index === wsGroup.ids.length - 1
                icon: "desktop_windows"
                title: "Рабочий стол " + modelData
                options: [
                    {
                        value: "",
                        label: "Как везде — " + WindowModes.presetInfo(WindowModes.globalPreset).label
                    },
                    ...WindowModes.presets.map(p => ({
                                value: p.value,
                                label: p.label
                            }))
                ]
                current: WindowModes.workspacePreset(modelData)
                onSelected: v => WindowModes.setWorkspace(modelData, v)
            }
        }
    }

    Group {
        title: "Плавающие приложения"
        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: true
            Layout.fillWidth: true
            implicitHeight: fcol.implicitHeight + 28
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            radius: 24
            ColumnLayout {
                id: fcol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 10
                MText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.fgSurfaceVariant
                    text: "В смешанном режиме эти приложения плавают, остальные стоят по раскладке. Классы окон через пробел или запятую — их видно в списке открытых окон ниже."
                }
                TextField {
                    id: floatField
                    Layout.fillWidth: true
                    icon: "select_window"
                    placeholder: "org.gnome.Calculator, pavucontrol"
                    text: Settings.data.floatApps.join(", ")
                    onAccepted: {
                        Settings.data.floatApps = text.split(/[,\s]+/).filter(c => c);
                        WindowModes.reconcileSoon();
                    }
                }
            }
        }
    }
    // --- Поведение ------------------------------------------------------------
    Group {
        title: "Поведение"
        ChoiceItem {
            icon: "mouse"
            title: "Фокус за мышью"
            options: [
                {
                    value: 1,
                    label: "Окно под курсором сразу получает фокус"
                },
                {
                    value: 2,
                    label: "Только клавиатура уходит за курсором, клик — фокус"
                },
                {
                    value: 0,
                    label: "Только по клику"
                }
            ]
            current: Settings.data.followMouse
            onSelected: v => Settings.data.followMouse = v
        }
        SwitchItem {
            icon: "notifications_active"
            title: "Переключаться на окно, которое просит фокус"
            subtitle: "Например, когда ссылка из Telegram открывается в браузере на другом столе"
            checked: Settings.data.focusOnActivate
            onToggled: v => Settings.data.focusOnActivate = v
        }
        SwitchItem {
            icon: "drag_pan"
            title: "Менять размер за рамку"
            subtitle: "Потянуть за край окна или за отступ между окнами"
            checked: Settings.data.resizeOnBorder
            onToggled: v => Settings.data.resizeOnBorder = v
        }
        SwitchItem {
            icon: "drag_pan"
            title: "Прилипание плавающих окон"
            subtitle: "К краям экрана и друг к другу"
            checked: Settings.data.snapEnabled
            onToggled: v => Settings.data.snapEnabled = v
        }
        SwitchItem {
            icon: "speed"
            title: "Разрешить разрывы кадров (tearing)"
            subtitle: "Меньше задержка в играх ценой разрывов изображения. Работает для окон с правилом immediate"
            checked: Settings.data.allowTearing
            onToggled: v => Settings.data.allowTearing = v
        }
    }

    // --- Правила окон -----------------------------------------------------
    // Всё мышкой: выбираешь окно (открытое сейчас или приложение из списка),
    // дальше — стол, монитор, режим и размер кнопками. Писать ничего не нужно.
    readonly property var rules: Settings.data.userRules ?? []
    function saveRule(i, patch) {
        const r = rules.slice();
        r[i] = Object.assign({}, r[i], patch);
        Settings.data.userRules = r;
    }
    function removeRule(i) {
        Settings.data.userRules = rules.filter((_, j) => j !== i);
        editing = -1;
    }
    function addRule(rule) {
        const i = rules.findIndex(r => r.cls === rule.cls && !r.title);
        if (i >= 0) {
            editing = i;
        } else {
            Settings.data.userRules = [...rules, Object.assign({
                    exact: true
                }, rule)];
            editing = rules.length - 1;
        }
        picking = false;
    }
    property bool picking: false
    property string pickQuery: ""

    // Открытые окна: значок, имя, заголовок и где сейчас
    readonly property var openWindows: Hyprland.toplevels.values.map(t => {
        const o = t.lastIpcObject ?? {};
        const mon = Hyprland.monitors.values.find(m => m.id === o.monitor);
        return {
            cls: o.class ?? "",
            title: o.title ?? t.title ?? "",
            workspace: o.workspace?.name ?? "",
            monitor: mon?.name ?? "",
            floating: !!o.floating,
            size: o.size ?? [0, 0]
        };
    }).filter(w => w.cls)

    function wsLabel(w) {
        return /^special/.test(w) ? "особый стол" : "стол " + w;
    }
    function screenSize(name) {
        const sc = Quickshell.screens.find(x => x.name === name) ?? Quickshell.screens[0];
        return sc ? [sc.width, sc.height] : [1920, 1080];
    }
    readonly property var sizePresets: [
        {
            value: "",
            label: "Как получится"
        },
        {
            value: "s",
            label: "Маленькое",
            k: [0.4, 0.5]
        },
        {
            value: "m",
            label: "Среднее",
            k: [0.6, 0.7]
        },
        {
            value: "l",
            label: "Большое",
            k: [0.8, 0.85]
        }
    ]

    Group {
        title: "Правила для приложений"

        Repeater {
            model: page.rules
            Rectangle {
                id: rule
                required property var modelData
                required property int index
                readonly property bool groupItem: true
                property bool first: false
                property bool last: false
                readonly property bool open: page.editing === index
                readonly property var entry: Apps.forWindow(modelData.cls)
                readonly property string mode: modelData.fullscreen ? "fullscreen" : modelData.float ? "float" : "tile"
                Layout.fillWidth: true
                implicitHeight: 72 + (open ? editor.implicitHeight + 20 : 0)
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
                        topLeftRadius: rule.topLeftRadius
                        topRightRadius: rule.topRightRadius
                        onClicked: page.editing = rule.open ? -1 : rule.index
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 12
                        spacing: 16
                        AppIcon {
                            size: 36
                            icon: rule.entry?.icon ?? rule.modelData.cls ?? ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            MText {
                                Layout.fillWidth: true
                                text: rule.entry?.name ?? (rule.modelData.cls || rule.modelData.title)
                                size: Theme.type.bodyL
                                elide: Text.ElideRight
                            }
                            MText {
                                Layout.fillWidth: true
                                color: Theme.fgSurfaceVariant
                                elide: Text.ElideRight
                                text: {
                                    const r = rule.modelData;
                                    const p = [];
                                    if (r.workspace)
                                        p.push(page.wsLabel(r.workspace));
                                    if (r.monitor)
                                        p.push(Brightness.label(r.monitor));
                                    p.push(rule.mode === "fullscreen" ? "на весь экран" : rule.mode === "float" ? "плавающее" : "в раскладке");
                                    if (r.float && r.center)
                                        p.push("по центру");
                                    if (r.pin)
                                        p.push("на всех столах");
                                    if (r.opacity && r.opacity < 1)
                                        p.push("прозрачность " + Math.round(r.opacity * 100) + "%");
                                    return p.join(" · ");
                                }
                            }
                        }
                        IconButton {
                            icon: "delete"
                            onClicked: page.removeRule(rule.index)
                        }
                    }
                }

                ColumnLayout {
                    id: editor
                    visible: rule.open
                    y: 72
                    x: 20
                    width: parent.width - 40
                    spacing: 10

                    Label {
                        text: "На каком столе открывать"
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: ["", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
                            Chip {
                                required property string modelData
                                text: modelData === "" ? "На текущем" : modelData
                                square: modelData !== ""
                                on: (rule.modelData.workspace ?? "") === modelData
                                onClicked: page.saveRule(rule.index, {
                                    workspace: modelData
                                })
                            }
                        }
                    }

                    Label {
                        visible: Quickshell.screens.length > 1
                        text: "На каком мониторе"
                    }
                    Flow {
                        Layout.fillWidth: true
                        visible: Quickshell.screens.length > 1
                        spacing: 6
                        Repeater {
                            model: ["", ...Quickshell.screens.map(x => x.name)]
                            Chip {
                                required property string modelData
                                icon: modelData === "" ? "" : "monitor"
                                text: modelData === "" ? "Любой" : Brightness.label(modelData)
                                on: (rule.modelData.monitor ?? "") === modelData
                                onClicked: page.saveRule(rule.index, {
                                    monitor: modelData
                                })
                            }
                        }
                    }

                    Label {
                        text: "Как показывать"
                    }
                    SegmentedButtons {
                        Layout.fillWidth: true
                        options: [
                            {
                                value: "tile",
                                label: "В раскладке",
                                icon: "view_column"
                            },
                            {
                                value: "float",
                                label: "Плавающее",
                                icon: "picture_in_picture"
                            },
                            {
                                value: "fullscreen",
                                label: "На весь экран",
                                icon: "fullscreen"
                            }
                        ]
                        current: rule.mode
                        onSelected: v => page.saveRule(rule.index, {
                            float: v === "float",
                            tile: v === "tile",
                            fullscreen: v === "fullscreen",
                            center: v === "float" ? (rule.modelData.center ?? true) : false
                        })
                    }

                    // Размер — для плавающих
                    Label {
                        visible: rule.mode === "float"
                        text: "Размер"
                    }
                    Flow {
                        Layout.fillWidth: true
                        visible: rule.mode === "float"
                        spacing: 6
                        Repeater {
                            model: page.sizePresets
                            Chip {
                                required property var modelData
                                text: modelData.label
                                on: (rule.modelData.sizePreset ?? (rule.modelData.width ? "custom" : "")) === modelData.value
                                onClicked: {
                                    if (!modelData.k) {
                                        page.saveRule(rule.index, {
                                            sizePreset: "",
                                            width: "",
                                            height: ""
                                        });
                                        return;
                                    }
                                    const [w, h] = page.screenSize(rule.modelData.monitor);
                                    page.saveRule(rule.index, {
                                        sizePreset: modelData.value,
                                        width: Math.round(w * modelData.k[0]),
                                        height: Math.round(h * modelData.k[1])
                                    });
                                }
                            }
                        }
                        Chip {
                            visible: !!rule.modelData.width && (rule.modelData.sizePreset ?? "") === ""
                            on: true
                            text: rule.modelData.width + " × " + rule.modelData.height
                        }
                    }

                    Label {
                        text: "Ещё"
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [
                                {
                                    key: "center",
                                    label: "По центру",
                                    icon: "center_focus_weak",
                                    floatOnly: true
                                },
                                {
                                    key: "pin",
                                    label: "На всех столах",
                                    icon: "push_pin",
                                    floatOnly: true
                                },
                                {
                                    key: "noBlur",
                                    label: "Без размытия",
                                    icon: "blur_off"
                                },
                                {
                                    key: "opaque",
                                    label: "Непрозрачное",
                                    icon: "opacity"
                                }
                            ].filter(c => !c.floatOnly || rule.mode === "float")
                            Chip {
                                required property var modelData
                                icon: modelData.icon
                                text: modelData.label
                                on: !!rule.modelData[modelData.key]
                                onClicked: page.saveRule(rule.index, {
                                    [modelData.key]: !on
                                })
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        MText {
                            text: "Прозрачность"
                            color: Theme.fgSurfaceVariant
                        }
                        MSlider {
                            Layout.fillWidth: true
                            from: 0.3
                            to: 1
                            stepSize: 0.05
                            value: rule.modelData.opacity ?? 1
                            onMoved: v => page.saveRule(rule.index, {
                                opacity: Math.round(v * 100) / 100
                            })
                        }
                        MText {
                            text: Math.round((rule.modelData.opacity ?? 1) * 100) + "%"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }
            }
        }

        ListItem {
            visible: page.rules.length === 0 && !page.picking
            icon: "rule"
            title: "Правил пока нет"
            subtitle: "Например: Telegram всегда на 7-м столе, калькулятор — маленьким плавающим окном"
            clickable: false
        }

        // --- Выбор окна для нового правила ---------------------------------
        Rectangle {
            readonly property bool groupItem: true
            property bool first: false
            property bool last: false
            Layout.fillWidth: true
            implicitHeight: page.picking ? pickCol.implicitHeight + 32 : 64
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4
            clip: true

            StateLayer {
                visible: !page.picking
                radius: parent.bottomLeftRadius
                onClicked: page.picking = true
            }
            RowLayout {
                visible: !page.picking
                anchors.fill: parent
                anchors.leftMargin: 20
                spacing: 16
                MIcon {
                    icon: "add"
                    color: Theme.primary
                }
                MText {
                    text: "Добавить правило"
                    color: Theme.primary
                    weight: Theme.strongWeight
                }
            }

            ColumnLayout {
                id: pickCol
                visible: page.picking
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    MText {
                        Layout.fillWidth: true
                        text: "Выбери окно"
                        size: Theme.type.titleM
                        weight: Theme.strongWeight
                    }
                    IconButton {
                        icon: "close"
                        onClicked: page.picking = false
                    }
                }
                MText {
                    visible: page.openWindows.length > 0
                    text: "Открытые сейчас — правило запомнит, где окно стоит"
                    color: Theme.fgSurfaceVariant
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: page.openWindows
                        Rectangle {
                            id: ow
                            required property var modelData
                            readonly property var entry: Apps.forWindow(modelData.cls)
                            width: 220
                            height: 64
                            radius: Theme.radius.l
                            color: Theme.surfaceContainerHighest
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10
                                AppIcon {
                                    size: 32
                                    icon: ow.entry?.icon ?? ow.modelData.cls
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    MText {
                                        Layout.fillWidth: true
                                        text: ow.entry?.name ?? ow.modelData.cls
                                        elide: Text.ElideRight
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        text: page.wsLabel(ow.modelData.workspace) + (ow.modelData.floating ? " · плавающее" : "")
                                        size: Theme.type.bodyS
                                        color: Theme.fgSurfaceVariant
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                            StateLayer {
                                radius: ow.radius
                                onClicked: {
                                    const w = ow.modelData;
                                    page.addRule({
                                        cls: w.cls,
                                        workspace: /^special/.test(w.workspace) ? "" : w.workspace,
                                        monitor: Quickshell.screens.length > 1 ? w.monitor : "",
                                        float: w.floating,
                                        center: w.floating,
                                        width: w.floating ? w.size[0] : "",
                                        height: w.floating ? w.size[1] : ""
                                    });
                                }
                            }
                        }
                    }
                }

                MText {
                    text: "Или любое приложение"
                    color: Theme.fgSurfaceVariant
                }
                TextField {
                    Layout.fillWidth: true
                    implicitHeight: 48
                    icon: "search"
                    placeholder: "Найти приложение"
                    onTextChanged: page.pickQuery = text
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: Math.max(3, Math.floor(width / 120))
                    rowSpacing: 4
                    columnSpacing: 4
                    Repeater {
                        model: (page.pickQuery ? Apps.search(page.pickQuery) : Apps.all).slice(0, 24)
                        Item {
                            id: ap
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 92
                            StateLayer {
                                radius: Theme.radius.l
                                onClicked: page.addRule({
                                    cls: ap.modelData.startupClass || ap.modelData.id,
                                    workspace: "",
                                    float: false
                                })
                            }
                            ColumnLayout {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                spacing: 6
                                AppIcon {
                                    Layout.alignment: Qt.AlignHCenter
                                    size: 40
                                    icon: ap.modelData.icon
                                }
                                MText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: ap.modelData.name
                                    size: Theme.type.bodyS
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Label: MText {
        size: Theme.type.labelL
        weight: Theme.strongWeight
        color: Theme.primary
        Layout.topMargin: 4
    }
    component Chip: Rectangle {
        id: chip
        property string text
        property string icon: ""
        property bool on: false
        property bool square: false
        signal clicked
        implicitHeight: 40
        implicitWidth: square ? 48 : chipRow.implicitWidth + 28
        radius: on ? Theme.radius.full : Theme.radius.m
        color: on ? Theme.secondaryContainer : "transparent"
        border.width: on ? 0 : 1
        border.color: Theme.outlineVariant
        Behavior on radius {
            NumberAnimation {
                duration: Theme.anim.fast
            }
        }
        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            MIcon {
                visible: chip.on && !chip.square || chip.icon !== ""
                icon: chip.on && !chip.square ? "check" : chip.icon
                size: 18
                color: chip.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
            }
            MText {
                text: chip.text
                size: Theme.type.labelL
                weight: chip.square ? Theme.strongWeight : Theme.fontWeight
                color: chip.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
            }
        }
        StateLayer {
            radius: chip.radius
            onClicked: chip.clicked()
        }
    }
}
