pragma Singleton

// Звук через PipeWire: устройство по умолчанию, громкость, приложения.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !(n.name ?? "").includes(".monitor"))
    readonly property var playbackStreams: Pipewire.nodes.values.filter(n => n.isStream && n.audio && (n.properties["media.class"] ?? "") === "Stream/Output/Audio")

    readonly property string icon: muted || volume <= 0 ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"

    // Без трекера PipeWire не отдаёт громкость и mute узлов.
    PwObjectTracker {
        objects: [root.sink, root.source, ...root.sinks, ...root.sources, ...root.playbackStreams]
    }

    function setVolume(v) {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function setMicVolume(v) {
        if (source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function nodeName(n) {
        return n?.nickname || n?.description || n?.name || "";
    }
    function streamName(n) {
        const p = n?.properties ?? {};
        return p["application.name"] || p["media.name"] || nodeName(n);
    }
    function streamIcon(n) {
        const p = n?.properties ?? {};
        return p["application.icon-name"] || (p["application.process.binary"] ?? "").toLowerCase() || "audio-x-generic";
    }
}
