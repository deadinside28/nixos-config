pragma Singleton

// Bluetooth через BlueZ (Quickshell.Bluetooth).
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: adapter ? adapter.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)) : []
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
    readonly property var available_: devices.filter(d => !d.paired && !d.bonded && d.name && d.name !== d.address.replace(/:/g, "-"))
    readonly property var connected: devices.filter(d => d.connected)

    readonly property string icon: !enabled ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"
    readonly property string label: !available ? "Нет адаптера" : !enabled ? "Выключен" : connected.length === 1 ? connected[0].name : connected.length > 1 ? connected.length + " устройства" : "Включён"

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }
    function discover(on) {
        if (adapter && adapter.enabled)
            adapter.discovering = on;
    }
    function deviceIcon(d) {
        const i = d?.icon ?? "";
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("audio"))
            return "speaker";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("mouse"))
            return "mouse";
        if (i.includes("phone"))
            return "smartphone";
        if (i.includes("gaming") || i.includes("joystick"))
            return "stadia_controller";
        if (i.includes("computer"))
            return "computer";
        return "bluetooth";
    }
}
