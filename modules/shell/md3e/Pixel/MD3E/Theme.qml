pragma Singleton

// Material 3 Expressive: цветовые роли, шрифты, скругления и движение.
// Часть библиотеки Pixel.MD3E — чистый Qt Quick, без Quickshell: её же
// используют самостоятельные приложения.
//
// Входы задаёт хозяин: Pixel Shell — мостом common/ThemeBridge.qml,
// отдельное приложение — элементом ThemeFile (читает те же файлы
// оболочки). Цвета — из matugen: в colors.json сразу обе схемы, тёмная и
// светлая, поэтому переключение темы мгновенное. Пока схемы нет — базовая
// палитра Google Blue.

import QtQuick

QtObject {
    id: root

    // --- входы -------------------------------------------------------------

    property bool dark: true
    property var scheme: ({}) // colors.json matugen: {source, dark: {…}, light: {…}}
    property string font: "Google Sans"
    property string monoFont: "JetBrainsMono Nerd Font"
    property string fontWeightName: "Medium" // Regular | Medium | Bold
    property real fontSize: 12 // 12 — как задумано; масштабирует всю типографику
    property real animationScale: 1
    property real panelOpacity: 1 // фон выезжающих панелей (под ним размытие)
    property color frame: surfaceContainer // рамка экрана оболочки

    // --- палитра -----------------------------------------------------------

    readonly property var fallbackDark: ({
            primary: "#adc6ff",
            on_primary: "#102f60",
            primary_container: "#2b4678",
            on_primary_container: "#d8e2ff",
            primary_fixed: "#d8e2ff",
            primary_fixed_dim: "#adc6ff",
            on_primary_fixed: "#001a41",
            on_primary_fixed_variant: "#2b4678",
            inverse_primary: "#445e91",
            secondary: "#bfc6dc",
            on_secondary: "#293041",
            secondary_container: "#3f4759",
            on_secondary_container: "#dbe2f9",
            secondary_fixed: "#dbe2f9",
            secondary_fixed_dim: "#bfc6dc",
            on_secondary_fixed: "#141b2c",
            on_secondary_fixed_variant: "#3f4759",
            tertiary: "#debcdf",
            on_tertiary: "#402843",
            tertiary_container: "#583e5b",
            on_tertiary_container: "#fbd7fc",
            tertiary_fixed: "#fbd7fc",
            tertiary_fixed_dim: "#debcdf",
            on_tertiary_fixed: "#29132d",
            on_tertiary_fixed_variant: "#583e5b",
            error: "#ffb4ab",
            on_error: "#690005",
            error_container: "#93000a",
            on_error_container: "#ffdad6",
            background: "#111318",
            on_background: "#e2e2e9",
            surface: "#111318",
            on_surface: "#e2e2e9",
            surface_variant: "#44474f",
            on_surface_variant: "#c4c6d0",
            surface_dim: "#111318",
            surface_bright: "#37393e",
            surface_container_lowest: "#0c0e13",
            surface_container_low: "#1a1b20",
            surface_container: "#1e1f25",
            surface_container_high: "#282a2f",
            surface_container_highest: "#33353a",
            surface_tint: "#adc6ff",
            inverse_surface: "#e2e2e9",
            inverse_on_surface: "#2f3036",
            outline: "#8e9099",
            outline_variant: "#44474f",
            shadow: "#000000",
            scrim: "#000000"
        })

    readonly property var fallbackLight: ({
            primary: "#445e91",
            on_primary: "#ffffff",
            primary_container: "#d8e2ff",
            on_primary_container: "#001a41",
            primary_fixed: "#d8e2ff",
            primary_fixed_dim: "#adc6ff",
            on_primary_fixed: "#001a41",
            on_primary_fixed_variant: "#2b4678",
            inverse_primary: "#adc6ff",
            secondary: "#575e71",
            on_secondary: "#ffffff",
            secondary_container: "#dbe2f9",
            on_secondary_container: "#141b2c",
            secondary_fixed: "#dbe2f9",
            secondary_fixed_dim: "#bfc6dc",
            on_secondary_fixed: "#141b2c",
            on_secondary_fixed_variant: "#3f4759",
            tertiary: "#715573",
            on_tertiary: "#ffffff",
            tertiary_container: "#fbd7fc",
            on_tertiary_container: "#29132d",
            tertiary_fixed: "#fbd7fc",
            tertiary_fixed_dim: "#debcdf",
            on_tertiary_fixed: "#29132d",
            on_tertiary_fixed_variant: "#583e5b",
            error: "#ba1a1a",
            on_error: "#ffffff",
            error_container: "#ffdad6",
            on_error_container: "#410002",
            background: "#f9f9ff",
            on_background: "#1a1b20",
            surface: "#f9f9ff",
            on_surface: "#1a1b20",
            surface_variant: "#e1e2ec",
            on_surface_variant: "#44474f",
            surface_dim: "#d9d9e0",
            surface_bright: "#f9f9ff",
            surface_container_lowest: "#ffffff",
            surface_container_low: "#f3f3fa",
            surface_container: "#ededf4",
            surface_container_high: "#e8e7ee",
            surface_container_highest: "#e2e2e9",
            surface_tint: "#445e91",
            inverse_surface: "#2f3036",
            inverse_on_surface: "#f0f0f7",
            outline: "#74777f",
            outline_variant: "#c4c6d0",
            shadow: "#000000",
            scrim: "#000000"
        })

    // Недостающие в схеме роли берутся из базовой палитры
    readonly property var p: {
        const s = dark ? scheme.dark : scheme.light;
        const base = dark ? fallbackDark : fallbackLight;
        return s && s.primary ? Object.assign({}, base, s) : base;
    }
    readonly property color sourceColor: scheme.source ?? "#4285f4"

    readonly property color primary: p.primary
    readonly property color fgPrimary: p.on_primary
    readonly property color primaryContainer: p.primary_container
    readonly property color fgPrimaryContainer: p.on_primary_container
    readonly property color primaryFixed: p.primary_fixed
    readonly property color primaryFixedDim: p.primary_fixed_dim
    readonly property color fgPrimaryFixed: p.on_primary_fixed
    readonly property color inversePrimary: p.inverse_primary
    readonly property color secondary: p.secondary
    readonly property color fgSecondary: p.on_secondary
    readonly property color secondaryContainer: p.secondary_container
    readonly property color fgSecondaryContainer: p.on_secondary_container
    readonly property color tertiary: p.tertiary
    readonly property color fgTertiary: p.on_tertiary
    readonly property color tertiaryContainer: p.tertiary_container
    readonly property color fgTertiaryContainer: p.on_tertiary_container
    readonly property color error: p.error
    readonly property color fgError: p.on_error
    readonly property color errorContainer: p.error_container
    readonly property color fgErrorContainer: p.on_error_container
    readonly property color background: p.background
    readonly property color surface: p.surface
    readonly property color fgSurface: p.on_surface
    readonly property color surfaceVariant: p.surface_variant
    readonly property color fgSurfaceVariant: p.on_surface_variant
    readonly property color surfaceDim: p.surface_dim
    readonly property color surfaceBright: p.surface_bright
    readonly property color surfaceContainerLowest: p.surface_container_lowest
    readonly property color surfaceContainerLow: p.surface_container_low
    readonly property color surfaceContainer: p.surface_container
    readonly property color surfaceContainerHigh: p.surface_container_high
    readonly property color surfaceContainerHighest: p.surface_container_highest
    readonly property color inverseSurface: p.inverse_surface
    readonly property color inverseOnSurface: p.inverse_on_surface
    readonly property color outline: p.outline
    readonly property color outlineVariant: p.outline_variant
    readonly property color shadow: p.shadow
    readonly property color scrim: p.scrim

    // Цвета-«пятна» для иконок в списке разделов настроек — как на Pixel,
    // где у каждого раздела свой тональный кружок.
    readonly property var accents: [
        {
            bg: primaryContainer,
            fg: fgPrimaryContainer
        },
        {
            bg: secondaryContainer,
            fg: fgSecondaryContainer
        },
        {
            bg: tertiaryContainer,
            fg: fgTertiaryContainer
        },
        {
            bg: dark ? "#4a2a1a" : "#ffdbc9",
            fg: dark ? "#ffdbc9" : "#341100"
        },
        {
            bg: dark ? "#1f3d2b" : "#c3f0cf",
            fg: dark ? "#c3f0cf" : "#002110"
        },
        {
            bg: dark ? "#4a2433" : "#ffd9e3",
            fg: dark ? "#ffd9e3" : "#3e001d"
        }
    ]

    // Фон выезжающих панелей: полупрозрачный, чтобы под ним было видно
    // размытие Hyprland (матовое стекло). Прозрачность — в «Рабочий стол и окна».
    readonly property color panel: alpha(surfaceContainer, panelOpacity)

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    // Слой состояния M3: цвет контента поверх фона с нужной прозрачностью.
    function layer(base, over, a) {
        return Qt.tint(base, alpha(over, a));
    }

    readonly property real hoverOpacity: 0.08
    readonly property real pressOpacity: 0.12

    // --- типографика -------------------------------------------------------

    // Начертание обычного текста оболочки — как во всей системе
    readonly property int fontWeight: ({
            Regular: Font.Normal,
            Medium: Font.Medium,
            Bold: Font.Bold
        })[fontWeightName] ?? Font.Medium
    // Выделенный текст (заголовки, кнопки) — на ступень жирнее обычного
    readonly property int strongWeight: Math.min(Font.Black, Math.max(Font.Medium, fontWeight + 100))
    // Размер из настроек масштабирует всю типографику оболочки (12 — как задумано)
    readonly property real textScale: Math.max(0.75, Math.min(1.5, (fontSize || 12) / 12))
    readonly property string iconFont: "Material Symbols Rounded"

    readonly property QtObject type: QtObject {
        readonly property int displayL: Math.round(57 * root.textScale)
        readonly property int displayM: Math.round(45 * root.textScale)
        readonly property int displayS: Math.round(36 * root.textScale)
        readonly property int headlineL: Math.round(32 * root.textScale)
        readonly property int headlineM: Math.round(28 * root.textScale)
        readonly property int headlineS: Math.round(24 * root.textScale)
        readonly property int titleL: Math.round(22 * root.textScale)
        readonly property int titleM: Math.round(16 * root.textScale)
        readonly property int titleS: Math.round(14 * root.textScale)
        readonly property int bodyL: Math.round(16 * root.textScale)
        readonly property int bodyM: Math.round(14 * root.textScale)
        readonly property int bodyS: Math.round(12 * root.textScale)
        readonly property int labelL: Math.round(14 * root.textScale)
        readonly property int labelM: Math.round(12 * root.textScale)
        readonly property int labelS: Math.round(11 * root.textScale)
    }

    // --- форма -------------------------------------------------------------

    readonly property QtObject radius: QtObject {
        readonly property int xs: 4
        readonly property int s: 8
        readonly property int m: 12
        readonly property int l: 16
        readonly property int xl: 28
        readonly property int xxl: 36
        readonly property int full: 999
    }

    // --- движение (M3 Expressive) ------------------------------------------

    readonly property QtObject anim: QtObject {
        readonly property real scale: root.animationScale
        readonly property int fast: 150 * scale
        readonly property int normal: 300 * scale
        readonly property int slow: 450 * scale
        readonly property int extraSlow: 600 * scale
        // cubic-bezier кривые Material 3
        readonly property var emphasized: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
        // «пружина» с лёгким перелётом — для раскрытия панелей
        readonly property var expressiveSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        readonly property var expressiveEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    }
}
