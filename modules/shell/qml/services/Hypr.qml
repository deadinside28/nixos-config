pragma Singleton

// Помощники Hyprland: воркспейсы экрана, переключение, окна.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function workspacesFor(screenName) {
        return Hyprland.workspaces.values.filter(ws => ws.id > 0 && ws.monitor?.name === screenName).sort((a, b) => a.id - b.id);
    }
    function activeWorkspaceFor(screenName) {
        return Hyprland.monitors.values.find(m => m.name === screenName)?.activeWorkspace ?? null;
    }
    function focusWorkspace(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }
    function focusWindow(address) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${address}" })`);
    }
    function closeWindow(address) {
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:0x${address}" })`);
    }
    function exit() {
        Hyprland.dispatch("hl.dsp.exit()");
    }
    function dpms(on) {
        Hyprland.dispatch(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`);
    }
}
