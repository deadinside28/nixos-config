pragma Singleton

// Яркость: подсветка ноутбука (brightnessctl) и внешние мониторы по
// DDC/CI (ddcutil). У каждого монитора своя яркость.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    // [{ name, bus, value (0…1), max }] — name: имя выхода (HDMI-A-1) или "backlight"
    property var monitors: []
    readonly property bool available: monitors.length > 0
    // Яркость экрана с фокусом (для быстрых настроек и OSD)
    readonly property var focused: monitors.find(m => m.name === Ui.focusedScreen) ?? monitors.find(m => m.name === "backlight") ?? monitors[0] ?? null
    readonly property real value: focused?.value ?? 0
    property bool detecting: false
    // Для OSD: яркость поменяли руками (а не при опросе мониторов)
    signal changedByUser

    function refresh() {
        detecting = true;
        detect.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: detect
        command: ["sh", "-c", `
            # подсветка ноутбука
            if b=$(brightnessctl -m -c backlight info 2>/dev/null | head -1); then
                [ -n "$b" ] && echo "backlight $(echo "$b" | cut -d, -f3) $(echo "$b" | cut -d, -f5)"
            fi
            # внешние мониторы: шина i2c → разъём DRM → текущая яркость (VCP 10)
            ddcutil detect --terse 2>/dev/null | awk '
                /I2C bus:/ { bus = $NF; sub(".*-", "", bus) }
                /DRM connector:/ { con = $NF; sub("^card[0-9]+-", "", con); print bus, con }
            ' | while read -r bus con; do
                v=$(ddcutil getvcp 10 --bus "$bus" --terse 2>/dev/null)
                set -- $v
                [ "$1" = VCP ] && echo "$con $4 $5 $bus"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.detecting = false;
                root.monitors = text.split("\n").filter(l => l.trim()).map(l => {
                    const [name, cur, max, bus] = l.trim().split(/\s+/);
                    return {
                        name,
                        bus: bus ?? "",
                        max: parseInt(max) || 100,
                        value: (parseInt(cur) || 0) / (parseInt(max) || 100)
                    };
                });
            }
        }
    }

    function valueFor(name) {
        return monitors.find(m => m.name === name)?.value ?? 0;
    }

    // Поставить яркость монитору (name не указан — экрану с фокусом)
    function set(v, name) {
        const target = name ?? focused?.name;
        const i = monitors.findIndex(m => m.name === target);
        if (i < 0)
            return;
        const list = monitors.slice();
        list[i] = Object.assign({}, list[i], {
            value: Math.max(0.01, Math.min(1, v))
        });
        monitors = list;
        changedByUser();
        pending[target] = true;
        applyTimer.restart();
    }
    property var pending: ({})

    // DDC медленный: шлём не чаще раза в 150 мс и только последнее значение
    Timer {
        id: applyTimer
        interval: 150
        onTriggered: {
            for (const name of Object.keys(root.pending)) {
                const m = root.monitors.find(x => x.name === name);
                if (!m)
                    continue;
                const raw = Math.round(m.value * m.max);
                if (name === "backlight")
                    Quickshell.execDetached(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(m.value * 100) + "%"]);
                else
                    Quickshell.execDetached(["ddcutil", "setvcp", "10", String(raw), "--bus", m.bus, "--noverify"]);
            }
            root.pending = {};
        }
    }
}
