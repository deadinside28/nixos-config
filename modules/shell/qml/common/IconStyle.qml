pragma Singleton

// Значки приложений как на Pixel: обычные, в форме (значок на подложке
// выбранной формы) или тематические — монохромные в цветах обоев.
// Формы — из набора Material 3 Expressive: круг, сквиркл, «печенье»,
// клевер, «солнышко»… Контуры считаются один раз в единичном квадрате
// 100×100 и масштабируются под размер значка.
import QtQuick
import Quickshell
import Pixel.MD3E

Singleton {
    id: root

    readonly property string style: Settings.data.iconStyle // original | shaped | themed
    readonly property string shape: Settings.data.iconShape
    readonly property string colorRole: Settings.data.iconColor

    readonly property var shapes: [
        {
            value: "circle",
            label: "Круг"
        },
        {
            value: "squircle",
            label: "Сквиркл"
        },
        {
            value: "rounded",
            label: "Квадрат"
        },
        {
            value: "cookie4",
            label: "Печенье"
        },
        {
            value: "cookie9",
            label: "Цветок"
        },
        {
            value: "clover",
            label: "Клевер"
        },
        {
            value: "sunny",
            label: "Солнышко"
        },
        {
            value: "pebble",
            label: "Камешек"
        }
    ]

    // Радиус формы в направлении угла t (единичный круг = 1)
    function radius(name, t) {
        const sup = n => Math.pow(Math.pow(Math.abs(Math.cos(t)), n) + Math.pow(Math.abs(Math.sin(t)), n), -1 / n);
        switch (name) {
        case "squircle":
            return sup(4);
        case "rounded":
            return sup(9);
        case "cookie4":
            return 1 + 0.09 * Math.cos(4 * t);
        case "cookie9":
            return 1 + 0.07 * Math.cos(9 * t);
        case "clover":
            return 1 + 0.12 * Math.cos(4 * t) - 0.02 * Math.cos(8 * t);
        case "sunny":
            return 1 + 0.045 * Math.cos(8 * t);
        case "pebble":
            return 1 + 0.06 * Math.cos(2 * t + 0.6) + 0.04 * Math.cos(3 * t);
        default:
            return 1;
        }
    }
    function compute(name) {
        const n = 180;
        const pts = [];
        for (let i = 0; i <= n; i++) {
            const t = i / n * 2 * Math.PI;
            const r = radius(name, t);
            pts.push([Math.cos(t) * r, Math.sin(t) * r]);
        }
        // вписать в квадрат 100×100 с центром посередине
        const ext = Math.max(...pts.map(p => Math.max(Math.abs(p[0]), Math.abs(p[1]))));
        return pts.map(p => Qt.point(50 + p[0] / ext * 50, 50 + p[1] / ext * 50));
    }
    // Все контуры считаются один раз при старте
    readonly property var cache: {
        const c = {};
        for (const s of shapes)
            c[s.value] = compute(s.value);
        return c;
    }
    function points(name) {
        return cache[name] ?? cache.circle;
    }

    // Подложка и цвет значка
    readonly property var roles: [
        {
            value: "primary",
            label: "Акцент"
        },
        {
            value: "secondary",
            label: "Приглушённый"
        },
        {
            value: "tertiary",
            label: "Дополнительный"
        },
        {
            value: "neutral",
            label: "Нейтральный"
        }
    ]
    function bgFor(role, st) {
        if ((st ?? style) === "shaped" && role === "neutral")
            return Theme.dark ? Theme.surfaceContainerHighest : "#ffffff";
        return ({
                primary: Theme.primaryContainer,
                secondary: Theme.secondaryContainer,
                tertiary: Theme.tertiaryContainer,
                neutral: Theme.surfaceContainerHighest
            })[role] ?? Theme.primaryContainer;
    }
    function fgFor(role) {
        return ({
                primary: Theme.fgPrimaryContainer,
                secondary: Theme.fgSecondaryContainer,
                tertiary: Theme.fgTertiaryContainer,
                neutral: Theme.primary
            })[role] ?? Theme.fgPrimaryContainer;
    }
    readonly property color bg: bgFor(colorRole)
    readonly property color fg: fgFor(colorRole)
}
