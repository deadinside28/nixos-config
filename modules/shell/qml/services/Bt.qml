pragma Singleton

// Bluetooth через BlueZ (Quickshell.Bluetooth).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.common

Singleton {
    id: root

    // Адаптеров бывает несколько: встроенный в плату (часто нерабочий или
    // выключенный) и USB-свисток. «По умолчанию» у BlueZ — просто первый в
    // списке, поэтому берём выбранный в настройках, иначе включённый.
    readonly property var adapters: Bluetooth.adapters.values
    readonly property var adapter: adapters.find(a => a.adapterId === Settings.data.btAdapter) ?? adapters.find(a => a.enabled) ?? Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    function chooseAdapter(a) {
        Settings.data.btAdapter = a.adapterId;
    }
    function adapterLabel(a) {
        return a.adapterId + (a.name && a.name !== a.adapterId ? " · " + a.name : "");
    }
    readonly property var devices: adapter ? adapter.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)) : []
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
    readonly property var available_: devices.filter(d => !d.paired && !d.bonded && d.name && d.name !== d.address.replace(/:/g, "-"))
    readonly property var connected: devices.filter(d => d.connected)

    readonly property string icon: !enabled ? "bluetooth_disabled" : connected.length > 0 ? "bluetooth_connected" : "bluetooth"
    readonly property string label: !available ? "Нет адаптера" : blocked ? "Заблокирован" : !enabled ? "Выключен" : connected.length === 1 ? connected[0].name : connected.length > 1 ? connected.length + " устройства" : "Включён"

    function setEnabled(on) {
        if (!adapter)
            return;
        // Программная блокировка rfkill (режим «в самолёте», кнопка на
        // ноутбуке) не даёт включить адаптер через BlueZ — снимаем её
        if (on && blocked)
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
        adapter.enabled = on;
    }

    // --- Диагностика, когда адаптера не видно -----------------------------
    // service — состояние bluetooth.service; hci — адаптеры, которые видит
    // ядро; rfkill — блокировки. Ядро адаптер видит, а оболочка нет — значит
    // BlueZ стартовал позже оболочки, и её нужно перезапустить.
    property var diag: ({
            service: "",
            hci: [],
            hardBlocked: false
        })
    function diagnose() {
        diagProc.running = true;
    }
    function startService() {
        // systemctl сам спросит пароль через агент polkit оболочки
        Quickshell.execDetached(["sh", "-c", "systemctl start bluetooth.service; rfkill unblock bluetooth"]);
        Qt.callLater(diagnose);
    }
    Process {
        id: diagProc
        command: ["sh", "-c", 'echo "service=$(systemctl is-active bluetooth.service)"; for d in /sys/class/bluetooth/hci*; do [ -e "$d" ] && echo "hci=${d##*/}"; done; rfkill -rn -o TYPE,HARD 2>/dev/null | while read -r t h; do [ "$t" = bluetooth ] && echo "hard=$h"; done; true']
        stdout: StdioCollector {
            onStreamFinished: {
                const d = {
                    service: "",
                    hci: [],
                    hardBlocked: false
                };
                for (const l of text.split("\n")) {
                    const [k, v] = [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)];
                    if (k === "service")
                        d.service = v;
                    else if (k === "hci")
                        d.hci.push(v);
                    else if (k === "hard" && v === "blocked")
                        d.hardBlocked = true;
                }
                root.diag = d;
            }
        }
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
