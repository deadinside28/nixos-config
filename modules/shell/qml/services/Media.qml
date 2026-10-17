pragma Singleton

// Плееры MPRIS: активный — тот, что играет, иначе последний живой.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var manual: null
    readonly property var active: {
        if (manual && players.includes(manual))
            return manual;
        return players.find(p => p.isPlaying) ?? players[0] ?? null;
    }
    readonly property bool hasPlayer: active !== null

    function next() {
        if (players.length < 2)
            return;
        const i = players.indexOf(active);
        manual = players[(i + 1) % players.length];
    }
}
