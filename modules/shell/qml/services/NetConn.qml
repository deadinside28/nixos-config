pragma Singleton

// Сохранённые соединения NetworkManager через nmcli: список, подробности
// (адреса, DNS), правка IPv4/IPv6, автоподключение, удаление. Заменяет
// nm-connection-editor и апплет в трее.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ name, uuid, type, device, active, autoconnect }]
    property var connections: []
    property bool loading: false
    // uuid → { "ipv4.method": …, "IP4.ADDRESS[1]": …, … }
    property var details: ({})
    property string lastError: ""

    readonly property var typeNames: ({
            "802-3-ethernet": "Ethernet",
            "802-11-wireless": "Wi‑Fi",
            "wireguard": "WireGuard",
            "vpn": "VPN",
            "bridge": "Мост",
            "loopback": "Loopback",
            "tun": "Туннель",
            "gsm": "Мобильная сеть",
            "bluetooth": "Bluetooth"
        })
    readonly property var typeIcons: ({
            "802-3-ethernet": "lan",
            "802-11-wireless": "wifi",
            "wireguard": "vpn_lock",
            "vpn": "vpn_lock",
            "bridge": "device_hub",
            "loopback": "loop",
            "tun": "settings_ethernet",
            "gsm": "signal_cellular_alt",
            "bluetooth": "bluetooth"
        })
    // Служебные (docker, loopback) по умолчанию прячем
    function isService(c) {
        return ["bridge", "loopback", "tun", "veth", "dummy"].includes(c.type) || /^(docker|br-|virbr|veth|lo$)/.test(c.device || c.name);
    }

    // nmcli -t: «:» внутри значений экранирован как «\:»
    function splitTerse(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (ch === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    function refresh() {
        loading = true;
        list.running = false;
        list.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                root.connections = text.split("\n").filter(l => l).map(l => {
                    const [name, uuid, type, device, active, autoconnect] = root.splitTerse(l);
                    return {
                        name,
                        uuid,
                        type,
                        device,
                        active: active === "yes",
                        autoconnect: autoconnect === "yes"
                    };
                }).sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name));
            }
        }
    }

    function load(uuid) {
        const p = detailProc.createObject(root, {
            uuid
        });
        p.running = true;
    }
    property Component detailProc: Component {
        Process {
            id: dp
            property string uuid
            command: ["nmcli", "-t", "connection", "show", uuid]
            stdout: StdioCollector {
                onStreamFinished: {
                    const d = {};
                    for (const l of text.split("\n")) {
                        const i = l.indexOf(":");
                        if (i > 0)
                            d[l.slice(0, i)] = l.slice(i + 1).replace(/\\:/g, ":").replace(/\\\\/g, "\\");
                    }
                    const all = Object.assign({}, root.details);
                    all[dp.uuid] = d;
                    root.details = all;
                    dp.destroy();
                }
            }
        }
    }

    // Все значения поля вида IP4.DNS[1], IP4.DNS[2]…
    function multi(d, key) {
        return Object.keys(d ?? {}).filter(k => k.startsWith(key + "[")).sort().map(k => d[k]).filter(v => v);
    }

    // nmcli с последующим обновлением списка; ошибки — в lastError
    function nm(args, uuid) {
        const p = runProc.createObject(root, {
            args,
            uuid: uuid ?? ""
        });
        p.running = true;
    }
    property Component runProc: Component {
        Process {
            id: rp
            property var args: []
            property string uuid
            command: ["nmcli", ...args]
            stderr: StdioCollector {
                id: err
            }
            onExited: code => {
                root.lastError = code === 0 ? "" : err.text.trim().replace(/^Error: /, "");
                root.refresh();
                if (rp.uuid)
                    root.load(rp.uuid);
                rp.destroy();
            }
        }
    }

    function up(uuid) {
        nm(["connection", "up", "uuid", uuid], uuid);
    }
    function down(uuid) {
        nm(["connection", "down", "uuid", uuid], uuid);
    }
    function remove(uuid) {
        nm(["connection", "delete", "uuid", uuid]);
    }
    // props: { "ipv4.method": "manual", … }; reapply — переподключить, если активно
    function modify(c, props) {
        const args = ["connection", "modify", "uuid", c.uuid];
        for (const k of Object.keys(props))
            args.push(k, String(props[k]));
        if (c.active) {
            // применить сразу: modify + up одной цепочкой
            const p = runProc.createObject(root, {
                args,
                uuid: c.uuid
            });
            p.exited.connect(code => {
                if (code === 0)
                    root.up(c.uuid);
            });
            p.running = true;
        } else {
            nm(args, c.uuid);
        }
    }
    function hotspot(ssid, password) {
        nm(["device", "wifi", "hotspot", "ssid", ssid, "password", password]);
    }
}
