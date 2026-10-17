import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Обои и стиль"

    // Превью палитр: matugen --dry-run для каждой схемы.
    property var swatches: ({})
    property var iconThemes: []

    Component.onCompleted: {
        Wallpapers.refresh();
        WallpaperEngine.refresh();
        previews.running = true;
        icons.running = true;
    }
    Connections {
        target: Settings.data
        function onWallpaperChanged() {
            previews.running = true;
        }
        function onEnginePreviewChanged() {
            previews.running = true;
        }
        function onWallpaperTypeChanged() {
            previews.running = true;
        }
        function onPresetColorChanged() {
            previews.running = true;
        }
        function onColorSourceChanged() {
            previews.running = true;
        }
        function onDarkModeChanged() {
            previews.running = true;
        }
    }

    Process {
        id: previews
        command: {
            const d = Settings.data;
            const img = Wallpapers.image;
            const src = d.colorSource === "wallpaper" && img ? `image "${img}" --source-color-index 0` : `color hex "${d.presetColor}"`;
            const types = Theming.schemes.map(s => s.value).join(" ");
            return ["sh", "-c", `for t in ${types}; do printf '%s ' "$t"; ${Nix.matugen} ${src} -t "$t" -m ${Theming.mode} --dry-run -j hex 2>/dev/null | tr -d '\\n'; echo; done`];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf(" ");
                    if (i < 0)
                        continue;
                    try {
                        const c = JSON.parse(line.slice(i + 1)).colors;
                        out[line.slice(0, i)] = [c.primary.default.color, c.secondary_container.default.color, c.tertiary.default.color];
                    } catch (e) {}
                }
                page.swatches = out;
            }
        }
    }

    Process {
        id: icons
        command: ["sh", "-c", `for d in "$HOME/.local/share/icons" "$HOME/.icons" /run/current-system/sw/share/icons /etc/profiles/per-user/$USER/share/icons; do [ -d "$d" ] && for t in "$d"/*/; do [ -f "$t/index.theme" ] && [ ! -d "$t/cursors" ] && basename "$t"; done; done | sort -u`]
        stdout: StdioCollector {
            onStreamFinished: page.iconThemes = text.split("\n").filter(t => t && t !== "hicolor" && t !== "default")
        }
    }

    // --- Превью рабочего стола -------------------------------------------
    ClippingRectangle {
        Layout.fillWidth: true
        implicitHeight: width * 0.42
        radius: Theme.radius.xxl
        color: Theme.surfaceDim

        Image {
            anchors.fill: parent
            source: Wallpapers.image ? "file://" + Wallpapers.image : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 900
            asynchronous: true
        }
        // мини-окно
        Rectangle {
            x: parent.width * 0.18
            y: parent.height * 0.14
            width: parent.width * 0.5
            height: parent.height * 0.58
            radius: 14
            color: Theme.surface
            Rectangle {
                x: 14
                y: 14
                width: parent.width * 0.4
                height: 12
                radius: 6
                color: Theme.fgSurface
                opacity: 0.8
            }
            Row {
                x: 14
                y: 40
                spacing: 8
                Repeater {
                    model: [Theme.primary, Theme.secondaryContainer, Theme.tertiary]
                    Rectangle {
                        required property var modelData
                        width: 44
                        height: 22
                        radius: 11
                        color: modelData
                    }
                }
            }
            Rectangle {
                x: 14
                y: 74
                width: parent.width - 28
                height: parent.height - 88
                radius: 10
                color: Theme.surfaceContainerHigh
            }
        }
        // мини-панель задач
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 30
            color: Theme.alpha(Theme.surfaceContainer, 0.9)
            Rectangle {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: "transparent"
                border.width: 2
                border.color: Theme.fgSurface
            }
            Row {
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: 5
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: index === 0 ? Theme.primary : Theme.surfaceContainerHighest
                    }
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 70
                height: 20
                radius: 10
                color: Theme.surfaceContainerHighest
            }
        }
    }

    // --- Обои -------------------------------------------------------------
    Group {
        title: "Обои"

        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: true
            Layout.fillWidth: true
            implicitHeight: wallCol.implicitHeight + 32
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4

            ColumnLayout {
                id: wallCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MText {
                        Layout.fillWidth: true
                        text: Wallpapers.dir.replace(Settings.home, "~")
                        color: Theme.fgSurfaceVariant
                    }
                    Button {
                        variant: "tonal"
                        icon: "shuffle"
                        text: "Случайные"
                        onClicked: Wallpapers.random()
                    }
                    Button {
                        variant: "tonal"
                        icon: "folder_open"
                        text: "Папка"
                        onClicked: folderDialog.open()
                    }
                    Button {
                        variant: "tonal"
                        icon: "add_photo_alternate"
                        text: "Файл"
                        onClicked: fileDialog.open()
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    implicitHeight: Math.min(3, Math.ceil(count / 4)) * cellHeight
                    cellWidth: width / 4
                    cellHeight: cellWidth * 0.62
                    clip: true
                    interactive: count > 12
                    model: Wallpapers.files
                    delegate: Item {
                        id: wp
                        required property string modelData
                        width: grid.cellWidth
                        height: grid.cellHeight
                        readonly property bool sel: Settings.data.wallpaperType === "image" && Settings.data.wallpaper === modelData
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: wp.sel ? Theme.radius.xl : Theme.radius.l
                            color: Theme.surfaceContainerHighest
                            border.width: wp.sel ? 3 : 0
                            border.color: Theme.primary
                            Behavior on radius {
                                NumberAnimation {
                                    duration: Theme.anim.normal
                                }
                            }
                            Image {
                                anchors.fill: parent
                                source: "file://" + wp.modelData
                                sourceSize.width: 320
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            MIcon {
                                visible: wp.sel
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                icon: "check_circle"
                                fill: 1
                                color: Theme.primary
                            }
                            StateLayer {
                                color: "white"
                                onClicked: Wallpapers.set(wp.modelData)
                            }
                        }
                    }
                }

                MText {
                    visible: Wallpapers.files.length === 0
                    Layout.fillWidth: true
                    text: "В папке нет картинок. Положи обои в " + Wallpapers.dir.replace(Settings.home, "~") + " или выбери другую папку."
                    color: Theme.fgSurfaceVariant
                    wrapMode: Text.WordWrap
                }
            }
        }
    }


    // --- Wallpaper Engine ---------------------------------------------------
    Group {
        title: "Живые обои (Wallpaper Engine)"

        SwitchItem {
            icon: "animated_images"
            title: "Живые обои"
            subtitle: WallpaperEngine.active ? "Сейчас: " + (WallpaperEngine.current?.title ?? Settings.data.engineWallpaper.split("/").pop()) : "Выбери обои ниже — они встанут на все мониторы"
            checked: WallpaperEngine.active
            disabled: Settings.data.engineWallpaper === ""
            onToggled: v => Settings.data.wallpaperType = v ? "engine" : "image"
        }

        Rectangle {
            readonly property bool groupItem: true
            property bool first: false
            property bool last: false
            Layout.fillWidth: true
            implicitHeight: engCol.implicitHeight + 32
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4

            ColumnLayout {
                id: engCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MText {
                        Layout.fillWidth: true
                        text: WallpaperEngine.scanning ? "Ищу обои в библиотеках Steam…" : "Из мастерской Steam: " + WallpaperEngine.items.length
                        color: Theme.fgSurfaceVariant
                    }
                    Button {
                        variant: "tonal"
                        icon: "refresh"
                        text: "Обновить"
                        onClicked: WallpaperEngine.refresh()
                    }
                    Button {
                        variant: "tonal"
                        icon: "storefront"
                        text: "Мастерская"
                        onClicked: Quickshell.execDetached(["xdg-open", "steam://url/SteamWorkshopPage/431960"])
                    }
                }

                GridView {
                    id: engGrid
                    Layout.fillWidth: true
                    implicitHeight: Math.min(3, Math.ceil(count / 4)) * cellHeight
                    cellWidth: width / 4
                    cellHeight: cellWidth * 0.62 + 28
                    clip: true
                    interactive: count > 12
                    model: WallpaperEngine.items
                    delegate: Item {
                        id: we
                        required property var modelData
                        width: engGrid.cellWidth
                        height: engGrid.cellHeight
                        readonly property bool sel: WallpaperEngine.active && Settings.data.engineWallpaper === modelData.dir

                        ClippingRectangle {
                            id: thumb
                            x: 4
                            y: 4
                            width: parent.width - 8
                            height: parent.height - 36
                            radius: we.sel ? Theme.radius.xl : Theme.radius.l
                            color: Theme.surfaceContainerHighest
                            border.width: we.sel ? 3 : 0
                            border.color: Theme.primary
                            Behavior on radius {
                                NumberAnimation {
                                    duration: Theme.anim.normal
                                }
                            }
                            // превью бывает gif — анимируем только при наведении
                            AnimatedImage {
                                anchors.fill: parent
                                source: we.modelData.preview ? "file://" + we.modelData.preview : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                playing: hover.hovered
                                cache: false
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                implicitWidth: typeLabel.implicitWidth + 12
                                implicitHeight: 20
                                radius: 10
                                color: Theme.alpha(Theme.scrim, 0.55)
                                MText {
                                    id: typeLabel
                                    anchors.centerIn: parent
                                    text: ({
                                            scene: "Сцена",
                                            video: "Видео",
                                            web: "Веб"
                                        })[we.modelData.type] ?? we.modelData.type
                                    size: Theme.type.labelS
                                    color: "white"
                                }
                            }
                            MIcon {
                                visible: we.sel
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 8
                                icon: "check_circle"
                                fill: 1
                                color: Theme.primary
                            }
                            HoverHandler {
                                id: hover
                            }
                            StateLayer {
                                color: "white"
                                onClicked: WallpaperEngine.apply(we.modelData)
                            }
                        }
                        MText {
                            anchors.top: thumb.bottom
                            anchors.topMargin: 4
                            x: 8
                            width: parent.width - 16
                            text: we.modelData.title
                            size: Theme.type.bodyS
                            color: we.sel ? Theme.primary : Theme.fgSurfaceVariant
                        }
                    }
                }

                MText {
                    visible: !WallpaperEngine.scanning && WallpaperEngine.items.length === 0
                    Layout.fillWidth: true
                    text: "Обоев не найдено. Купи и установи Wallpaper Engine в Steam (запускать не нужно), подпишись на обои в мастерской и дождись загрузки — они появятся здесь."
                    color: Theme.fgSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                MText {
                    visible: WallpaperEngine.items.length > 0 && WallpaperEngine.assetsDir === ""
                    Layout.fillWidth: true
                    text: "Ресурсы Wallpaper Engine не найдены: видеообои будут работать, а «сцены» — нет. Установи сам Wallpaper Engine в Steam."
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }
                MText {
                    visible: WallpaperEngine.active && WallpaperEngine.lastError !== ""
                    Layout.fillWidth: true
                    text: "linux-wallpaperengine: " + WallpaperEngine.lastError
                    color: Theme.error
                    wrapMode: Text.WordWrap
                    font.family: Theme.monoFont
                    size: Theme.type.bodyS
                }
            }
        }

        SwitchItem {
            icon: "volume_up"
            title: "Звук обоев"
            subtitle: "Сам приглушается, когда играет другое приложение"
            checked: !Settings.data.engineSilent
            onToggled: v => Settings.data.engineSilent = !v
        }
        SliderItem {
            visible: !Settings.data.engineSilent
            icon: "graphic_eq"
            title: "Громкость обоев"
            valueText: Settings.data.engineVolume + "%"
            from: 0
            to: 100
            stepSize: 5
            value: Settings.data.engineVolume
            onMoved: v => Settings.data.engineVolume = Math.round(v)
        }
        ChoiceItem {
            icon: "speed"
            title: "Частота кадров"
            options: [15, 24, 30, 60, 100, 144].map(f => ({
                        value: f,
                        label: f + " FPS"
                    }))
            current: Settings.data.engineFps
            onSelected: v => Settings.data.engineFps = v
        }
        ChoiceItem {
            icon: "fit_screen"
            title: "Масштабирование"
            options: [
                {
                    value: "fill",
                    label: "Заполнить экран"
                },
                {
                    value: "fit",
                    label: "Вписать целиком"
                },
                {
                    value: "stretch",
                    label: "Растянуть"
                },
                {
                    value: "default",
                    label: "Как задумал автор"
                }
            ]
            current: Settings.data.engineScaling
            onSelected: v => Settings.data.engineScaling = v
        }
        SwitchItem {
            icon: "sports_esports"
            title: "Пауза в полноэкранных приложениях"
            subtitle: "Обои не тратят видеокарту, пока идёт игра или фильм"
            checked: Settings.data.enginePauseFullscreen
            onToggled: v => Settings.data.enginePauseFullscreen = v
        }
    }

    FolderDialog {
        id: folderDialog
        title: "Папка с обоями"
        currentFolder: "file://" + Wallpapers.dir
        onAccepted: Settings.data.wallpaperDir = decodeURIComponent(selectedFolder.toString().replace("file://", ""))
    }
    FileDialog {
        id: fileDialog
        title: "Выбор обоев"
        nameFilters: ["Изображения (*.jpg *.jpeg *.png *.webp *.bmp)"]
        currentFolder: "file://" + Wallpapers.dir
        onAccepted: Wallpapers.set(decodeURIComponent(selectedFile.toString().replace("file://", "")))
    }

    // --- Цвета ------------------------------------------------------------
    Group {
        title: "Цвета"

        Rectangle {
            readonly property bool groupItem: true
            property bool first: true
            property bool last: true
            Layout.fillWidth: true
            implicitHeight: colorCol.implicitHeight + 32
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4

            ColumnLayout {
                id: colorCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 16

                SegmentedButtons {
                    Layout.fillWidth: true
                    options: [
                        {
                            value: "wallpaper",
                            label: "Цвета обоев",
                            icon: "wallpaper"
                        },
                        {
                            value: "preset",
                            label: "Основные цвета",
                            icon: "palette"
                        }
                    ]
                    current: Settings.data.colorSource
                    onSelected: v => Settings.data.colorSource = v
                }

                // Основной цвет (для «Основных цветов»)
                Flow {
                    Layout.fillWidth: true
                    visible: Settings.data.colorSource === "preset"
                    spacing: 12
                    Repeater {
                        model: Theming.presets
                        Rectangle {
                            id: seed
                            required property string modelData
                            readonly property bool sel: Settings.data.presetColor.toLowerCase() === modelData
                            width: 56
                            height: 56
                            radius: sel ? Theme.radius.l : 28
                            color: modelData
                            Behavior on radius {
                                NumberAnimation {
                                    duration: Theme.anim.normal
                                    easing.type: Easing.OutBack
                                }
                            }
                            MIcon {
                                anchors.centerIn: parent
                                visible: seed.sel
                                icon: "check"
                                color: "white"
                                weight: 700
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.data.presetColor = seed.modelData
                            }
                        }
                    }
                    Rectangle {
                        width: 56
                        height: 56
                        radius: 28
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.outline
                        MIcon {
                            anchors.centerIn: parent
                            icon: "colorize"
                            color: Theme.fgSurfaceVariant
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: colorDialog.open()
                        }
                    }
                }

                MText {
                    text: "Стиль палитры"
                    color: Theme.fgSurfaceVariant
                    size: Theme.type.labelL
                    weight: Font.Medium
                }

                // Схемы палитры — кружки-образцы, как на Pixel
                Flow {
                    Layout.fillWidth: true
                    spacing: 16
                    Repeater {
                        model: Theming.schemes
                        ColumnLayout {
                            id: sch
                            required property var modelData
                            readonly property bool sel: Settings.data.schemeType === modelData.value
                            readonly property var c: page.swatches[modelData.value] ?? [Theme.primary, Theme.secondaryContainer, Theme.tertiary]
                            spacing: 6
                            width: 80

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 72
                                implicitHeight: 72
                                radius: sch.sel ? Theme.radius.xl : 36
                                color: Theme.surfaceContainerHighest
                                border.width: sch.sel ? 3 : 0
                                border.color: Theme.primary
                                Behavior on radius {
                                    NumberAnimation {
                                        duration: Theme.anim.normal
                                    }
                                }
                                // круг из трёх долей: основной сверху, вторичный и третичный снизу
                                Item {
                                    anchors.centerIn: parent
                                    width: 52
                                    height: 52
                                    Rectangle {
                                        width: 52
                                        height: 26
                                        topLeftRadius: 26
                                        topRightRadius: 26
                                        color: sch.c[0]
                                    }
                                    Rectangle {
                                        y: 27
                                        width: 25.5
                                        height: 25
                                        bottomLeftRadius: 26
                                        color: sch.c[1]
                                    }
                                    Rectangle {
                                        x: 26.5
                                        y: 27
                                        width: 25.5
                                        height: 25
                                        bottomRightRadius: 26
                                        color: sch.c[2]
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Settings.data.schemeType = sch.modelData.value
                                }
                            }
                            MText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: sch.modelData.label
                                size: Theme.type.bodyS
                                color: sch.sel ? Theme.primary : Theme.fgSurfaceVariant
                            }
                        }
                    }
                }
            }
        }
    }

    ColorDialog {
        id: colorDialog
        title: "Свой цвет"
        selectedColor: Settings.data.presetColor
        onAccepted: Settings.data.presetColor = selectedColor.toString()
    }

    Group {
        title: "Тема"
        SwitchItem {
            icon: "dark_mode"
            title: "Тёмная тема"
            subtitle: "Тёмный фон у оболочки и приложений"
            checked: Settings.data.darkMode
            onToggled: v => Settings.data.darkMode = v
        }
        SwitchItem {
            icon: "format_paint"
            title: "Красить приложения"
            subtitle: "GTK и libadwaita, Nemo, kitty и рамки окон получают цвета обоев"
            checked: Settings.data.themeApps
            onToggled: v => Settings.data.themeApps = v
        }
        ChoiceItem {
            icon: "interests"
            title: "Значки"
            options: page.iconThemes
            current: Settings.data.iconTheme || "Adwaita"
            onSelected: v => Theming.setIconTheme(v)
        }
        ListItem {
            visible: Theming.busy
            icon: "autorenew"
            title: "Обновляю палитру…"
            clickable: false
        }
    }
}
