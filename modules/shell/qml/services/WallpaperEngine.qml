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
    // Экраны с живыми обоями: [{ screen, dir }]
    readonly property var targets: {
        const _ = Settings.data.screenWallpapers;
        const __ = Settings.data.wallpaperType + Settings.data.engineWallpaper;
        return Quickshell.screens.map(s => ({
                    screen: s.name,
                    w: Wallpapers.forScreen(s.name)
                })).filter(t => t.w.type === "engine" && t.w.engine).map(t => ({
                    screen: t.screen,
                    dir: t.w.engine
                }));
    }
    readonly property bool active: targets.length > 0
    readonly property var current: items.find(i => i.dir === Wallpapers.current.engine) ?? null
    property string lastError: ""
    // Пока не знаем тип обоев (видео или сцена) — ничего не запускаем
    property bool scanned: false

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
                    jq -r --arg d "$d" '["item", $d, (.title // ""), ((.type // "") | ascii_downcase), (.preview // ""), (.file // "")] | @tsv' "$d/project.json" 2>/dev/null
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
                    // Одна и та же папка находится и через ~/.steam/steam, и через
                    // ~/.local/share/Steam — сравниваем по ID из мастерской.
                    if (f[0] !== "item")
                        continue;
                    const id = f[1].split("/").pop();
                    if (seen[id])
                        continue;
                    seen[id] = true;
                    list.push({
                        dir: f[1],
                        id: f[1].split("/").pop(),
                        title: f[2] || f[1].split("/").pop(),
                        type: f[3] || "scene",
                        preview: f[4] ? f[1] + "/" + f[4] : "",
                        // сам видеофайл обоев (для type = video)
                        file: f[5] ? f[1] + "/" + f[5] : ""
                    });
                }
                root.items = list.sort((a, b) => a.title.localeCompare(b.title));
                root.scanned = true;
            }
        }
    }

    function apply(item) {
        Wallpapers.apply({
            type: "engine",
            engine: item.dir,
            preview: item.preview
        });
    }

    // Общие параметры для всех мониторов
    readonly property var baseArgs: {
        const d = Settings.data;
        const a = ["--fps", String(d.engineFps)];
        if (d.engineSilent)
            a.push("--silent");
        else
            a.push("--volume", String(d.engineVolume));
        if (!d.enginePauseFullscreen)
            a.push("--no-fullscreen-pause");
        else
            a.push("--fullscreen-pause-only-active");
        if (assetsDir)
            a.push("--assets-dir", assetsDir);
        return a;
    }

    // Как показывать обои на экране:
    //   video — сам видеофайл через mpvpaper (mpv, аппаратное декодирование,
    //           без перекодированных превью и с честным качеством);
    //   scene / web — linux-wallpaperengine.
    function commandFor(screen, dir) {
        const d = Settings.data;
        const item = items.find(i => i.dir === dir);
        if (item && item.type === "video" && item.file) {
            const opts = ["loop", "hwdec=auto", "keep-open=yes"];
            opts.push(d.engineSilent ? "no-audio" : "volume=" + d.engineVolume);
            if (d.engineScaling === "fill")
                opts.push("panscan=1.0");
            else if (d.engineScaling === "stretch")
                opts.push("keepaspect=no");
            const cmd = ["mpvpaper", "-l", "bottom", "-p"];
            if (d.enginePauseFullscreen)
                cmd.push("-a", "full");
            cmd.push("-o", opts.join(" "), screen, item.file);
            return cmd;
        }
        return ["linux-wallpaperengine", ...baseArgs, "--scaling", d.engineScaling, "--screen-root", screen, "--bg", dir];
    }

    // Отдельный процесс на каждый монитор: смена обоев на одном экране не
    // перезапускает другой, а разные обои на разных экранах в одном процессе
    // linux-wallpaperengine показывает с ошибками.
    Variants {
        // Ключ — готовая команда: изменилась — пересоздаётся только процесс
        // этого экрана.
        model: root.scanned ? root.targets.map(t => JSON.stringify([t.screen, ...root.commandFor(t.screen, t.dir)])) : []

        Scope {
            id: inst
            required property string modelData
            readonly property var parts: JSON.parse(modelData)

            Process {
                id: proc
                running: true
                command: inst.parts.slice(1)
                stderr: StdioCollector {
                    onStreamFinished: {
                        const t = text.trim().split("\n").filter(l => /error|fail|cannot|could not/i.test(l)).slice(-3).join("\n");
                        if (t)
                            root.lastError = inst.parts[0] + ": " + t;
                    }
                }
                onExited: code => {
                    // упал сам — попробуем ещё раз чуть позже
                    if (code !== 0 && code !== 15 && code !== 143)
                        retry.restart();
                }
            }
            Timer {
                id: retry
                interval: 5000
                onTriggered: proc.running = true
            }
        }
    }
}
