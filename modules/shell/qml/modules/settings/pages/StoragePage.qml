import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

// «Память»: место на диске. Подсчёт — services/Storage.qml.
SettingsPage {
    id: page
    title: "Память"
    description: "Чем занят диск: приложения, их данные и кеш, система и твои файлы. Это место на диске, а не оперативная память."

    Component.onCompleted: if (Storage.measuredAt.getTime() === 0)
        Storage.refresh()

    readonly property var ov: Storage.overview
    readonly property real total: ov.disk?.[0] ?? 0
    readonly property real free: ov.disk?.[1] ?? 0
    function size(b) {
        return b > 0 ? Files.humanSize(b) : "—";
    }

    property string filter: ""
    property string open: ""
    readonly property var apps: {
        const sizes = Storage.appSizes;
        const q = filter.trim().toLowerCase();
        return Apps.everything.filter(a => !a.custom && (!q || a.name.toLowerCase().includes(q))).sort((a, b) => (sizes[b.id]?.own ?? -1) - (sizes[a.id]?.own ?? -1) || a.name.localeCompare(b.name));
    }

    // --- Диск ---------------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: diskCol.implicitHeight + 40
        radius: Theme.radius.xl
        color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
        ColumnLayout {
            id: diskCol
            x: 20
            y: 20
            width: parent.width - 40
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                MText {
                    Layout.fillWidth: true
                    text: page.total ? "Занято " + Files.humanSize(page.total - page.free) + " из " + Files.humanSize(page.total) : "Считаю…"
                    size: Theme.type.titleL
                    weight: Theme.strongWeight
                }
                Button {
                    variant: "tonal"
                    icon: Storage.measuring ? "stop" : "refresh"
                    text: Storage.measuring ? "Остановить" : "Пересчитать"
                    onClicked: Storage.measuring ? Storage.cancel() : Storage.refresh()
                }
            }
            LinearProgress {
                Layout.fillWidth: true
                value: page.total ? (page.total - page.free) / page.total : 0
            }
            MText {
                Layout.fillWidth: true
                color: Theme.fgSurfaceVariant
                size: Theme.type.bodyS
                text: (page.total ? "Свободно " + Files.humanSize(page.free) + ". " : "") + (Storage.measuring ? "Ещё считаю — числа уточняются." : Storage.measuredAt.getTime() > 0 ? "Посчитано " + Files.humanDate(Storage.measuredAt) + "." : "") + (page.ov.homedisk ? " Домашняя папка на отдельном разделе: свободно " + Files.humanSize(page.ov.homedisk[1]) + " из " + Files.humanSize(page.ov.homedisk[0]) + "." : "")
                wrapMode: Text.WordWrap
            }
        }
    }

    // --- Категории ------------------------------------------------------------
    Group {
        title: "По категориям"
        ListItem {
            first: true
            last: false
            icon: "deployed_code"
            title: "Система"
            subtitle: "Текущая версия NixOS со всеми зависимостями: " + page.size(page.ov.system?.[0] ?? 0) + ". Сохранённых версий для отката: " + (page.ov.generations?.[0] ?? 0)
            clickable: false
            Button {
                variant: "text"
                text: "Удалить старые"
                disabled: SystemConfig.running
                onClicked: SystemConfig.collectGarbage()
            }
        }
        ListItem {
            first: false
            last: false
            icon: "inventory_2"
            title: "Приложения Flatpak и их среды"
            subtitle: page.size(page.ov.flatpak?.[0] ?? 0) + " — среды выполнения общие для нескольких приложений"
            clickable: false
        }
        ListItem {
            first: false
            last: false
            icon: "folder_data"
            title: "Данные приложений Flatpak"
            subtitle: page.size(page.ov.appdata?.[0] ?? 0) + " в ~/.var/app"
            clickable: false
        }
        ListItem {
            first: false
            last: false
            icon: "cached"
            title: "Кеш"
            subtitle: page.size(page.ov.cache?.[0] ?? 0) + " в ~/.cache — программы создадут его заново"
            onClicked: Files.open(Settings.home + "/.cache")
            chevron: true
        }
        ListItem {
            first: false
            last: false
            icon: "delete"
            title: "Корзина"
            subtitle: page.size(page.ov.trash?.[0] ?? 0)
            clickable: false
            Button {
                variant: "text"
                text: "Очистить"
                disabled: (page.ov.trash?.[0] ?? 0) === 0
                onClicked: {
                    Files.emptyTrash();
                    Qt.callLater(Storage.refresh);
                }
            }
        }
        ListItem {
            first: false
            last: true
            icon: "home"
            title: "Домашняя папка целиком"
            subtitle: page.size(page.ov.home?.[0] ?? 0) + " — файлы, настройки, данные, кеш и корзина вместе"
            onClicked: Files.open(Settings.home)
            chevron: true
        }
    }

    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        wrapMode: Text.WordWrap
        color: Theme.fgSurfaceVariant
        size: Theme.type.bodyS
        text: "Удалённая из конфигурации программа остаётся на диске, пока её держит сохранённая версия системы для отката. Место освобождается после «Удалить старые»."
    }

    // --- Приложения ---------------------------------------------------------------
    Group {
        title: "Приложения"
        TextField {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            icon: "search"
            placeholder: "Найти приложение"
            onTextChanged: page.filter = text
        }
        Repeater {
            model: page.apps.slice(0, 60)
            ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var app: modelData
                readonly property var sz: Storage.appSizes[app.id] ?? {}
                readonly property var paths: Storage.pathsFor(app)
                readonly property bool isOpen: page.open === app.id
                readonly property var plan: Storage.uninstallPlan(app)
                readonly property bool last: index === Math.min(59, page.apps.length - 1)
                Layout.fillWidth: true
                spacing: 2

                AppListItem {
                    first: row.index === 0
                    last: row.last && !row.isOpen
                    appIcon: row.app.icon || "application-x-executable"
                    title: row.app.name
                    subtitle: (row.app.origin || "источник неизвестен") + (row.sz.own ? " · " + Files.humanSize(row.sz.own) : "")
                    selected: row.isOpen
                    onClicked: {
                        page.open = row.isOpen ? "" : row.app.id;
                        if (!row.isOpen && row.paths)
                            Storage.measurePaths([...new Set([...row.paths.data, ...row.paths.cache])]);
                    }
                    MIcon {
                        icon: row.isOpen ? "expand_less" : "expand_more"
                        color: Theme.fgSurfaceVariant
                    }
                }
                Rectangle {
                    visible: row.isOpen
                    Layout.fillWidth: true
                    implicitHeight: card.implicitHeight + 32
                    color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                    radius: 4
                    bottomLeftRadius: row.last ? 24 : 4
                    bottomRightRadius: row.last ? 24 : 4
                    ColumnLayout {
                        id: card
                        x: 20
                        y: 16
                        width: parent.width - 40
                        spacing: 8
                        MText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: Storage.kindOf(row.app) === "nix" ? "Пакет: " + page.size(row.sz.own ?? 0) + "\nВместе с зависимостями: " + page.size(row.sz.closure ?? 0) + " — часть их общая с другими программами, поэтому после удаления освободится меньше" : Storage.kindOf(row.app) === "flatpak" ? "Приложение: " + page.size(row.sz.own ?? 0) + " (без общей среды выполнения)" : "Размер программы неизвестен: источник не Nix и не Flatpak"
                        }
                        Repeater {
                            model: row.paths ? row.paths.data : []
                            MText {
                                required property var modelData
                                Layout.fillWidth: true
                                text: modelData.replace(Settings.home, "~") + " — " + page.size(Storage.pathSizes[modelData] ?? 0)
                                color: Theme.fgSurfaceVariant
                                size: Theme.type.bodyS
                                elide: Text.ElideMiddle
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: !row.paths
                            wrapMode: Text.WordWrap
                            color: Theme.fgSurfaceVariant
                            size: Theme.type.bodyS
                            text: "Где эта программа хранит данные, неизвестно — очистить их отсюда нельзя."
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: Storage.lastError !== "" && Storage.busyId === "" && row.isOpen
                            text: Storage.lastError
                            color: Theme.error
                            wrapMode: Text.WordWrap
                        }
                        MText {
                            Layout.fillWidth: true
                            visible: Storage.lastDone !== "" && row.isOpen
                            text: Storage.lastDone
                            color: Theme.primary
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 8
                            Button {
                                visible: !!row.paths && row.paths.cache.length > 0
                                variant: "tonal"
                                icon: "cleaning_services"
                                text: "Очистить кеш"
                                disabled: Storage.busyId !== ""
                                onClicked: Storage.clean(row.app, "cache")
                            }
                            Button {
                                id: resetBtn
                                visible: !!row.paths
                                property bool armed: false
                                variant: armed ? "danger" : "tonal"
                                icon: "restart_alt"
                                text: armed ? "Точно сбросить? Удалится всё выше" : "Сбросить данные"
                                disabled: Storage.busyId !== ""
                                onClicked: {
                                    if (!armed) {
                                        armed = true;
                                        return;
                                    }
                                    armed = false;
                                    Storage.clean(row.app, "data");
                                }
                            }
                            Button {
                                visible: !!row.paths
                                variant: "text"
                                icon: "folder_open"
                                text: "Открыть"
                                onClicked: Files.open(row.paths.data[0])
                            }
                            Button {
                                id: unBtn
                                visible: row.plan.how === "system" || row.plan.how === "flatpak"
                                property bool armed: false
                                variant: armed ? "danger" : "text"
                                icon: "delete"
                                text: armed ? "Точно удалить?" : "Удалить приложение"
                                disabled: Storage.busyId !== ""
                                onClicked: {
                                    if (!armed) {
                                        armed = true;
                                        return;
                                    }
                                    armed = false;
                                    Storage.uninstall(row.app);
                                }
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Theme.fgSurfaceVariant
                            size: Theme.type.bodyS
                            text: row.plan.how === "system" ? "Установлено через «Система»: удаление уберёт его из списка, применится после «Применить» там же. Данные приложения при этом останутся." : row.plan.how === "config" ? "Программа входит в конфигурацию системы (modules/system/packages.nix) — удалить её можно только там." : row.plan.how === "flatpak" ? "Установлено вручную; данные в ~/.var/app останутся — сбрось их отдельно." : ""
                        }
                    }
                }
            }
        }
    }
}
