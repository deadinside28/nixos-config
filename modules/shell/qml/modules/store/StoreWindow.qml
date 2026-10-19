// Магазин — отдельное окно в духе GNOME Software и Bazaar: обзор с
// подборками Flathub и категориями, страницы приложений со скриншотами и
// описанием, общий поиск по Flathub, Nixpkgs и Chaotic-Nyx, установленное,
// обновления и история. Логика — services/Store.qml.
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
            implicitWidth: 1180
            implicitHeight: 800
            minimumSize: Qt.size(780, 560)
            color: Theme.surfaceContainer
            visible: true
            onVisibleChanged: if (!visible)
                Ui.storeOpen = false
            // Карточки и страницы — встроенные компоненты, id окна им не
            // видны, поэтому навигация идёт сигналами сервиса
            function takePending() {
                const it = Store.takePendingApp();
                if (it)
                    openApp(it);
            }
            Component.onCompleted: {
                Store.prepare();
                if (Store.query)
                    search.text = Store.query;
                takePending();
            }
            Connections {
                target: Store
                function onPendingAppChanged() {
                    win.takePending();
                }
                function onCatalogChanged() {
                    win.takePending();
                }
                function onAppRequested(item) {
                    win.openApp(item);
                }
                function onSearchRequested(q) {
                    win.tab = "explore";
                    win.stack = [
                        {
                            kind: "home"
                        }
                    ];
                    search.text = q;
                }
                function onShotRequested(url) {
                    win.shotUrl = url;
                }
            }

            property string tab: "explore" // explore | installed | updates | history
            property string shotUrl: "" // скриншот целиком поверх окна
            // Обзор: стек страниц { kind: home | category | app, … }
            property var stack: [
                {
                    kind: "home"
                }
            ]
            readonly property var page: stack[stack.length - 1]
            readonly property bool searching: search.text.trim() !== "" && page.kind !== "app"

            function openApp(item) {
                tab = "explore";
                stack = [...stack, {
                        kind: "app",
                        item
                    }];
                Store.loadNixInfo(item);
            }
            function openCategory(id) {
                search.text = "";
                stack = [...stack, {
                        kind: "category",
                        id
                    }];
            }
            function back() {
                if (stack.length > 1)
                    stack = stack.slice(0, -1);
            }

            Shortcut {
                sequence: "Escape"
                onActivated: win.shotUrl !== "" ? win.shotUrl = "" : win.stack.length > 1 ? win.back() : search.text !== "" ? search.text = "" : Ui.storeOpen = false
            }
            Shortcut {
                sequence: "Ctrl+F"
                onActivated: {
                    win.tab = "explore";
                    search.forceFocus();
                }
            }
            Shortcut {
                sequence: "Alt+Left"
                onActivated: win.back()
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
                            description: "Пакет Nix"
                        });
                for (const ref of SystemConfig.get("flatpaks", []).map(f => f.split("//")[0]).concat(Store.flatpakInstalled)) {
                    if (out.some(x => x.id === ref))
                        continue;
                    const a = Store.catalogById[ref];
                    out.push(a ? Store.itemOf(a) : {
                        source: "flatpak",
                        id: ref,
                        name: Apps.byId(ref)?.name ?? ref.split(".").pop(),
                        version: "",
                        description: ref
                    });
                }
                return out;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // --- Шапка ----------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    IconButton {
                        visible: win.tab === "explore" && win.stack.length > 1
                        icon: "arrow_back"
                        tooltip: "Назад"
                        onClicked: win.back()
                    }
                    MText {
                        text: "Магазин"
                        size: Theme.type.headlineM
                    }
                    SegmentedButtons {
                        Layout.fillWidth: true
                        options: [
                            {
                                value: "explore",
                                label: "Обзор",
                                icon: "storefront"
                            },
                            {
                                value: "installed",
                                label: "Установлено",
                                icon: "apps"
                            },
                            {
                                value: "updates",
                                label: "Обновления" + (Store.flatpakUpdates.length ? " · " + Store.flatpakUpdates.length : ""),
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

                TextField {
                    id: search
                    visible: win.tab === "explore" && win.page.kind !== "app"
                    Layout.fillWidth: true
                    icon: "search"
                    placeholder: "Поиск приложений во Flathub, Nixpkgs и Chaotic-Nyx"
                    onTextChanged: Store.search(text)
                    Component.onCompleted: forceFocus()
                }

                // --- Обзор: главная ---------------------------------------------------
                Flickable {
                    id: home
                    visible: win.tab === "explore" && win.page.kind === "home" && !win.searching
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: homeCol.implicitHeight + 16
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int columns: Math.max(2, Math.floor(width / 340))

                    ColumnLayout {
                        id: homeCol
                        width: home.width
                        spacing: 20

                        MText {
                            visible: Store.catalog.length === 0
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: Theme.fgSurfaceVariant
                            text: Store.catalogLoading ? "Загружаю каталог Flathub…" : "Каталог Flathub пуст: Flatpak ещё не скачал описание приложений. Подключите Flathub («flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo») — поиск по Nixpkgs работает и без него."
                        }

                        // Баннер: приложения из подборок со скриншотами
                        Hero {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 300
                            apps: [...Store.collection("trending", 12), ...Store.collection("popular", 12), ...Store.recentlyReleased].filter(a => a.screenshots.length > 0).filter((a, i, arr) => arr.findIndex(b => b.id === a.id) === i).slice(0, 6)
                        }

                        Section {
                            title: "Категории"
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: Math.max(3, Math.floor(home.width / 260))
                            columnSpacing: 8
                            rowSpacing: 8
                            Repeater {
                                model: Store.categories
                                Rectangle {
                                    id: cat
                                    required property var modelData
                                    required property int index
                                    readonly property var accent: Theme.accents[index % Theme.accents.length]
                                    Layout.fillWidth: true
                                    implicitHeight: 72
                                    radius: Theme.radius.l
                                    color: accent.bg
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12
                                        MIcon {
                                            icon: cat.modelData.icon
                                            fill: 1
                                            color: cat.accent.fg
                                        }
                                        MText {
                                            Layout.fillWidth: true
                                            text: cat.modelData.label
                                            size: Theme.type.titleM
                                            weight: Theme.strongWeight
                                            color: cat.accent.fg
                                            elide: Text.ElideRight
                                        }
                                    }
                                    StateLayer {
                                        radius: parent.radius
                                        onClicked: win.openCategory(cat.modelData.id)
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: [
                                {
                                    title: "Популярное",
                                    apps: Store.collection("popular", 12)
                                },
                                {
                                    title: "В тренде",
                                    apps: Store.collection("trending", 12)
                                },
                                {
                                    title: "Недавно обновлённые",
                                    apps: Store.collection("recently-updated", 12).length ? Store.collection("recently-updated", 12) : Store.recentlyReleased.slice(0, 12)
                                },
                                {
                                    title: "Новое во Flathub",
                                    apps: Store.collection("recently-added", 12)
                                }
                            ]
                            ColumnLayout {
                                id: sec
                                required property var modelData
                                visible: modelData.apps.length > 0
                                Layout.fillWidth: true
                                spacing: 8
                                Section {
                                    title: sec.modelData.title
                                }
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: home.columns
                                    columnSpacing: 8
                                    rowSpacing: 8
                                    Repeater {
                                        model: sec.modelData.apps.slice(0, home.columns * 2)
                                        AppCard {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            app: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Обзор: категория -------------------------------------------------
                ColumnLayout {
                    visible: win.tab === "explore" && win.page.kind === "category" && !win.searching
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    readonly property var cat: Store.categories.find(c => c.id === win.page.id) ?? null
                    readonly property var apps: cat ? Store.categoryApps(cat.id) : []
                    MText {
                        text: (parent.cat?.label ?? "") + " · " + parent.apps.length
                        size: Theme.type.titleL
                    }
                    GridView {
                        id: catGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: parent.apps
                        readonly property int columns: Math.max(2, Math.floor(width / 340))
                        cellWidth: width / columns
                        cellHeight: 100
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            required property var modelData
                            width: catGrid.cellWidth
                            height: catGrid.cellHeight
                            AppCard {
                                anchors.fill: parent
                                anchors.margins: 4
                                app: parent.modelData
                            }
                        }
                    }
                }

                // --- Поиск ------------------------------------------------------------------
                ColumnLayout {
                    visible: win.tab === "explore" && win.searching
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    MText {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        size: Theme.type.bodyS
                        color: Store.indexStatus === "failed" ? Theme.error : Theme.fgSurfaceVariant
                        text: Store.indexStatus === "building" ? "Готовлю каталог Nix по ревизиям из flake.lock — первый раз это несколько минут. Flathub ищется уже сейчас." : Store.indexStatus === "failed" ? "Каталог Nix не построился — ищется только Flathub. Проверь сеть и flake.lock." : "Пакеты Nix — ровно те версии, из которых собирается система: установка не обновляет flake.lock."
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        // приложения Flathub — выше пакетов Nix
                        model: [...Store.flatpakResults, ...Store.nixResults]
                        delegate: StoreRow {
                            required property var modelData
                            width: ListView.view.width
                            item: modelData
                        }
                        MText {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: Store.searching ? "Ищу…" : "Ничего не нашлось"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }

                // --- Страница приложения ----------------------------------------------
                AppPage {
                    visible: win.tab === "explore" && win.page.kind === "app"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    item: win.page.kind === "app" ? win.page.item : null
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
                            subtitle: Store.flatpakUpdates.length ? Store.flatpakUpdates.map(id => Store.catalogById[id]?.name ?? id).join(", ") : "Flatpak обновляется и сам раз в неделю (если включено в «Системе»). Список Flatpak в конфигурации не закрепляет версии — ставится текущая из remote."
                            clickable: false
                            Button {
                                visible: Store.flatpakUpdates.length > 0
                                text: "Обновить"
                                onClicked: Apps.run([Nix.terminal, "--hold", "flatpak", "update"])
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
                            text: SystemConfig.running ? SystemConfig.task + ": " + SystemConfig.stage : "Ожидают применения: " + Store.pending.map(p => (p.add ? "+" : "−") + (Store.catalogById[p.id.split("//")[0]]?.name ?? p.id)).join(", ")
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

            // Скриншот целиком — поверх окна, клик или Escape закрывает
            Rectangle {
                anchors.fill: parent
                visible: win.shotUrl !== ""
                color: Theme.alpha(Theme.scrim, 0.8)
                Image {
                    id: shot
                    source: win.shotUrl
                    anchors.fill: parent
                    anchors.margins: 32
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                CircularProgress {
                    anchors.centerIn: parent
                    visible: shot.status === Image.Loading
                    implicitWidth: 48
                    implicitHeight: 48
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: win.shotUrl = ""
                }
            }

            // --- Компоненты -----------------------------------------------------------

            component Section: MText {
                property string title
                text: title
                size: Theme.type.titleL
                weight: Theme.strongWeight
            }

            // Значок записи: из AppStream (файл или адрес), иначе из темы
            component StoreIcon: Item {
                id: si
                property var item
                property real size: 48
                readonly property string src: item?.app?.icon ?? Store.catalogById[item?.id]?.icon ?? ""
                implicitWidth: size
                implicitHeight: size
                Image {
                    id: siImg
                    anchors.fill: parent
                    source: si.src === "" ? "" : si.src.startsWith("/") ? "file://" + si.src : si.src
                    visible: status === Image.Ready
                    sourceSize: Qt.size(si.size * 2, si.size * 2)
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                }
                AppIcon {
                    anchors.fill: parent
                    visible: !siImg.visible
                    styled: false
                    icon: Apps.byId(si.item?.id ?? "")?.icon ?? (si.item?.source === "flatpak" ? si.item.id : "package-x-generic")
                }
            }

            // Карточка приложения каталога: значок, имя, кратко
            component AppCard: Rectangle {
                id: card
                property var app
                readonly property var item: Store.itemOf(app)
                readonly property var st: Store.stateOf(item)
                implicitHeight: 92
                radius: Theme.radius.l
                color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14
                    StoreIcon {
                        item: card.item
                        size: 56
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            MText {
                                Layout.fillWidth: true
                                text: card.app.name
                                size: Theme.type.titleS
                                weight: Theme.strongWeight
                                elide: Text.ElideRight
                            }
                            MIcon {
                                visible: card.app.verified
                                icon: "verified"
                                fill: 1
                                size: 16
                                color: Theme.primary
                            }
                            MIcon {
                                visible: card.st.actual
                                icon: "check_circle"
                                fill: 1
                                size: 16
                                color: Theme.tertiary
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            text: card.app.summary
                            size: Theme.type.bodyS
                            color: Theme.fgSurfaceVariant
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
                StateLayer {
                    radius: parent.radius
                    onClicked: Store.requestApp(card.item)
                }
            }

            // Баннер с листанием: скриншот фоном, значок, имя, кратко
            component Hero: Rectangle {
                id: hero
                property var apps: []
                property int current: 0
                readonly property var app: apps[current % Math.max(1, apps.length)] ?? null
                visible: apps.length > 0
                radius: Theme.radius.xl
                color: Theme.secondaryContainer
                clip: true
                Timer {
                    running: hero.visible && hero.apps.length > 1
                    interval: 7000
                    repeat: true
                    onTriggered: hero.current = (hero.current + 1) % hero.apps.length
                }
                Image {
                    id: heroBg
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 24
                    width: parent.width * 0.55
                    source: hero.app?.screenshots[0]?.thumb ?? ""
                    fillMode: Image.PreserveAspectCrop
                    horizontalAlignment: Image.AlignLeft
                    verticalAlignment: Image.AlignTop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.anim.normal
                        }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.35
                            color: Theme.secondaryContainer
                        }
                        GradientStop {
                            position: 0.75
                            color: Theme.alpha(Theme.secondaryContainer, 0)
                        }
                    }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 32
                    width: parent.width * 0.45
                    spacing: 10
                    StoreIcon {
                        item: hero.app ? Store.itemOf(hero.app) : null
                        size: 72
                    }
                    MText {
                        Layout.fillWidth: true
                        text: hero.app?.name ?? ""
                        size: Theme.type.headlineM
                        color: Theme.fgSecondaryContainer
                        elide: Text.ElideRight
                    }
                    MText {
                        Layout.fillWidth: true
                        text: hero.app?.summary ?? ""
                        color: Theme.fgSecondaryContainer
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Button {
                        text: "Подробнее"
                        onClicked: Store.requestApp(Store.itemOf(hero.app))
                    }
                }
                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 16
                    anchors.leftMargin: 32
                    spacing: 6
                    Repeater {
                        model: hero.apps.length
                        Rectangle {
                            required property int index
                            width: index === hero.current ? 20 : 8
                            height: 8
                            radius: 4
                            color: index === hero.current ? Theme.primary : Theme.alpha(Theme.fgSecondaryContainer, 0.3)
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.anim.fast
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                onClicked: hero.current = parent.index
                            }
                        }
                    }
                }
            }

            // Кнопки установки для записи
            component InstallButtons: RowLayout {
                id: ib
                property var item
                readonly property var st: Store.stateOf(item)
                readonly property var entry: Apps.byId(item.id)
                spacing: 8
                Button {
                    visible: ib.st.actual && !!ib.entry
                    variant: "tonal"
                    text: "Открыть"
                    onClicked: Apps.launch(ib.entry)
                }
                Button {
                    variant: ib.st.desired || ib.st.manual ? "text" : "filled"
                    icon: ib.st.desired || ib.st.manual ? "delete" : ib.st.actual ? "undo" : "download"
                    text: ib.st.desired || ib.st.manual ? "Удалить" : ib.st.actual ? "Вернуть" : "Установить"
                    disabled: SystemConfig.running || SystemConfig.parseError !== ""
                    onClicked: ib.st.desired || ib.st.manual ? Store.remove(ib.item) : Store.install(ib.item)
                }
            }

            // Строка поиска и «Установлено»
            component StoreRow: Rectangle {
                id: sr
                property var item
                readonly property var st: Store.stateOf(item)
                implicitHeight: 76
                radius: Theme.radius.l
                color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                StateLayer {
                    radius: parent.radius
                    onClicked: Store.requestApp(sr.item)
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16
                    StoreIcon {
                        item: sr.item
                        size: 44
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
                                    text: (sr.item.source === "flatpak" ? "Flathub" : Store.sources[sr.item.source]) + (sr.item.remote && sr.item.remote !== "flathub" ? " · " + sr.item.remote : "")
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
                    InstallButtons {
                        item: sr.item
                    }
                }
            }

            // Страница приложения
            component AppPage: Flickable {
                id: ap
                property var item
                readonly property var app: item ? (item.app ?? Store.catalogById[item.id] ?? null) : null
                readonly property var nix: item && item.source !== "flatpak" ? Store.nixInfo[item.id] ?? null : null
                readonly property var st: item ? Store.stateOf(item) : ({})
                contentHeight: apCol.implicitHeight + 24
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                onItemChanged: contentY = 0

                ColumnLayout {
                    id: apCol
                    width: ap.width
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 24
                        StoreIcon {
                            item: ap.item
                            size: 112
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            MText {
                                Layout.fillWidth: true
                                text: ap.app?.name ?? ap.item?.name ?? ""
                                size: Theme.type.headlineM
                                wrapMode: Text.WordWrap
                            }
                            RowLayout {
                                spacing: 6
                                MText {
                                    text: ap.app?.developer || (ap.item?.source === "flatpak" ? "" : Store.sources[ap.item?.source] ?? "")
                                    color: Theme.fgSurfaceVariant
                                }
                                MIcon {
                                    visible: ap.app?.verified ?? false
                                    icon: "verified"
                                    fill: 1
                                    size: 18
                                    color: Theme.primary
                                }
                                MText {
                                    visible: ap.app?.verified ?? false
                                    text: "Проверенный разработчик"
                                    size: Theme.type.bodyS
                                    color: Theme.primary
                                }
                            }
                            MText {
                                Layout.fillWidth: true
                                text: ap.app?.summary ?? ap.nix?.description ?? ap.item?.description ?? ""
                                wrapMode: Text.WordWrap
                            }
                            MText {
                                text: ap.st.label ?? ""
                                size: Theme.type.labelM
                                color: ap.st.desired && ap.st.actual ? Theme.primary : Theme.fgSurfaceVariant
                            }
                        }
                        InstallButtons {
                            visible: ap.item !== null
                            Layout.alignment: Qt.AlignTop
                            item: ap.item ?? ({})
                        }
                    }

                    // Скриншоты
                    ListView {
                        id: shots
                        visible: (ap.app?.screenshots ?? []).length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 340
                        orientation: ListView.Horizontal
                        spacing: 12
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: ap.app?.screenshots ?? []
                        delegate: Rectangle {
                            id: sh
                            required property var modelData
                            height: shots.height
                            width: img.status === Image.Ready ? Math.min(shots.height * img.implicitWidth / Math.max(1, img.implicitHeight), shots.width * 0.9) : shots.height * 16 / 10
                            radius: Theme.radius.l
                            color: Theme.surfaceContainerHighest
                            clip: true
                            Image {
                                id: img
                                anchors.fill: parent
                                source: sh.modelData.thumb
                                sourceSize.height: shots.height * 2
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            CircularProgress {
                                anchors.centerIn: parent
                                visible: img.status === Image.Loading
                                implicitWidth: 36
                                implicitHeight: 36
                            }
                            MIcon {
                                anchors.centerIn: parent
                                visible: img.status === Image.Error
                                icon: "image_not_supported"
                                size: 40
                                color: Theme.fgSurfaceVariant
                            }
                            StateLayer {
                                radius: parent.radius
                                onClicked: Store.requestShot(sh.modelData.full)
                            }
                        }
                    }

                    MText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: ap.app?.description ?? (ap.nix ? (ap.nix.long || ap.nix.description || "") : "")
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                    }
                    MText {
                        visible: ap.item && ap.item.source !== "flatpak" && !ap.nix
                        text: "Загружаю описание пакета…"
                        color: Theme.fgSurfaceVariant
                    }

                    // Сведения
                    GridLayout {
                        Layout.fillWidth: true
                        columns: Math.max(2, Math.floor(ap.width / 260))
                        columnSpacing: 8
                        rowSpacing: 8
                        Repeater {
                            model: {
                                const a = ap.app, n = ap.nix, it = ap.item;
                                if (!it)
                                    return [];
                                const lic = a?.license || (Array.isArray(n?.license) ? n.license.join(", ") : n?.license) || "";
                                return [["new_releases", "Версия", a?.version || n?.version || it.version || "—"], ["update", "Обновлено", a?.released ? new Date(a.released * 1000).toLocaleDateString(Qt.locale("ru_RU"), "d MMMM yyyy") : "—"], ["gavel", "Лицензия", lic || "—"], ["inventory_2", "Источник", it.source === "flatpak" ? "Flathub (Flatpak)" : Store.sources[it.source] + " (Nix)"], ["tag", it.source === "flatpak" ? "ID" : "Пакет", it.id], ["person", "Разработчик", a?.developer || "—"]].filter(x => x[2] !== "—" || x[1] === "Версия");
                            }
                            Rectangle {
                                id: fact
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 64
                                radius: Theme.radius.l
                                color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12
                                    MIcon {
                                        icon: fact.modelData[0]
                                        color: Theme.primary
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        MText {
                                            text: fact.modelData[1]
                                            size: Theme.type.labelM
                                            color: Theme.fgSurfaceVariant
                                        }
                                        MText {
                                            Layout.fillWidth: true
                                            text: fact.modelData[2]
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Button {
                            readonly property string url: ap.app?.homepage || ap.nix?.homepage || ""
                            visible: url !== ""
                            variant: "outlined"
                            icon: "open_in_new"
                            text: "Сайт проекта"
                            onClicked: Qt.openUrlExternally(url)
                        }
                        Button {
                            visible: ap.item?.source === "flatpak"
                            variant: "outlined"
                            icon: "storefront"
                            text: "Страница во Flathub"
                            onClicked: Qt.openUrlExternally("https://flathub.org/apps/" + ap.item.id)
                        }
                    }
                }
            }
        }
    }
}
