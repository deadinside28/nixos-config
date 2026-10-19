pragma Singleton

// Звук через PipeWire: устройство по умолчанию, громкость, приложения.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    // Громкость в интерфейсе — в кубической шкале, как у wpctl, pavucontrol
    // и клавиш громкости (binds.lua): PipeWire хранит линейный множитель, и
    // «50%» на клавишах — это 0.125 в узле. Линейный ползунок отдавал почти
    // весь ход тихой части, а клавиши и индикатор расходились вчетверо.
    function toUi(linear) {
        return Math.cbrt(Math.max(0, linear ?? 0));
    }
    function fromUi(v) {
        return Math.pow(Math.max(0, Math.min(1, v)), 3);
    }
    readonly property real volume: toUi(sink?.audio?.volume)
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: toUi(source?.audio?.volume)
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !(n.name ?? "").includes(".monitor"))
    // Тип узла известен сразу, а свойства (имя приложения и т.п.) приходят
    // только после того, как узел начали отслеживать (PwObjectTracker ниже).
    readonly property var playbackStreams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream)

    readonly property string icon: muted || volume <= 0 ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"

    // Без трекера PipeWire не отдаёт громкость и mute узлов.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.playbackStreams]
    }

    function setVolume(v) {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = fromUi(v);
        }
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function setMicVolume(v) {
        if (source?.audio) {
            source.audio.muted = false;
            source.audio.volume = fromUi(v);
        }
    }
    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function nodeName(n) {
        return n?.nickname || n?.description || n?.name || "";
    }
    // --- Громкость приложений -------------------------------------------
    //
    // Один плеер может открыть несколько потоков (у linux-wallpaperengine —
    // по одному на монитор), поэтому потоки группируются по приложению.
    // Приложение ищем так: Flatpak app_id → окно Hyprland того же процесса
    // или его родителя (Electron и Chromium играют звук из дочерних
    // процессов, а имя у потока — «Chromium»/«electron») → имя бинарника.

    // pid → [{ pid, comm, exe }] — цепочка родителей процесса
    property var ancestry: ({})

    readonly property var streamPids: [...new Set(playbackStreams.map(n => n.properties["application.process.id"]).filter(p => p))].sort()
    onStreamPidsChanged: resolveTimer.restart()

    Timer {
        id: resolveTimer
        interval: 200
        onTriggered: {
            const pids = root.streamPids.filter(p => !(p in root.ancestry));
            if (pids.length === 0)
                return;
            resolver.command = ["sh", "-c", `
                for p in "$@"; do
                    line="$p"; q=$p
                    for i in 1 2 3 4 5 6 7 8; do
                        [ -r /proc/$q/stat ] || break
                        comm=$(cat /proc/$q/comm 2>/dev/null)
                        exe=$(basename "$(readlink /proc/$q/exe 2>/dev/null)")
                        line="$line	$q:$comm:$exe"
                        q=$(sed 's/.*) //' /proc/$q/stat | cut -d' ' -f2)
                        [ "$q" -le 1 ] && break
                    done
                    printf '%b\n' "$line"
                done`, "sh", ...pids];
            resolver.running = true;
        }
    }
    Process {
        id: resolver
        stdout: StdioCollector {
            onStreamFinished: {
                const a = Object.assign({}, root.ancestry);
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (!f[0])
                        continue;
                    a[f[0]] = f.slice(1).map(x => {
                        const [pid, comm, exe] = x.split(":");
                        return {
                            pid,
                            comm,
                            exe
                        };
                    });
                }
                root.ancestry = a;
            }
        }
    }

    // pid окна → класс окна
    readonly property var windowPids: {
        const m = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject ?? {};
            if (o.pid)
                m[String(o.pid)] = o.class || o.initialClass || "";
        }
        return m;
    }

    function clean(name) {
        return String(name ?? "").replace(/^\./, "").replace(/-wrapped$|-bin$|\.bin$|\.exe$/i, "").trim();
    }
    // .desktop по имени, но только если он правда похож на это имя
    function entryFor(name) {
        const n = clean(name).toLowerCase();
        if (!n || ["electron", "chromium", "chrome", "python3", "python", "java", "wine", "wine64-preloader", "pipewire", "sh", "bash"].includes(n))
            return null;
        const e = DesktopEntries.byId(n) ?? DesktopEntries.heuristicLookup(n);
        if (!e)
            return null;
        const hay = (e.id + " " + e.name + " " + (e.startupClass ?? "") + " " + e.execString).toLowerCase();
        return hay.includes(n) ? e : null;
    }

    function resolve(n) {
        const p = n.properties ?? {};
        const flatpak = p["pipewire.access.portal.app_id"];
        if (flatpak) {
            const e = DesktopEntries.byId(flatpak);
            if (e)
                return {
                    key: e.id,
                    name: e.name,
                    icon: e.icon
                };
        }
        const chain = ancestry[p["application.process.id"]] ?? [];
        for (const c of chain) {
            const cls = windowPids[c.pid];
            if (cls) {
                const e = Apps.forWindow(cls);
                if (e)
                    return {
                        key: e.id,
                        name: e.name,
                        icon: e.icon
                    };
            }
        }
        const candidates = [p["application.process.binary"], ...chain.map(c => c.exe), ...chain.map(c => c.comm), p["application.name"], p["node.name"]];
        for (const c of candidates) {
            const e = entryFor(c);
            if (e)
                return {
                    key: e.id,
                    name: e.name,
                    icon: e.icon
                };
        }
        // Известные приложения без .desktop
        const bin = clean(p["application.process.binary"] || p["application.name"]).toLowerCase();
        if (bin === "linux-wallpaperengine")
            return {
                key: "linux-wallpaperengine",
                name: "Живые обои",
                icon: "preferences-desktop-wallpaper"
            };
        const name = p["application.name"] || clean(p["application.process.binary"]) || nodeName(n);
        return {
            key: name.toLowerCase(),
            name,
            icon: p["application.icon-name"] || clean(p["application.process.binary"]).toLowerCase() || "audio-x-generic"
        };
    }

    // [{ key, name, icon, nodes: [PwNode], volume, muted }]
    readonly property var apps: {
        const _ = ancestry; // пересчитать, когда узнали родителей процессов
        const __ = DesktopEntries.applications.values.length;
        const groups = {};
        const order = [];
        for (const n of playbackStreams) {
            const r = resolve(n);
            if (!groups[r.key]) {
                groups[r.key] = Object.assign(r, {
                    nodes: []
                });
                order.push(r.key);
            }
            groups[r.key].nodes.push(n);
        }
        return order.map(k => {
            const g = groups[k];
            const vols = g.nodes.map(n => n.audio?.volume ?? 0);
            g.volume = toUi(Math.max(...vols));
            g.muted = g.nodes.every(n => n.audio?.muted);
            return g;
        });
    }

    // Списки в интерфейсе строятся по ключам (ScriptModel сравнивает строки),
    // а сам объект берётся отсюда. Иначе каждое движение громкости пересоздавало
    // строки микшера, и слайдер нельзя было тянуть — только нажать.
    readonly property var appKeys: apps.map(a => a.key)
    readonly property var emptyApp: ({
            key: "",
            name: "",
            icon: "",
            nodes: [],
            volume: 0,
            muted: false
        })
    function appByKey(k) {
        return apps.find(a => a.key === k) ?? emptyApp;
    }

    function setAppVolume(app, v) {
        for (const n of app.nodes)
            if (n.audio) {
                n.audio.muted = false;
                n.audio.volume = fromUi(v);
            }
    }
    function toggleAppMute(app) {
        const m = !app.muted;
        for (const n of app.nodes)
            if (n.audio)
                n.audio.muted = m;
    }
    // Вывод приложения на другое устройство: WirePlumber переносит потоки
    // по метаданным target.object. В свойствах узла перенос не виден, поэтому
    // выбранное устройство запоминается здесь (по ключу приложения).
    property var appTargets: ({})
    function moveApp(app, sink) {
        for (const n of app.nodes)
            Quickshell.execDetached(["pw-metadata", String(n.id), "target.object", sink.name, "Spa:String"]);
        const t = Object.assign({}, appTargets);
        t[app.key] = sink.name;
        appTargets = t;
    }
    function appSinkId(app) {
        const p = app.nodes[0]?.properties ?? {};
        const target = appTargets[app.key] ?? p["target.object"] ?? p["node.target"];
        return sinks.find(s => s.name === target || String(s.id) === String(target))?.id ?? sink?.id;
    }

    // --- Профили звуковых карт ------------------------------------------
    //
    // HDMI или аналоговый выход, A2DP или гарнитура у Bluetooth-наушников —
    // это профиль устройства (то, ради чего открывали pavucontrol).
    // [{ id, name, profiles: [{ value, label }], current }]
    property var cards: []
    function refreshCards() {
        cardsTimer.restart();
    }
    function setProfile(card, index) {
        Quickshell.execDetached(["wpctl", "set-profile", String(card.id), String(index)]);
        cardsTimer.restart();
    }
    onSinksChanged: refreshCards()
    onSourcesChanged: refreshCards()
    Timer {
        id: cardsTimer
        interval: 400
        onTriggered: cardsProc.running = true
    }
    Process {
        id: cardsProc
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                let objs;
                try {
                    objs = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.cards = objs.filter(o => o.type === "PipeWire:Interface:Device" && o.info?.props?.["media.class"] === "Audio/Device").map(o => {
                    const params = o.info.params ?? {};
                    const current = params.Profile?.[0]?.index;
                    const profiles = (params.EnumProfile ?? []).filter(p => p.available !== "no" || p.index === current).map(p => ({
                                value: p.index,
                                label: p.description || p.name
                            }));
                    return {
                        id: o.id,
                        name: o.info.props["device.description"] || o.info.props["device.nick"] || o.info.props["device.name"],
                        profiles,
                        current
                    };
                }).filter(c => c.profiles.length > 1);
            }
        }
    }
}
