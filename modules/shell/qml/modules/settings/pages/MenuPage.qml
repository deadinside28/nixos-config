import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

// Меню приложений: вид лаунчера и правки отдельных записей. Правки ложатся
// поверх .desktop (services/Apps.qml) и переживают обновление пакетов.
SettingsPage {
    id: page
    title: "Меню приложений"
    description: "Папки, названия и значки, скрытие ненужного и параметры запуска. Сами файлы приложений не меняются — правки хранятся отдельно и переживают обновления."

    property string filter: ""
    property string editing: ""
    readonly property var shown: {
        const q = filter.trim().toLowerCase();
        const list = q ? Apps.everything.filter(a => (a.name + " " + a.id + " " + (a.origin ?? "") + " " + a.folder).toLowerCase().includes(q)) : Apps.everything;
        return list.slice(0, 80);
    }

    // Поле с подписью; сохраняет по Enter и при уходе фокуса
    component EditField: ColumnLayout {
        id: ef
        property string label
        property string value
        property string placeholder: ""
        signal commit(string value)
        Layout.fillWidth: true
        spacing: 4
        MText {
            Layout.leftMargin: 8
            text: ef.label
            size: Theme.type.labelL
            color: Theme.fgSurfaceVariant
        }
        TextField {
            id: efField
            Layout.fillWidth: true
            implicitHeight: 48
            text: ef.value
            placeholder: ef.placeholder
            onAccepted: ef.commit(text.trim())
            Connections {
                target: efField.input
                function onActiveFocusChanged() {
                    if (!efField.input.activeFocus && efField.text.trim() !== ef.value)
                        ef.commit(efField.text.trim());
                }
            }
        }
    }

    // --- Вид ---------------------------------------------------------------
    Group {
        title: "Вид лаунчера"
        ChoiceItem {
            first: true
            last: false
            icon: "sort"
            title: "Порядок приложений"
            options: [
                {
                    value: "name",
                    label: "По алфавиту"
                },
                {
                    value: "usage",
                    label: "Частые первыми"
                }
            ]
            current: Settings.data.launcherSort
            onSelected: v => Settings.data.launcherSort = v
        }
        SliderItem {
            first: false
            last: false
            icon: "view_column"
            title: "Колонок в сетке"
            valueText: String(Settings.data.launcherColumns)
            from: 3
            to: 10
            stepSize: 1
            value: Settings.data.launcherColumns
            onMoved: v => Settings.data.launcherColumns = Math.round(v)
        }
        SliderItem {
            first: false
            last: false
            icon: "photo_size_select_large"
            title: "Размер значков"
            valueText: Settings.data.launcherIconSize + " px"
            from: 32
            to: 72
            stepSize: 4
            value: Settings.data.launcherIconSize
            onMoved: v => Settings.data.launcherIconSize = Math.round(v)
        }
        SwitchItem {
            first: false
            last: true
            icon: "label"
            title: "Подписи под значками"
            checked: Settings.data.launcherLabels
            onToggled: v => Settings.data.launcherLabels = v
        }
    }

    // --- Записи --------------------------------------------------------------
    Group {
        title: "Приложения"
        TextField {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            icon: "search"
            placeholder: "Найти: название, ID, источник или папка"
            onTextChanged: page.filter = text
        }
        Repeater {
            model: page.shown
            ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var app: modelData
                readonly property bool open: page.editing === app.id
                readonly property var ov: app.custom ? (Settings.data.customApps ?? []).find(c => c.id === app.id) ?? {} : Apps.override(app.id)
                // правка поля: свои команды — в customApps, остальное — поверх .desktop
                function put(key, value) {
                    if (app.custom)
                        Apps.setCustom(app.id, key, value);
                    else
                        Apps.setOverride(app.id, key, value);
                }
                Layout.fillWidth: true
                spacing: 2

                AppListItem {
                    first: row.index === 0
                    last: row.index === page.shown.length - 1 && !row.open
                    appIcon: row.app.icon || "application-x-executable"
                    title: row.app.name
                    subtitle: [row.app.origin, row.app.folder ? "папка «" + row.app.folder + "»" : "", row.app.hidden ? "скрыто" : "", row.app.edited && !row.app.custom ? "изменено" : ""].filter(s => s).join(" · ") || row.app.id
                    opacity: row.app.hidden ? 0.6 : 1
                    selected: row.open
                    onClicked: page.editing = row.open ? "" : row.app.id
                    MIcon {
                        icon: row.open ? "expand_less" : "expand_more"
                        color: Theme.fgSurfaceVariant
                    }
                }

                // Правка записи
                Rectangle {
                    visible: row.open
                    Layout.fillWidth: true
                    implicitHeight: edCol.implicitHeight + 32
                    color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                    radius: 4
                    bottomLeftRadius: row.index === page.shown.length - 1 ? 24 : 4
                    bottomRightRadius: row.index === page.shown.length - 1 ? 24 : 4
                    ColumnLayout {
                        id: edCol
                        x: 20
                        y: 16
                        width: parent.width - 40
                        spacing: 12

                        MText {
                            Layout.fillWidth: true
                            visible: !row.app.custom
                            text: "ID: " + row.app.id + "\nКоманда из файла: " + (row.app.execString ?? "")
                            size: Theme.type.bodyS
                            color: Theme.fgSurfaceVariant
                            wrapMode: Text.WrapAnywhere
                        }
                        EditField {
                            label: "Название"
                            value: row.ov.name ?? ""
                            placeholder: row.app.entry?.name ?? ""
                            onCommit: v => row.put("name", v)
                        }
                        EditField {
                            label: "Значок — имя из темы или путь к файлу"
                            value: row.ov.icon ?? ""
                            placeholder: row.app.entry?.icon ?? "application-x-executable"
                            onCommit: v => row.put("icon", v)
                        }
                        EditField {
                            visible: row.app.custom
                            label: "Команда"
                            value: row.ov.command ?? ""
                            placeholder: "программа --аргумент \"с пробелами\""
                            onCommit: v => row.put("command", v)
                        }
                        EditField {
                            label: "Папка в лаунчере"
                            value: row.ov.folder ?? ""
                            placeholder: Apps.folders.length ? "например, " + Apps.folders.join(", ") : "без папки"
                            onCommit: v => row.put("folder", v)
                        }
                        EditField {
                            label: "Дополнительные слова для поиска"
                            value: row.ov.keywords ?? ""
                            placeholder: "через пробел или запятую"
                            onCommit: v => row.put("keywords", v)
                        }
                        EditField {
                            visible: !row.app.custom
                            label: "Дополнительные аргументы — в конец команды"
                            value: row.ov.args ?? ""
                            placeholder: "--ozone-platform=wayland"
                            onCommit: v => row.put("args", v)
                        }
                        EditField {
                            label: "Переменные окружения"
                            value: row.ov.env ?? ""
                            placeholder: "ИМЯ=значение ДРУГОЕ=\"с пробелами\""
                            onCommit: v => row.put("env", v)
                        }
                        EditField {
                            label: "Рабочая папка"
                            value: row.ov.cwd ?? ""
                            placeholder: row.app.entry?.workingDirectory || "домашняя"
                            onCommit: v => row.put("cwd", v)
                        }
                        SegmentedButtons {
                            Layout.fillWidth: true
                            options: row.app.custom ? [
                                {
                                    value: false,
                                    label: "Обычное окно"
                                },
                                {
                                    value: true,
                                    label: "В терминале"
                                }
                            ] : [
                                {
                                    value: "",
                                    label: "Как в файле"
                                },
                                {
                                    value: "no",
                                    label: "Обычное окно"
                                },
                                {
                                    value: "yes",
                                    label: "В терминале"
                                }
                            ]
                            current: row.app.custom ? !!row.ov.terminal : (row.ov.terminal ?? "")
                            onSelected: v => row.put("terminal", v)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Button {
                                variant: "tonal"
                                icon: "play_arrow"
                                text: "Запустить"
                                onClicked: Apps.launch(Apps.byId(row.app.id))
                            }
                            Button {
                                variant: "tonal"
                                icon: row.app.hidden ? "visibility" : "visibility_off"
                                text: row.app.hidden ? "Показывать" : "Скрыть из меню"
                                onClicked: row.put("hidden", !row.app.hidden)
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Button {
                                visible: !row.app.custom && row.app.edited
                                variant: "text"
                                icon: "restart_alt"
                                text: "Как в файле"
                                onClicked: Apps.resetOverride(row.app.id)
                            }
                            Button {
                                visible: row.app.custom
                                variant: "text"
                                icon: "delete"
                                text: "Удалить"
                                onClicked: {
                                    page.editing = "";
                                    Apps.removeCustom(row.app.id);
                                }
                            }
                        }
                    }
                }
            }
        }
        ListItem {
            visible: page.shown.length === 0
            icon: "search_off"
            title: "Ничего не нашлось"
            clickable: false
        }
    }

    // --- Своя команда ----------------------------------------------------------
    Group {
        title: "Своя команда"
        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: true
            Layout.fillWidth: true
            implicitHeight: addCol.implicitHeight + 32
            radius: 24
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            ColumnLayout {
                id: addCol
                x: 20
                y: 16
                width: parent.width - 40
                spacing: 12
                MText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.fgSurfaceVariant
                    text: "Любая команда как пункт меню. Запускается без shell: слова делятся пробелами, кавычки объединяют."
                }
                TextField {
                    id: newName
                    Layout.fillWidth: true
                    implicitHeight: 48
                    placeholder: "Название"
                }
                TextField {
                    id: newCmd
                    Layout.fillWidth: true
                    implicitHeight: 48
                    placeholder: "Команда, например: kitty --hold htop"
                    onAccepted: addBtn.clicked()
                }
                Button {
                    id: addBtn
                    icon: "add"
                    text: "Добавить в меню"
                    disabled: newCmd.text.trim() === ""
                    onClicked: {
                        if (newCmd.text.trim() === "")
                            return;
                        page.editing = Apps.addCustom(newName.text.trim(), newCmd.text.trim());
                        newName.text = "";
                        newCmd.text = "";
                    }
                }
            }
        }
    }
}
