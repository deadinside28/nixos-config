import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Система"
    description: "Параметры NixOS. Изменения копятся в system.json в конфиге и вступают в силу после «Применить» — система пересоберётся, как nixos-rebuild switch."

    property var timezones: []
    property var pkgResults: []
    property bool pkgSearching: false
    property var flatResults: []
    property bool flatSearching: false

    Component.onCompleted: {
        tz.running = true;
        SystemConfig.refreshGenerations();
    }

    Process {
        id: tz
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector {
            onStreamFinished: page.timezones = text.split("\n").filter(t => t)
        }
    }

    Process {
        id: pkgSearch
        property string q
        command: ["nix", "search", "nixpkgs", q, "--json", "--quiet"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.pkgSearching = false;
                try {
                    const o = JSON.parse(text);
                    page.pkgResults = Object.keys(o).map(k => ({
                                attr: k.split(".").slice(2).join("."),
                                version: o[k].version,
                                description: o[k].description
                            })).sort((a, b) => (a.attr === pkgSearch.q ? -1 : 0) - (b.attr === pkgSearch.q ? -1 : 0) || a.attr.length - b.attr.length).slice(0, 25);
                } catch (e) {
                    page.pkgResults = [];
                }
            }
        }
    }
    Process {
        id: flatSearch
        property string q
        command: ["flatpak", "search", "--columns=application,name,description", q]
        stdout: StdioCollector {
            onStreamFinished: {
                page.flatSearching = false;
                page.flatResults = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [id, name, description] = l.split("\t");
                    return {
                        id,
                        name,
                        description
                    };
                }).slice(0, 20);
            }
        }
    }

    // system.json не разобрался — правки отключены, пока файл не исправлен
    Rectangle {
        Layout.fillWidth: true
        visible: SystemConfig.parseError !== ""
        implicitHeight: parseCol.implicitHeight + 40
        radius: Theme.radius.xl
        color: Theme.errorContainer
        ColumnLayout {
            id: parseCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 4
            MText {
                Layout.fillWidth: true
                text: "system.json не читается — изменения здесь не сохраняются"
                size: Theme.type.titleS
                weight: Theme.strongWeight
                color: Theme.fgErrorContainer
                wrapMode: Text.Wrap
            }
            MText {
                Layout.fillWidth: true
                text: SystemConfig.path + ": " + SystemConfig.parseError
                color: Theme.fgErrorContainer
                wrapMode: Text.Wrap
            }
        }
    }

    // --- Состояние: изменения / сборка ------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: SystemConfig.pending || SystemConfig.status !== "idle"
        implicitHeight: statusCol.implicitHeight + 40
        radius: Theme.radius.xl
        color: SystemConfig.status === "failed" ? Theme.errorContainer : SystemConfig.status === "success" && !SystemConfig.pending ? Theme.tertiaryContainer : Theme.primaryContainer
        readonly property color fg: SystemConfig.status === "failed" ? Theme.fgErrorContainer : SystemConfig.status === "success" && !SystemConfig.pending ? Theme.fgTertiaryContainer : Theme.fgPrimaryContainer

        id: banner

        ColumnLayout {
            id: statusCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                MIcon {
                    icon: SystemConfig.status === "running" ? "progress_activity" : SystemConfig.status === "failed" ? "error" : SystemConfig.status === "success" && !SystemConfig.pending ? "check_circle" : "pending"
                    size: 28
                    fill: 1
                    color: banner.fg
                    RotationAnimation on rotation {
                        running: SystemConfig.status === "running"
                        from: 0
                        to: 360
                        duration: 1200
                        loops: Animation.Infinite
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    MText {
                        Layout.fillWidth: true
                        text: SystemConfig.status === "running" ? SystemConfig.task : SystemConfig.status === "failed" ? SystemConfig.task + ": не получилось" : SystemConfig.status === "success" && !SystemConfig.pending ? SystemConfig.task + ": готово" : "Есть неприменённые изменения"
                        size: Theme.type.titleM
                        weight: Theme.strongWeight
                        color: banner.fg
                    }
                    MText {
                        Layout.fillWidth: true
                        text: SystemConfig.status === "idle" || (SystemConfig.status === "success" && SystemConfig.pending) ? "Сборка займёт от минуты; пароль спросят перед переключением" : SystemConfig.stage
                        color: banner.fg
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // прогресс M3: сразу после нажатия — бегущая полоса, на сборке —
            // реальный процент по событиям Nix
            RowLayout {
                Layout.fillWidth: true
                visible: SystemConfig.running
                spacing: 12
                LinearProgress {
                    Layout.fillWidth: true
                    thickness: 6
                    value: SystemConfig.progress
                    color: banner.fg
                    trackColor: Theme.alpha(banner.fg, 0.2)
                }
                MText {
                    visible: SystemConfig.progress >= 0
                    text: Math.round(SystemConfig.progress * 100) + "%"
                    color: banner.fg
                    weight: Theme.strongWeight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Button {
                    visible: SystemConfig.status !== "idle"
                    variant: "text"
                    icon: "terminal"
                    text: "Подробности и лог"
                    onClicked: Ui.updateWindowOpen = true
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    visible: SystemConfig.status === "running"
                    variant: "tonal"
                    text: "Остановить"
                    onClicked: SystemConfig.cancel()
                }
                Button {
                    visible: SystemConfig.pending && SystemConfig.status !== "running"
                    variant: "text"
                    text: "Отменить изменения"
                    onClicked: SystemConfig.revert()
                }
                Button {
                    visible: SystemConfig.pending && SystemConfig.status !== "running"
                    icon: "deployed_code_update"
                    text: "Применить"
                    onClicked: SystemConfig.rebuild("switch")
                }
            }
        }
    }

    // --- Время и язык ------------------------------------------------------
    Group {
        title: "Время и язык"
        ChoiceItem {
            icon: "schedule"
            title: "Часовой пояс"
            options: page.timezones
            current: SystemConfig.get("timeZone", "")
            maxVisible: 7
            onSelected: v => SystemConfig.set("timeZone", v)
        }
        ChoiceItem {
            icon: "translate"
            title: "Язык системы"
            options: [
                {
                    value: "ru_RU.UTF-8",
                    label: "Русский"
                },
                {
                    value: "en_US.UTF-8",
                    label: "English (US)"
                },
                {
                    value: "en_GB.UTF-8",
                    label: "English (UK)"
                },
                {
                    value: "uk_UA.UTF-8",
                    label: "Українська"
                },
                {
                    value: "be_BY.UTF-8",
                    label: "Беларуская"
                },
                {
                    value: "kk_KZ.UTF-8",
                    label: "Қазақ тілі"
                },
                {
                    value: "de_DE.UTF-8",
                    label: "Deutsch"
                }
            ]
            current: SystemConfig.get("locale", "ru_RU.UTF-8")
            onSelected: v => SystemConfig.set("locale", v)
        }
    }

    // --- Службы ------------------------------------------------------------
    Group {
        title: "Службы и оборудование"
        Repeater {
            model: [
                {
                    key: "services.bluetooth",
                    icon: "bluetooth",
                    title: "Bluetooth",
                    sub: "Служба BlueZ для наушников, геймпадов и прочего"
                },
                {
                    key: "services.printing",
                    icon: "print",
                    title: "Печать",
                    sub: "CUPS — принтеры и сканеры"
                },
                {
                    key: "services.avahi",
                    icon: "lan",
                    title: "Обнаружение в локальной сети",
                    sub: "Avahi/mDNS: принтеры, имена .local, Chromecast"
                },
                {
                    key: "services.docker",
                    icon: "deployed_code",
                    title: "Docker",
                    sub: "Контейнеры (нужны WinBoat и distrobox)"
                },
                {
                    key: "services.sunshine",
                    icon: "cast",
                    title: "Sunshine",
                    sub: "Стриминг игр на другие устройства через Moonlight"
                },
                {
                    key: "services.scx",
                    icon: "memory",
                    title: "Планировщик sched-ext",
                    sub: "Отзывчивость под нагрузкой, особенно в играх"
                },
                {
                    key: "services.plymouth",
                    icon: "animation",
                    title: "Заставка при загрузке",
                    sub: "Plymouth с логотипом производителя"
                },
                {
                    key: "services.zram",
                    icon: "compress",
                    title: "Сжатая подкачка в памяти (zram)",
                    sub: "Больше свободной ОЗУ под тяжёлые игры и браузер"
                }
            ]
            SwitchItem {
                required property var modelData
                icon: modelData.icon
                title: modelData.title
                subtitle: modelData.sub
                checked: SystemConfig.get(modelData.key, false)
                onToggled: v => SystemConfig.set(modelData.key, v)
            }
        }
    }

    Group {
        title: "Игры"
        Repeater {
            model: [
                {
                    key: "gaming.steam",
                    icon: "sports_esports",
                    title: "Steam",
                    sub: "С Remote Play и сессией Gamescope"
                },
                {
                    key: "gaming.gamescope",
                    icon: "fullscreen",
                    title: "Gamescope",
                    sub: "Микрокомпозитор для игр: масштабирование, HDR, ограничение FPS"
                },
                {
                    key: "gaming.gamemode",
                    icon: "speed",
                    title: "GameMode",
                    sub: "Режим производительности на время игры"
                }
            ]
            SwitchItem {
                required property var modelData
                icon: modelData.icon
                title: modelData.title
                subtitle: modelData.sub
                checked: SystemConfig.get(modelData.key, false)
                onToggled: v => SystemConfig.set(modelData.key, v)
            }
        }
    }

    // --- Пакеты -------------------------------------------------------------
    Group {
        title: "Дополнительные пакеты (nixpkgs)"

        Repeater {
            model: SystemConfig.get("extraPackages", [])
            ListItem {
                id: pk
                required property string modelData
                icon: "package_2"
                title: modelData
                clickable: false
                IconButton {
                    icon: "delete"
                    onClicked: SystemConfig.removeFrom("extraPackages", pk.modelData)
                }
            }
        }

        SearchCard {
            placeholder: "Найти пакет в nixpkgs, например «obs-studio»"
            busy: page.pkgSearching
            hint: "Первый поиск может занять до минуты — Nix индексирует nixpkgs"
            onSearch: q => {
                page.pkgSearching = true;
                pkgSearch.q = q;
                pkgSearch.running = true;
            }
            results: page.pkgResults.map(r => ({
                        id: r.attr,
                        title: r.attr + (r.version ? "  " + r.version : ""),
                        subtitle: r.description ?? "",
                        added: SystemConfig.get("extraPackages", []).includes(r.attr)
                    }))
            onAdd: id => SystemConfig.addTo("extraPackages", id)
        }
    }

    Group {
        title: "Flatpak (Flathub)"

        Repeater {
            model: SystemConfig.get("flatpaks", [])
            ListItem {
                id: fp
                required property string modelData
                icon: "shopping_bag"
                title: modelData
                clickable: false
                IconButton {
                    icon: "delete"
                    onClicked: SystemConfig.removeFrom("flatpaks", fp.modelData)
                }
            }
        }
        SwitchItem {
            icon: "update"
            title: "Обновлять Flatpak раз в неделю"
            checked: SystemConfig.get("flatpakAutoUpdate", true)
            onToggled: v => SystemConfig.set("flatpakAutoUpdate", v)
        }
        SearchCard {
            placeholder: "Найти приложение на Flathub"
            busy: page.flatSearching
            onSearch: q => {
                page.flatSearching = true;
                flatSearch.q = q;
                flatSearch.running = true;
            }
            results: page.flatResults.map(r => ({
                        id: r.id,
                        title: r.name,
                        subtitle: r.id + (r.description ? " — " + r.description : ""),
                        added: SystemConfig.get("flatpaks", []).includes(r.id)
                    }))
            onAdd: id => SystemConfig.addTo("flatpaks", id)
        }
    }

    // --- Сеть ----------------------------------------------------------------
    Group {
        title: "Брандмауэр"
        PortsItem {
            title: "Открытые TCP-порты"
            key: "firewall.tcp"
        }
        PortsItem {
            title: "Открытые UDP-порты"
            key: "firewall.udp"
        }
    }

    // --- Обслуживание ---------------------------------------------------------
    Group {
        title: "Обслуживание Nix"
        SwitchItem {
            icon: "auto_delete"
            title: "Автоматически удалять старые поколения"
            subtitle: "Раз в неделю: всё старше " + SystemConfig.get("nix.gcDays", 14) + " дней"
            checked: SystemConfig.get("nix.autoGc", true)
            onToggled: v => SystemConfig.set("nix.autoGc", v)
        }
        ChoiceItem {
            icon: "date_range"
            title: "Хранить поколения"
            options: [3, 7, 14, 30, 60].map(d => ({
                        value: d,
                        label: d + " дней"
                    }))
            current: SystemConfig.get("nix.gcDays", 14)
            onSelected: v => SystemConfig.set("nix.gcDays", v)
        }
        SwitchItem {
            icon: "compress"
            title: "Дедупликация хранилища"
            subtitle: "nix.optimise: одинаковые файлы хранятся один раз"
            checked: SystemConfig.get("nix.autoOptimise", true)
            onToggled: v => SystemConfig.set("nix.autoOptimise", v)
        }
    }

    Group {
        title: "Действия"
        ListItem {
            icon: "system_update_alt"
            title: "Обновить систему"
            subtitle: "nix flake update + пересборка: свежие пакеты, ядро и драйверы"
            disabled: SystemConfig.status === "running"
            chevron: true
            onClicked: SystemConfig.updateAndRebuild()
        }
        ListItem {
            icon: "build"
            title: "Проверить сборку"
            subtitle: "Собрать, но не переключаться — убедиться, что конфиг без ошибок"
            disabled: SystemConfig.status === "running"
            chevron: true
            onClicked: SystemConfig.rebuild("build")
        }
        ListItem {
            icon: "restart_alt"
            title: "Применить при следующей загрузке"
            subtitle: "nixos-rebuild boot: безопаснее для смены ядра и драйверов"
            disabled: SystemConfig.status === "running"
            chevron: true
            onClicked: SystemConfig.rebuild("boot")
        }
        ListItem {
            icon: "cleaning_services"
            title: "Очистить старые поколения"
            subtitle: "Удалить поколения старше " + SystemConfig.get("nix.gcDays", 14) + " дней и мусор в /nix/store"
            disabled: SystemConfig.status === "running"
            chevron: true
            onClicked: SystemConfig.collectGarbage()
        }
        ListItem {
            icon: "folder_code"
            title: "Открыть конфиг в редакторе"
            subtitle: Nix.flake.replace(Settings.home, "~")
            chevron: true
            onClicked: Apps.run(["zeditor", Nix.flake])
        }
    }

    Group {
        title: "Поколения системы"
        Repeater {
            model: SystemConfig.generations.slice(0, 8)
            ListItem {
                required property var modelData
                icon: modelData.current ? "radio_button_checked" : "history"
                title: "Поколение " + modelData.number + (modelData.current ? " · текущее" : "")
                subtitle: modelData.date.toLocaleString(Qt.locale("ru_RU"), "d MMMM yyyy, HH:mm")
                clickable: false
                selected: modelData.current
            }
        }
        ListItem {
            icon: "undo"
            title: "Откатиться на предыдущее поколение"
            subtitle: "Если после обновления что-то сломалось"
            disabled: SystemConfig.status === "running" || SystemConfig.generations.length < 2
            onClicked: SystemConfig.rollback()
        }
    }

    // Поиск с результатами и кнопкой «добавить»
    component SearchCard: Rectangle {
        id: sc
        readonly property bool groupItem: true
        property bool first: false
        property bool last: true
        property string placeholder
        property string hint: ""
        property bool busy: false
        property var results: []
        signal search(string q)
        signal add(string id)

        Layout.fillWidth: true
        implicitHeight: scCol.implicitHeight + 24
        color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
        topLeftRadius: first ? 24 : 4
        topRightRadius: first ? 24 : 4
        bottomLeftRadius: last ? 24 : 4
        bottomRightRadius: last ? 24 : 4

        ColumnLayout {
            id: scCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 4
            TextField {
                id: field
                Layout.fillWidth: true
                implicitHeight: 48
                icon: sc.busy ? "hourglass_top" : "search"
                placeholder: sc.placeholder
                onAccepted: if (text.trim().length >= 2)
                    sc.search(text.trim())
            }
            MText {
                visible: sc.busy && sc.hint !== ""
                Layout.leftMargin: 16
                text: sc.hint
                size: Theme.type.bodyS
                color: Theme.fgSurfaceVariant
            }
            Repeater {
                model: sc.results
                Rectangle {
                    id: res
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 60
                    radius: Theme.radius.l
                    color: "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 8
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            MText {
                                Layout.fillWidth: true
                                text: res.modelData.title
                            }
                            MText {
                                Layout.fillWidth: true
                                text: res.modelData.subtitle
                                size: Theme.type.bodyS
                                color: Theme.fgSurfaceVariant
                            }
                        }
                        IconButton {
                            icon: res.modelData.added ? "check" : "add"
                            variant: res.modelData.added ? "standard" : "tonal"
                            onClicked: if (!res.modelData.added)
                                sc.add(res.modelData.id)
                        }
                    }
                }
            }
        }
    }

    component PortsItem: ListItem {
        id: pi
        property string key
        icon: "shield"
        clickable: false
        subtitle: "Через запятую"
        TextField {
            implicitWidth: 220
            implicitHeight: 44
            text: SystemConfig.get(pi.key, []).join(", ")
            onAccepted: SystemConfig.set(pi.key, text.split(/[,\s]+/).map(Number).filter(n => n > 0 && n < 65536))
        }
    }
}
