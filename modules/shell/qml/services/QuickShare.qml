pragma Singleton

// Quick Share с Android: связь со службой pixel-quickshare
// (modules/shell/quickshare) через её сокет, по строке JSON на сообщение.
// Согласие на входящие спрашивает сама служба уведомлением; здесь —
// видимость, поиск устройств и отправка из «Файлов» (окно modules/share).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    // Служба включена в «Системе» (services.quickShare)
    readonly property bool enabled: Nix.quickShare
    readonly property bool available: sock.connected
    property string name: ""
    property string visibility: "hidden" // visible | hidden | temporary
    property var trusted: [] // имена устройств, от которых приём без вопроса
    property var devices: [] // [{id, name, type, ble}]
    property var transfers: ({}) // id → {direction, state, device, files, total, done, …}
    property string lastError: ""

    // Окно отправки: файлы, которые ждут выбора устройства
    property var shareFiles: []
    readonly property bool shareOpen: shareFiles.length > 0

    readonly property var outgoing: Object.keys(transfers).map(id => transfers[id]).filter(t => t.direction === "out")

    readonly property string visibilityLabel: !available ? "Служба не запущена" : ({
            visible: "Видно всем",
            temporary: "Видно 1 минуту",
            hidden: "Скрыто"
        })[visibility] ?? visibility

    function share(files) {
        const list = (files ?? []).map(f => String(f).replace(/^file:\/\//, "")).filter(f => f);
        if (list.length)
            shareFiles = list;
    }
    function closeShare() {
        shareFiles = [];
    }

    function setVisibility(v) {
        cmd({
            cmd: "visibility",
            value: v
        });
    }
    // Плитка: скрыто → видно всем → скрыто
    function toggleVisible() {
        setVisibility(visibility === "hidden" ? "visible" : "hidden");
    }
    function sendTo(device, files) {
        lastError = "";
        cmd({
            cmd: "send",
            device: device,
            files: files
        });
    }
    function trust(device, on) {
        cmd({
            cmd: "trust",
            name: device,
            on: on
        });
    }
    // Служба сохранит имя и перезапустится
    function rename(n) {
        cmd({
            cmd: "rename",
            name: n
        });
    }
    function accept(id) {
        cmd({
            cmd: "accept",
            id: id
        });
    }
    function decline(id) {
        cmd({
            cmd: "decline",
            id: id
        });
    }
    function cancel(id) {
        cmd({
            cmd: "cancel",
            id: id
        });
    }

    function cmd(o) {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify(o) + "\n");
        sock.flush();
    }

    function handle(line) {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (ev.ev) {
        case "hello":
            name = ev.name;
            visibility = ev.visibility;
            trusted = ev.trusted ?? [];
            break;
        case "device":
            devices = [...devices.filter(d => d.id !== ev.id), ev].sort((a, b) => a.name.localeCompare(b.name));
            break;
        case "device-gone":
            devices = devices.filter(d => d.id !== ev.id);
            break;
        case "transfer":
            {
                const t = Object.assign({}, transfers);
                t[ev.id] = ev;
                transfers = t;
                break;
            }
        case "error":
            lastError = ev.message;
            break;
        }
    }
    function forget(id) {
        const t = Object.assign({}, transfers);
        delete t[id];
        transfers = t;
    }

    // Поиск устройств — пока открыто окно отправки. Служба сама выключит
    // его, если оболочка отключится.
    onShareOpenChanged: discover()
    function discover() {
        cmd({
            cmd: "discover",
            on: shareOpen
        });
        if (!shareOpen)
            devices = [];
    }

    Socket {
        id: sock
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pixel-quickshare.sock"
        connected: root.enabled
        onConnectedChanged: {
            if (connected) {
                if (root.shareOpen)
                    root.discover();
            } else {
                root.devices = [];
                root.transfers = {};
            }
        }
        parser: SplitParser {
            onRead: line => root.handle(line)
        }
    }
    // Служба стартует позже оболочки или перезапускается
    Timer {
        interval: 5000
        repeat: true
        running: root.enabled && !sock.connected
        onTriggered: {
            sock.connected = false;
            sock.connected = true;
        }
    }
}
