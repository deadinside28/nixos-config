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
                SegmentedButtons {
                    Layout.fillWidth: true
                    options: [
                        {
                            value: "scrolling",
                            label: "Лента",
                            icon: "view_column"
                        },
                        {
                            value: "dwindle",
                            label: "Мозаика",
                            icon: "dashboard"
                        },
                        {
                            value: "master",
                            label: "Главное окно",
                            icon: "view_quilt"
                        }
                    ]
                    current: Settings.data.layout
                    onSelected: v => Settings.data.layout = v
                }
                MText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.fgSurfaceVariant
                    text: ({
                            scrolling: "Окна стоят колонками в бесконечной горизонтальной ленте, которая прокручивается.",
                            dwindle: "Каждое новое окно делит место пополам с текущим — классический тайлинг.",
                            master: "Одно большое главное окно, остальные — стопкой рядом."
                        })[Settings.data.layout] ?? ""
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
            icon: "magnet"
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
    // Классы открытых окон — подсказки для нового правила
    readonly property var openClasses: [...new Set(Hyprland.toplevels.values.map(t => t.lastIpcObject?.class ?? "").filter(c => c))].sort()

    Group {
        title: "Свои правила окон"

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
                            size: 32
                            icon: rule.entry?.icon ?? rule.modelData.cls ?? ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            MText {
                                Layout.fillWidth: true
                                text: rule.entry?.name ?? (rule.modelData.cls || ("Заголовок: " + rule.modelData.title))
                                size: Theme.type.bodyL
                            }
                            MText {
                                Layout.fillWidth: true
                                color: Theme.fgSurfaceVariant
                                text: {
                                    const r = rule.modelData;
                                    const p = [];
                                    if (r.float)
                                        p.push("плавающее");
                                    if (r.center)
                                        p.push("по центру");
                                    if (r.pin)
                                        p.push("на всех столах");
                                    if (r.fullscreen)
                                        p.push("на весь экран");
                                    if (r.workspace)
                                        p.push("стол " + r.workspace);
                                    if (r.monitor)
                                        p.push(r.monitor);
                                    if (r.width && r.height)
                                        p.push(r.width + "×" + r.height);
                                    if (r.opacity && r.opacity < 1)
                                        p.push("прозрачность " + Math.round(r.opacity * 100) + "%");
                                    if (r.noBlur)
                                        p.push("без размытия");
                                    if (r.opaque)
                                        p.push("непрозрачное");
                                    return p.length ? p.join(" · ") : "Нажми, чтобы настроить";
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
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            icon: "apps"
                            placeholder: "Класс окна (app_id)"
                            text: rule.modelData.cls ?? ""
                            onAccepted: page.saveRule(rule.index, {
                                cls: text
                            })
                            input.onEditingFinished: page.saveRule(rule.index, {
                                cls: text
                            })
                        }
                        TextField {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            icon: "title"
                            placeholder: "Заголовок (необязательно)"
                            text: rule.modelData.title ?? ""
                            input.onEditingFinished: page.saveRule(rule.index, {
                                title: text
                            })
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [
                                {
                                    key: "float",
                                    label: "Плавающее",
                                    icon: "picture_in_picture"
                                },
                                {
                                    key: "center",
                                    label: "По центру",
                                    icon: "center_focus_weak"
                                },
                                {
                                    key: "pin",
                                    label: "На всех столах",
                                    icon: "push_pin"
                                },
                                {
                                    key: "fullscreen",
                                    label: "На весь экран",
                                    icon: "fullscreen"
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
                            ]
                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool on: !!rule.modelData[modelData.key]
                                implicitHeight: 36
                                implicitWidth: chipRow.implicitWidth + 24
                                radius: Theme.radius.s
                                color: on ? Theme.secondaryContainer : "transparent"
                                border.width: on ? 0 : 1
                                border.color: Theme.outlineVariant
                                RowLayout {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    MIcon {
                                        icon: chip.on ? "check" : chip.modelData.icon
                                        size: 18
                                        color: chip.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                                    }
                                    MText {
                                        text: chip.modelData.label
                                        size: Theme.type.labelL
                                        color: chip.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                                    }
                                }
                                StateLayer {
                                    onClicked: page.saveRule(rule.index, {
                                        [chip.modelData.key]: !chip.on
                                    })
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            Layout.preferredWidth: 150
                            implicitHeight: 48
                            icon: "space_dashboard"
                            placeholder: "Стол"
                            text: rule.modelData.workspace ?? ""
                            input.onEditingFinished: page.saveRule(rule.index, {
                                workspace: text
                            })
                        }
                        TextField {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            icon: "aspect_ratio"
                            placeholder: "Ширина"
                            text: rule.modelData.width ?? ""
                            input.onEditingFinished: page.saveRule(rule.index, {
                                width: text
                            })
                        }
                        TextField {
                            Layout.fillWidth: true
                            implicitHeight: 48
                            placeholder: "Высота"
                            text: rule.modelData.height ?? ""
                            input.onEditingFinished: page.saveRule(rule.index, {
                                height: text
                            })
                        }
                    }
                    SegmentedButtons {
                        Layout.fillWidth: true
                        visible: Quickshell.screens.length > 1
                        options: [
                            {
                                value: "",
                                label: "Любой монитор"
                            },
                            ...Quickshell.screens.map(s => ({
                                        value: s.name,
                                        label: s.name
                                    }))
                        ]
                        current: rule.modelData.monitor ?? ""
                        onSelected: v => page.saveRule(rule.index, {
                            monitor: v
                        })
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

        ChoiceItem {
            icon: "add"
            title: "Добавить правило для открытого окна"
            options: [
                {
                    value: "",
                    label: "Пустое правило — впишу класс сам"
                },
                ...page.openClasses.map(c => ({
                            value: c,
                            label: (Apps.forWindow(c)?.name ?? c) + "  ·  " + c
                        }))
            ]
            current: undefined
            onSelected: v => {
                Settings.data.userRules = [...page.rules, {
                        cls: v,
                        float: true,
                        center: true
                    }];
                page.editing = page.rules.length - 1;
            }
        }
    }
}
