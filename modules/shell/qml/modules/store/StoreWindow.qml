// Магазин — отдельное окно: каталог Nixpkgs, Chaotic-Nyx и Flatpak,
// установленное, обновления и история. Логика — services/Store.qml.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Scope {
    id: root

    LazyLoader {
        active: Ui.storeOpen

        FloatingWindow {
            id: win
            title: "Магазин"
            implicitWidth: 1080
            implicitHeight: 760
            minimumSize: Qt.size(760, 520)
            color: Theme.surfaceContainer
            visible: true
            onVisibleChanged: if (!visible)
                Ui.storeOpen = false
            Component.onCompleted: Store.prepare()

            property string tab: "catalog" // catalog | installed | updates | history

            Shortcut {
                sequence: "Escape"
                onActivated: search.text !== "" ? search.text = "" : Ui.storeOpen = false
            }
            Shortcut {
                sequence: "Ctrl+F"
                onActivated: search.forceFocus()
            }

            // Установленное: из system.json и фактически установленные Flatpak
            readonly property var installed: {
                const out = [];
                for (const id of SystemConfig.get("extraPackages", []).concat(SystemConfig.applied.extraPackages ?? []))
                    if (!out.some(x => x.id === id))
                        out.push({
                            source: "nixpkgs",
                            id,
                            name: id.split(".").pop(),
                            version: "",
                            description: "Nix-пакет из «Системы»"
                        });
                for (const ref of SystemConfig.get("flatpaks", []).map(f => f.split("//")[0]).concat(Store.flatpakInstalled))
                    if (!out.some(x => x.id === ref))
                        out.push({
                            source: "flatpak",
                            id: ref,
                            name: Apps.byId(ref)?.name ?? ref.split(".").pop(),
                            version: "",
                            description: ref
                        });
                return out;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    MText {
                        text: "Магазин"
                        size: Theme.type.headlineM
                    }
                    SegmentedButtons {
                        Layout.fillWidth: true
                        options: [
                            {
                                value: "catalog",
                                label: "Каталог",
                                icon: "storefront"
                            },
                            {
                                value: "installed",
                                label: "Установлено",
                                icon: "apps"
                            },
                            {
                                value: "updates",
                                label: "Обновления",
                                icon: "system_update"
                            },
                            {
                                value: "history",
                                label: "История",
                                icon: "history"
                            }
                        ]
                        current: win.tab
                        onSelected: v => win.tab = v
                    }
                }

                // --- Каталог ---------------------------------------------------
                ColumnLayout {
                    visible: win.tab === "catalog"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        icon: "search"
                        placeholder: "Поиск в Nixpkgs, Chaotic-Nyx и Flatpak"
                        onTextChanged: Store.search(text)
                        Component.onCompleted: forceFocus()
                    }
                    MText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        size: Theme.type.bodyS
                        color: Store.indexStatus === "failed" ? Theme.error : Theme.fgSurfaceVariant
                        text: Store.indexStatus === "building" ? "Готовлю каталог Nix по ревизиям из flake.lock — первый раз это несколько минут. Flatpak ищется уже сейчас." : Store.indexStatus === "failed" ? "Каталог Nix не построился — ищется только Flatpak. Проверь сеть и flake.lock." : "Пакеты Nix — ровно те версии, из которых собирается система: установка не обновляет flake.lock."
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        model: Store.results
                        delegate: StoreRow {
                            required property var modelData
                            width: ListView.view.width
                            item: modelData
                        }
                        MText {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: Store.searching ? "Ищу…" : Store.query.trim() ? "Ничего не нашлось" : "Найди приложение по названию или описанию"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }

                // --- Установлено -------------------------------------------------
                ListView {
                    visible: win.tab === "installed"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: win.installed
                    header: MText {
                        width: ListView.view.width
                        bottomPadding: 8
                        wrapMode: Text.WordWrap
                        size: Theme.type.bodyS
                        color: Theme.fgSurfaceVariant
                        text: "Здесь то, что поставлено через магазин или «Систему», и все Flatpak. Программы из конфигурации (modules/system/packages.nix) меняются там."
                    }
                    delegate: StoreRow {
                        required property var modelData
                        width: ListView.view.width
                        item: modelData
                    }
                }

                // --- Обновления --------------------------------------------------
                ColumnLayout {
                    visible: win.tab === "updates"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    Group {
                        title: "Система и пакеты Nix"
                        ListItem {
                            icon: "deployed_code_update"
                            title: "Обновить систему"
                            subtitle: "Обновит flake.lock (Nixpkgs, Nyx, рабочий стол) и пересоберёт систему. Отдельно от установки: установка нового пакета flake.lock не трогает."
                            clickable: false
                            Button {
                                text: "Обновить"
                                disabled: SystemConfig.running
                                onClicked: SystemConfig.updateAndRebuild()
                            }
                        }
                    }
                    Group {
                        title: "Flatpak"
                        ListItem {
                            icon: "inventory_2"
                            title: Store.flatpakUpdates.length ? "Доступны обновления: " + Store.flatpakUpdates.length : "Обновлений нет"
                            subtitle: Store.flatpakUpdates.length ? Store.flatpakUpdates.join(", ") : "Flatpak обновляется и сам раз в неделю (если включено в «Системе»). Список Flatpak в конфигурации не закрепляет версии — ставится текущая из remote."
                            clickable: false
                            Button {
                                visible: Store.flatpakUpdates.length > 0
                                text: "Обновить"
                                onClicked: {
                                    Apps.run([Nix.terminal, "--hold", "flatpak", "update"]);
                                }
                            }
                            IconButton {
                                icon: "refresh"
                                onClicked: Store.refreshFlatpaks()
                            }
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // --- История -------------------------------------------------------
                ListView {
                    visible: win.tab === "history"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: Store.history
                    header: ColumnLayout {
                        width: ListView.view.width
                        spacing: 8
                        Group {
                            title: "Версии системы"
                            Repeater {
                                model: SystemConfig.generations.slice(0, 5)
                                ListItem {
                                    required property var modelData
                                    icon: modelData.current ? "check_circle" : "history"
                                    title: "Версия " + modelData.number + (modelData.current ? " — текущая" : "")
                                    subtitle: Files.humanDate(modelData.date)
                                    clickable: false
                                }
                            }
                        }
                        MText {
                            visible: Store.history.length > 0
                            Layout.leftMargin: 20
                            text: "Действия в магазине"
                            color: Theme.primary
                            size: Theme.type.labelL
                        }
                    }
                    delegate: ListItem {
                        required property var modelData
                        width: ListView.view.width
                        icon: modelData.what.includes("удал") ? "remove_circle" : "add_circle"
                        title: modelData.what + ": " + modelData.id
                        subtitle: Store.sources[modelData.source] + " · " + Files.humanDate(modelData.at)
                        clickable: false
                    }
                }

                // --- Применение -----------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    visible: Store.pending.length > 0 || SystemConfig.running
                    implicitHeight: applyRow.implicitHeight + 24
                    radius: Theme.radius.xl
                    color: SystemConfig.status === "failed" ? Theme.errorContainer : Theme.primaryContainer
                    RowLayout {
                        id: applyRow
                        x: 16
                        y: 12
                        width: parent.width - 32
                        spacing: 12
                        MIcon {
                            icon: SystemConfig.running ? "progress_activity" : "pending_actions"
                            color: Theme.fgPrimaryContainer
                        }
                        MText {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Theme.fgPrimaryContainer
                            text: SystemConfig.running ? SystemConfig.task + ": " + SystemConfig.stage : "Ожидают применения: " + Store.pending.map(p => (p.add ? "+" : "−") + p.id).join(", ")
                        }
                        Button {
                            visible: !SystemConfig.running
                            variant: "text"
                            text: "Отменить"
                            onClicked: SystemConfig.revert()
                        }
                        Button {
                            visible: SystemConfig.running || SystemConfig.status === "failed"
                            variant: "tonal"
                            text: "Журнал"
                            onClicked: Ui.updateWindowOpen = true
                        }
                        Button {
                            visible: !SystemConfig.running
                            icon: "check"
                            text: "Применить"
                            onClicked: Store.apply()
                        }
                    }
                }
                MText {
                    Layout.fillWidth: true
                    visible: Store.lastError !== ""
                    text: Store.lastError
                    color: Theme.error
                }
            }
        }
    }

    // Строка каталога
    component StoreRow: Rectangle {
        id: sr
        property var item
        readonly property var st: Store.stateOf(item)
        readonly property var app: Apps.byId(item.id)
        // Значок Flatpak — из локального appstream remote
        readonly property string flatIcon: item.source === "flatpak" ? "file:///var/lib/flatpak/appstream/" + (item.remote || "flathub") + "/x86_64/active/icons/128x128/" + item.id + ".png" : ""
        implicitHeight: 76
        radius: Theme.radius.l
        color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 16
            Item {
                implicitWidth: 44
                implicitHeight: 44
                Image {
                    id: fimg
                    anchors.fill: parent
                    source: sr.flatIcon
                    visible: status === Image.Ready
                    sourceSize: Qt.size(88, 88)
                    asynchronous: true
                }
                AppIcon {
                    anchors.centerIn: parent
                    visible: !fimg.visible
                    size: 40
                    icon: sr.app?.icon ?? (sr.item.source === "flatpak" ? sr.item.id : "package-x-generic")
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    spacing: 8
                    MText {
                        text: sr.item.name
                        size: Theme.type.titleS
                        weight: Theme.strongWeight
                    }
                    Rectangle {
                        implicitWidth: srcLabel.implicitWidth + 12
                        implicitHeight: 20
                        radius: 10
                        color: Theme.secondaryContainer
                        MText {
                            id: srcLabel
                            anchors.centerIn: parent
                            text: Store.sources[sr.item.source] + (sr.item.remote ? " · " + sr.item.remote : "")
                            size: Theme.type.labelS
                            color: Theme.fgSecondaryContainer
                        }
                    }
                    MText {
                        text: sr.item.version ?? ""
                        size: Theme.type.bodyS
                        color: Theme.fgSurfaceVariant
                    }
                }
                MText {
                    Layout.fillWidth: true
                    text: (sr.item.source === "flatpak" ? "" : sr.item.id + " — ") + (sr.item.description ?? "")
                    size: Theme.type.bodyS
                    color: Theme.fgSurfaceVariant
                    elide: Text.ElideRight
                }
                MText {
                    text: sr.st.label
                    size: Theme.type.labelM
                    color: sr.st.desired && sr.st.actual ? Theme.primary : Theme.fgSurfaceVariant
                }
            }
            Button {
                visible: sr.st.actual && !!sr.app
                variant: "tonal"
                text: "Открыть"
                onClicked: Apps.launch(sr.app)
            }
            Button {
                variant: sr.st.desired || sr.st.manual ? "text" : "filled"
                text: sr.st.desired || sr.st.manual ? "Удалить" : sr.st.actual ? "Вернуть" : "Установить"
                disabled: SystemConfig.running || SystemConfig.parseError !== ""
                onClicked: sr.st.desired || sr.st.manual ? Store.remove(sr.item) : Store.install(sr.item)
            }
        }
    }
}
