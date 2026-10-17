pragma Singleton

// Что поменялось в последнем обновлении: nix store diff-closures между
// предыдущим и текущим поколением системы. Показывается в панели задач,
// пока не отметишь «Просмотрено».
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property int generation: 0
    property int previous: 0
    // [{ name, from, to, kind: "updated" | "added" | "removed", size }]
    property var changes: []
    readonly property var updated: changes.filter(c => c.kind === "updated")
    readonly property int count: changes.filter(c => c.kind !== "removed").length
    readonly property bool unseen: generation > 0 && count > 0 && Settings.data.updatesSeen !== generation
    property bool loading: false

    function markSeen() {
        Settings.data.updatesSeen = generation;
    }
    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: proc
        onRunningChanged: root.loading = running
        command: ["sh", "-c", `
            cur=$(readlink /nix/var/nix/profiles/system) || exit 0
            n=\${cur#system-}; n=\${n%-link}
            prev=$(for l in /nix/var/nix/profiles/system-*-link; do p=\${l##*/system-}; echo "\${p%-link}"; done | sort -n | awk -v n="$n" '$1 < n' | tail -n 1)
            echo "#gen $n \${prev:-0}"
            [ -n "$prev" ] && nix store diff-closures "/nix/var/nix/profiles/system-$prev-link" "/nix/var/nix/profiles/system-$n-link" 2>/dev/null
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (let line of text.split("\n")) {
                    line = line.replace(/\x1b\[[0-9;]*m/g, "").trim();
                    let m = line.match(/^#gen (\d+) (\d+)$/);
                    if (m) {
                        root.generation = parseInt(m[1]);
                        root.previous = parseInt(m[2]);
                        continue;
                    }
                    // firefox: 130.0 → 131.0, +2.3 MiB   |   foo: ∅ → 1.2
                    m = line.match(/^(.+?): (.+?) → (.+?)(?:, ([+-][\d.]+ \S+))?$/);
                    if (!m)
                        continue;
                    const from = m[2].replace(/ε/g, "").trim(), to = m[3].replace(/ε/g, "").trim();
                    const kind = from === "∅" ? "added" : to === "∅" ? "removed" : "updated";
                    out.push({
                        name: m[1],
                        from: from === "∅" ? "" : from,
                        to: to === "∅" ? "" : to,
                        kind,
                        size: m[4] ?? ""
                    });
                }
                // сначала обновлённые, потом новые, потом удалённые
                const order = {
                    updated: 0,
                    added: 1,
                    removed: 2
                };
                out.sort((a, b) => order[a.kind] - order[b.kind] || a.name.localeCompare(b.name));
                root.changes = out;
            }
        }
    }
}
