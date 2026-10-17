pragma Singleton

// Сеть через NetworkManager (Quickshell.Networking).
import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool hasWifi: wifiDevice !== null

    readonly property var networks: wifiDevice ? wifiDevice.networks.values.slice().sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property var activeWifi: networks.find(n => n.connected) ?? null
    readonly property bool wiredConnected: wiredDevice?.connected ?? false

    readonly property bool online: wiredConnected || activeWifi !== null
    readonly property int connectivity: Networking.connectivity

    readonly property string icon: {
        if (wiredConnected)
            return "lan";
        if (!wifiEnabled || !hasWifi)
            return hasWifi ? "wifi_off" : "lan";
        if (!activeWifi)
            return "wifi_find";
        return signalIcon(activeWifi.signalStrength);
    }
    readonly property string label: wiredConnected ? "Ethernet" : activeWifi ? activeWifi.name : (wifiEnabled && hasWifi ? "Не подключено" : hasWifi ? "Wi‑Fi выключен" : "Нет сети")
    readonly property string sublabel: wiredConnected ? (wiredDevice.linkSpeed > 0 ? wiredDevice.linkSpeed + " Мбит/с" : "Подключено") : activeWifi ? "Подключено" : ""

    function signalIcon(s) {
        if (s > 0.75)
            return "signal_wifi_4_bar";
        if (s > 0.5)
            return "network_wifi_3_bar";
        if (s > 0.25)
            return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }
    function secured(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown;
    }
    function setWifi(on) {
        Networking.wifiEnabled = on;
    }
    function scan(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }
}
