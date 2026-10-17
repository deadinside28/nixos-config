pragma Singleton

// Живые обои Wallpaper Engine через linux-wallpaperengine.
//
// Обои берутся из мастерской Steam (приложение 431960) во всех
// библиотеках Steam — родной, Flatpak и дополнительных дисках из
// libraryfolders.vdf. Ресурсы самого Wallpaper Engine (assets) нужны
// для «сценовых» обоев: для этого Wallpaper Engine должен быть куплен
// и установлен в Steam (запускать его не нужно).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    // [{ dir, id, title, type, preview }]
    property var items: []
    property string assetsDir: ""
    property bool scanning: scan.running
    readonly property bool active: Settings.data.wallpaperType === "engine" && Settings.data.engineWallpaper !== ""
    readonly property var current: items.find(i => i.dir === Settings.data.engineWallpaper) ?? null
    property string lastError: ""

    function refresh() {
        scan.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: scan
        command: ["sh", "-c", `
            roots="$HOME/.local/share/Steam $HOME/.steam/steam $HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"
            libs=""
            for r in $roots; do
                [ -d "$r/steamapps" ] && libs="$libs
$(readlink -f "$r")"
                vdf="$r/steamapps/libraryfolders.vdf"
                [ -f "$vdf" ] && libs="$libs
$(sed -n 's/^[[:space:]]*"path"[[:space:]]*"\\(.*\\)"/\\1/p' "$vdf")"
            done
            echo "$libs" | sort -u | while read -r lib; do
                [ -n "$lib" ] || continue
                a="$lib/steamapps/common/wallpaper_engine/assets"
                [ -d "$a" ] && printf 'assets\\t%s\\n' "$a"
                for d in "$lib"/steamapps/workshop/content/431960/*/; do
                    [ -f "$d/project.json" ] || continue
                    d=\${d%/}
                    jq -r --arg d "$d" '["item", $d, (.title // ""), ((.type // "") | ascii_downcase), (.preview // "")] | @tsv' "$d/project.json" 2>/dev/null
                done
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const seen = {};
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "assets" && !root.assetsDir)
                        root.assetsDir = f[1];
                    if (f[0] !== "item" || seen[f[1]])
                        continue;
                    seen[f[1]] = true;
                    list.push({
                        dir: f[1],
                        id: f[1].split("/").pop(),
                        title: f[2] || f[1].split("/").pop(),
                        type: f[3] || "scene",
                        preview: f[4] ? f[1] + "/" + f[4] : ""
                    });
                }
                root.items = list.sort((a, b) => a.title.localeCompare(b.title));
            }
        }
    }

    function apply(item) {
        Settings.data.enginePreview = item.preview;
        Settings.data.engineWallpaper = item.dir;
        Settings.data.wallpaperType = "engine";
    }
    function stop() {
        Settings.data.wallpaperType = "image";
    }

    readonly property var command: {
        const d = Settings.data;
        const cmd = ["linux-wallpaperengine", "--fps", String(d.engineFps)];
        if (d.engineSilent)
            cmd.push("--silent");
        else
            cmd.push("--volume", String(d.engineVolume));
        if (!d.enginePauseFullscreen)
            cmd.push("--no-fullscreen-pause");
        else
            cmd.push("--fullscreen-pause-only-active");
        if (assetsDir)
            cmd.push("--assets-dir", assetsDir);
        for (const s of Quickshell.screens)
            cmd.push("--screen-root", s.name, "--bg", d.engineWallpaper, "--scaling", d.engineScaling);
        return cmd;
    }

    // Перезапуск при смене обоев или параметров
    onCommandChanged: if (proc.running)
        restart.restart()

    Process {
        id: proc
        running: root.active && Settings.loaded && !restart.running
        command: root.command
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim().split("\n").filter(l => /error|fail|cannot|could not/i.test(l)).slice(-3).join("\n");
                if (t)
                    root.lastError = t;
            }
        }
        onStarted: root.lastError = ""
        onExited: code => {
            // упал сам — попробуем ещё раз чуть позже
            if (root.active && code !== 0 && code !== 15)
                crashRestart.restart();
        }
    }
    Timer {
        id: restart
        interval: 400
    }
    Timer {
        id: crashRestart
        interval: 5000
        onTriggered: if (root.active && !proc.running)
            restart.restart()
    }
}
