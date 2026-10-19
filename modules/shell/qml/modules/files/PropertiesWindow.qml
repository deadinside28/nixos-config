// «Свойства» — отдельное окно, как в Nautilus: основное (тип, размер,
// содержимое папки, даты, медиа), права доступа с правкой и приложение
// по умолчанию для типа. Открывается из «Файлов» (Files.properties()).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

FloatingWindow {
    id: win
    required property var entry // { id, paths }

    readonly property var paths: entry.paths
    readonly property bool multi: paths.length > 1
    readonly property string path: paths[0]
    readonly property string name: multi ? paths.length + " объектов" : (path.split("/").pop() || "/")
    readonly property string parentDir: path.slice(0, path.lastIndexOf("/")) || "/"

    title: "Свойства — " + name
    implicitWidth: 540
    implicitHeight: 680
    minimumSize: Qt.size(440, 520)
    color: Theme.surfaceContainer
    visible: true
    onVisibleChanged: if (!visible)
        Files.closeProperties(entry.id)

    property string tab: "main" // main | perms | open
    property var info: ({}) // ключ → значение из stat, xdg-mime, df, ffprobe
    property var count: null // { size, dirs, files } — по готовности
    readonly property bool isDir: info.ftype === "directory"
    readonly property bool isLink: (info.link ?? "") !== ""
    readonly property string mime: info.mime ?? ""
    readonly property bool mine: info.owner === Quickshell.env("USER")

    function load() {
        statProc.running = true;
        countProc.running = true;
    }
    Component.onCompleted: load()

    function date(sec) {
        const n = Number(sec);
        if (!n || n <= 0)
            return "—";
        return new Date(n * 1000).toLocaleString(Qt.locale("ru_RU"), "d MMMM yyyy, HH:mm");
    }
    function duration(sec) {
        const s = Math.round(Number(sec));
        if (!s)
            return "";
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(r).padStart(2, "0");
    }
    function exact(b) {
        return Number(b).toLocaleString(Qt.locale("ru_RU"), "f", 0) + " байт";
    }

    // stat, тип, свободное место, медиа (ffprobe) — быстро
    Process {
        id: statProc
        command: ["sh", "-c", `
            f=$1
            stat -c 'size=%s
mode=%a
perm=%A
owner=%U
group=%G
atime=%X
mtime=%Y
btime=%W
ftype=%F' -- "$f" 2>/dev/null
            [ -L "$f" ] && echo "link=$(readlink -- "$f")"
            m=$(xdg-mime query filetype "$f" 2>/dev/null); echo "mime=$m"
            df -B1 --output=avail,size,target -- "$f" 2>/dev/null | tail -n 1 | awk '{print "free="$1; print "disk="$2; print "mount="$3}'
            true`, "sh", win.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0 && !(l.slice(0, i) in o))
                        o[l.slice(0, i)] = l.slice(i + 1);
                }
                win.info = o;
                win.syncPerms();
                if (/^(image|video|audio)\//.test(o.mime ?? ""))
                    mediaProc.running = true;
            }
        }
    }

    // --- Медиа: контейнер, потоки и кодеки (ffprobe), снимок с камеры (exiv2) ---
    property var media: null
    Process {
        id: mediaProc
        command: ["sh", "-c", `
            ffprobe -v error -of json -show_format -show_streams -- "$1" 2>/dev/null
            echo "@@EXIF@@"
            # exiv2 не знает «--» (принял бы его за файл); путь всегда абсолютный
            case "$2" in image/*) LC_ALL=C exiv2 -q pr "$1" 2>/dev/null ;; esac
            true`, "sh", win.path, win.mime]
        stdout: StdioCollector {
            onStreamFinished: {
                const [ff, ex] = text.split("@@EXIF@@");
                let j = {};
                try {
                    j = JSON.parse(ff);
                } catch (e) {}
                const exif = [];
                for (const l of (ex ?? "").split("\n")) {
                    const i = l.indexOf(":");
                    if (i < 0)
                        continue;
                    const k = l.slice(0, i).trim(), v = l.slice(i + 1).trim();
                    if (!v || !win.exifLabels[k])
                        continue;
                    // «2026:10:18 02:18:07» → дата по-русски; единицы — по-русски
                    const t = v.match(/^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2})/);
                    const val = t ? new Date(+t[1], t[2] - 1, +t[3], +t[4], +t[5]).toLocaleString(Qt.locale("ru_RU"), "d MMMM yyyy, HH:mm") : v.replace(/ s$/, " с").replace(/ mm\b/g, " мм").replace(/35 mm equivalent/, "в пересчёте на 35 мм");
                    exif.push([win.exifLabels[k], val]);
                }
                const streams = j.streams ?? [];
                win.media = {
                    format: j.format ?? {},
                    video: streams.filter(x => x.codec_type === "video" && x.disposition?.attached_pic !== 1),
                    cover: streams.some(x => x.disposition?.attached_pic === 1),
                    audio: streams.filter(x => x.codec_type === "audio"),
                    subs: streams.filter(x => x.codec_type === "subtitle"),
                    exif
                };
            }
        }
    }
    readonly property var exifLabels: ({
            "Camera make": "Производитель",
            "Camera model": "Камера",
            "Image timestamp": "Снято",
            "Exposure time": "Выдержка",
            "Aperture": "Диафрагма",
            "ISO speed": "ISO",
            "Focal length": "Фокусное расстояние",
            "Exposure bias": "Экспокоррекция",
            "Flash": "Вспышка",
            "Exposure mode": "Режим экспозиции",
            "Metering mode": "Замер",
            "White balance": "Баланс белого",
            "Copyright": "Авторские права"
        })
    readonly property var codecNames: ({
            h264: "H.264 (AVC)",
            hevc: "H.265 (HEVC)",
            av1: "AV1",
            vp9: "VP9",
            vp8: "VP8",
            mpeg4: "MPEG-4 Part 2",
            mpeg2video: "MPEG-2",
            prores: "Apple ProRes",
            theora: "Theora",
            aac: "AAC",
            opus: "Opus",
            mp3: "MP3",
            flac: "FLAC",
            vorbis: "Vorbis",
            ac3: "Dolby Digital (AC-3)",
            eac3: "Dolby Digital Plus (E-AC-3)",
            truehd: "Dolby TrueHD",
            dts: "DTS",
            alac: "Apple Lossless",
            pcm_s16le: "PCM 16 бит",
            pcm_s24le: "PCM 24 бит",
            pcm_f32le: "PCM 32 бит (float)",
            mjpeg: "JPEG",
            png: "PNG",
            webp: "WebP",
            gif: "GIF",
            bmp: "BMP",
            tiff: "TIFF",
            hevc_image: "HEIF",
            jpegxl: "JPEG XL",
            subrip: "SubRip (SRT)",
            ass: "ASS/SSA",
            mov_text: "MP4 Timed Text",
            hdmv_pgs_subtitle: "PGS (Blu-ray)"
        })
    function codec(st) {
        const n = codecNames[st.codec_name] ?? st.codec_long_name ?? st.codec_name ?? "";
        return n + (st.profile && st.profile !== "unknown" && !/^\d+$/.test(st.profile) ? ", профиль " + st.profile : "");
    }
    function bitrate(b) {
        const n = Number(b);
        if (!n)
            return "";
        return n >= 1e6 ? (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + " Мбит/с" : Math.round(n / 1000) + " кбит/с";
    }
    function fps(r) {
        const [a, b] = String(r ?? "").split("/").map(Number);
        if (!a || !b)
            return "";
        const v = a / b;
        return (Math.abs(v - Math.round(v)) < 0.01 ? Math.round(v) : v.toFixed(2)) + " кадр/с";
    }
    function channels(st) {
        const l = st.channel_layout ?? "";
        const named = ({
                mono: "моно",
                stereo: "стерео"
            })[l];
        return named ?? (l ? l.replace(/\(.*\)/, "") : st.channels ? st.channels + " кан." : "");
    }
    function hz(r) {
        return r ? (Number(r) / 1000).toLocaleString(Qt.locale("ru_RU"), "f", Number(r) % 1000 ? 1 : 0) + " кГц" : "";
    }
    function join(parts) {
        return parts.filter(x => x).join(" · ");
    }
    // Кратко для «Основного»
    readonly property string videoLine: media && media.video.length ? join([media.video[0].width + " × " + media.video[0].height, codecNames[media.video[0].codec_name] ?? media.video[0].codec_name, fps(media.video[0].avg_frame_rate)]) : ""
    readonly property string audioLine: media && media.audio.length ? join([codecNames[media.audio[0].codec_name] ?? media.audio[0].codec_name, channels(media.audio[0]), hz(media.audio[0].sample_rate)]) : ""
    // Размер и число вложенных объектов — для папок и нескольких файлов долго
    Process {
        id: countProc
        command: ["sh", "-c", `
            s=$(du -scb -- "$@" 2>/dev/null | tail -n 1 | cut -f1)
            d=$(find "$@" -mindepth 1 -type d 2>/dev/null | wc -l)
            f=$(find "$@" -mindepth 1 ! -type d 2>/dev/null | wc -l)
            echo "$s $d $f"`, "sh", ...win.paths]
        stdout: StdioCollector {
            onStreamFinished: {
                const [size, dirs, files] = text.trim().split(" ").map(Number);
                win.count = {
                    size,
                    dirs,
                    files
                };
            }
        }
    }

    // --- Права: owner/group/other → 0 нет, 4 чтение, 6 чтение и запись ----------
    property var perm: [0, 0, 0]
    property bool execBit: false
    function syncPerms() {
        const m = parseInt(info.mode ?? "0", 8);
        perm = [6, 3, 0].map(sh => (m >> sh) & 6);
        execBit = !isDir && (m & 0o111) !== 0;
    }
    function applyPerms() {
        // у папки «чтение» без x бессмысленно: войти в неё нельзя
        const bits = perm.map(p => isDir ? (p ? p | 1 : 0) : (execBit && p ? p | 1 : p));
        const mode = bits.map(String).join("");
        Quickshell.execDetached(["chmod", mode, "--", ...paths]);
        reloadTimer.restart();
    }
    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: statProc.running = true
    }
    readonly property var accessOptions: [
        {
            value: 0,
            label: "Нет доступа"
        },
        {
            value: 4,
            label: isDir ? "Просмотр содержимого" : "Только чтение"
        },
        {
            value: 6,
            label: isDir ? "Создание и удаление файлов" : "Чтение и запись"
        }
    ]

    // --- Открывать в ------------------------------------------------------------
    property var apps: []
    property string defApp: ""
    property bool appsLoaded: false
    onTabChanged: if (tab === "open" && !appsLoaded)
        Files.appsFor(path, (list, def) => {
            win.apps = list;
            win.defApp = def.replace(/\.desktop$/, "");
            win.appsLoaded = true;
        })

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            // Заголовок: значок или превью, имя, тип
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 112
                    implicitHeight: 112
                    Image {
                        id: preview
                        anchors.fill: parent
                        visible: !win.multi && win.mime.startsWith("image/") && status === Image.Ready
                        source: visible || win.mime.startsWith("image/") ? "file://" + win.path : ""
                        sourceSize: Qt.size(224, 224)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    AppIcon {
                        anchors.fill: parent
                        visible: !preview.visible
                        styled: false
                        icon: win.multi ? "edit-copy" : Files.iconFor(win.name, win.path, win.isDir)
                    }
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: win.name
                    size: Theme.type.titleL
                    wrapMode: Text.WrapAnywhere
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fgSurfaceVariant
                    text: win.multi ? "Несколько объектов" : (win.isDir ? "Папка" : Files.kindLabel(Files.kindOf(win.name, false))) + (win.mime ? " · " + win.mime : "")
                }
            }

            SegmentedButtons {
                Layout.fillWidth: true
                options: [
                    {
                        value: "main",
                        label: "Основное"
                    },
                    {
                        value: "perms",
                        label: "Права"
                    },
                    ...(win.media && (win.media.video.length || win.media.audio.length || win.media.exif.length) ? [
                            {
                                value: "media",
                                label: "Медиа"
                            }
                        ] : []),
                    ...(win.multi || win.isDir ? [] : [
                            {
                                value: "open",
                                label: "Открывать в"
                            }
                        ])
                ]
                current: win.tab
                onSelected: v => win.tab = v
            }

            // --- Основное ---
            Group {
                visible: win.tab === "main"
                Prop {
                    icon: "straighten"
                    title: "Размер"
                    value: win.count ? Files.humanSize(win.count.size) + (win.count.size >= 1024 ? " (" + win.exact(win.count.size) + ")" : "") : win.info.size && !win.isDir && !win.multi ? Files.humanSize(Number(win.info.size)) : "Считаю…"
                }
                Prop {
                    visible: win.isDir || win.multi
                    icon: "folder_open"
                    title: "Содержимое"
                    value: win.count ? (win.count.dirs + win.count.files) + " объектов: папок " + win.count.dirs + ", файлов " + win.count.files : "Считаю…"
                }
                Prop {
                    icon: "location_on"
                    title: "Расположение"
                    value: win.parentDir.replace(Settings.home, "~")
                    clickable: true
                    chevron: true
                    onClicked: Files.open(win.parentDir)
                }
                Prop {
                    visible: win.isLink
                    icon: "link"
                    title: "Ссылка на"
                    value: win.info.link ?? ""
                }
                Prop {
                    visible: !win.multi
                    icon: "edit_calendar"
                    title: "Изменён"
                    value: win.date(win.info.mtime)
                }
                Prop {
                    visible: !win.multi
                    icon: "visibility"
                    title: "Открыт"
                    value: win.date(win.info.atime)
                }
                Prop {
                    visible: !win.multi && Number(win.info.btime) > 0
                    icon: "add_circle"
                    title: "Создан"
                    value: win.date(win.info.btime)
                }
                // Медиа кратко; подробно — вкладка «Медиа»
                Prop {
                    visible: win.videoLine !== ""
                    icon: win.mime.startsWith("image/") ? "aspect_ratio" : "movie"
                    title: win.mime.startsWith("image/") ? "Изображение" : "Видео"
                    value: win.videoLine
                }
                Prop {
                    visible: win.duration(win.media?.format?.duration) !== "" && !win.mime.startsWith("image/")
                    icon: "schedule"
                    title: "Длительность"
                    value: win.duration(win.media?.format?.duration)
                }
                Prop {
                    visible: win.audioLine !== ""
                    icon: "graphic_eq"
                    title: "Звук"
                    value: win.audioLine
                }
                Prop {
                    icon: "hard_drive"
                    title: "Свободно на диске"
                    value: win.info.free ? Files.humanSize(Number(win.info.free)) + " из " + Files.humanSize(Number(win.info.disk)) + " (" + win.info.mount + ")" : "—"
                }
            }

            // --- Медиа ---
            Group {
                visible: win.tab === "media" && win.media !== null && !win.mime.startsWith("image/")
                title: "Файл"
                Prop {
                    icon: "inventory_2"
                    title: "Контейнер"
                    value: win.media?.format?.format_long_name ?? ""
                }
                Prop {
                    visible: value !== ""
                    icon: "schedule"
                    title: "Длительность"
                    value: win.duration(win.media?.format?.duration)
                }
                Prop {
                    visible: value !== ""
                    icon: "speed"
                    title: "Общий битрейт"
                    value: win.bitrate(win.media?.format?.bit_rate)
                }
                Repeater {
                    // название, исполнитель, альбом, год, кодировщик…
                    model: {
                        const t = win.media?.format?.tags ?? {};
                        const names = {
                            title: "Название",
                            artist: "Исполнитель",
                            album_artist: "Исполнитель альбома",
                            album: "Альбом",
                            date: "Год",
                            genre: "Жанр",
                            track: "Дорожка",
                            comment: "Комментарий",
                            encoder: "Кодировщик",
                            creation_time: "Создано"
                        };
                        return Object.keys(t).filter(k => names[k.toLowerCase()]).map(k => [names[k.toLowerCase()], t[k]]);
                    }
                    Prop {
                        required property var modelData
                        icon: "label"
                        title: modelData[0]
                        value: modelData[1]
                    }
                }
            }
            Repeater {
                model: win.tab === "media" ? win.media?.video ?? [] : []
                Group {
                    id: vg
                    required property var modelData
                    required property int index
                    readonly property var st: modelData
                    title: win.mime.startsWith("image/") ? "Изображение" : "Видео" + ((win.media?.video.length ?? 0) > 1 ? " " + (index + 1) : "")
                    Prop {
                        icon: "aspect_ratio"
                        title: "Разрешение"
                        value: vg.st.width + " × " + vg.st.height + (vg.st.display_aspect_ratio && vg.st.display_aspect_ratio !== "0:1" ? " (" + vg.st.display_aspect_ratio + ")" : "")
                    }
                    Prop {
                        icon: "movie"
                        title: "Кодек"
                        value: win.codec(vg.st)
                    }
                    Prop {
                        visible: value !== "" && !win.mime.startsWith("image/")
                        icon: "slow_motion_video"
                        title: "Частота кадров"
                        value: win.fps(vg.st.avg_frame_rate)
                    }
                    Prop {
                        visible: value !== ""
                        icon: "speed"
                        title: "Битрейт"
                        value: win.bitrate(vg.st.bit_rate)
                    }
                    Prop {
                        visible: value !== ""
                        icon: "palette"
                        title: "Цвет"
                        value: win.join([vg.st.pix_fmt, vg.st.color_space, vg.st.color_transfer === "smpte2084" ? "HDR10 (PQ)" : vg.st.color_transfer === "arib-std-b67" ? "HLG" : "", vg.st.bits_per_raw_sample ? vg.st.bits_per_raw_sample + " бит" : ""])
                    }
                }
            }
            Repeater {
                model: win.tab === "media" ? win.media?.audio ?? [] : []
                Group {
                    id: ag
                    required property var modelData
                    required property int index
                    readonly property var st: modelData
                    title: "Звук" + ((win.media?.audio.length ?? 0) > 1 ? " " + (index + 1) + (st.tags?.language ? " · " + st.tags.language : "") : "")
                    Prop {
                        icon: "graphic_eq"
                        title: "Кодек"
                        value: win.codec(ag.st)
                    }
                    Prop {
                        icon: "surround_sound"
                        title: "Каналы"
                        value: win.channels(ag.st)
                    }
                    Prop {
                        visible: value !== ""
                        icon: "waves"
                        title: "Частота дискретизации"
                        value: win.hz(ag.st.sample_rate)
                    }
                    Prop {
                        visible: value !== ""
                        icon: "speed"
                        title: "Битрейт"
                        value: win.bitrate(ag.st.bit_rate)
                    }
                }
            }
            Group {
                visible: win.tab === "media" && (win.media?.subs.length ?? 0) > 0
                title: "Субтитры"
                Repeater {
                    model: win.media?.subs ?? []
                    Prop {
                        required property var modelData
                        icon: "subtitles"
                        title: modelData.tags?.title || modelData.tags?.language || "Дорожка"
                        value: win.codec(modelData)
                    }
                }
            }
            Group {
                visible: win.tab === "media" && (win.media?.exif.length ?? 0) > 0
                title: "Снимок"
                Repeater {
                    model: win.media?.exif ?? []
                    Prop {
                        required property var modelData
                        icon: ({
                                "Производитель": "factory",
                                "Камера": "photo_camera",
                                "Снято": "event",
                                "Выдержка": "shutter_speed",
                                "Диафрагма": "camera",
                                "ISO": "iso",
                                "Фокусное расстояние": "center_focus_strong",
                                "Вспышка": "flash_on"
                            })[modelData[0]] ?? "info"
                        title: modelData[0]
                        value: modelData[1]
                    }
                }
            }

            // --- Права ---
            Group {
                visible: win.tab === "perms"
                Prop {
                    icon: "person"
                    title: "Владелец"
                    value: (win.info.owner ?? "") + (win.mine ? " (вы)" : "")
                }
                Prop {
                    icon: "group"
                    title: "Группа"
                    value: win.info.group ?? ""
                }
                Prop {
                    icon: "key"
                    title: "Права"
                    value: (win.info.perm ?? "") + "  " + (win.info.mode ?? "")
                }
            }
            MText {
                visible: win.tab === "perms" && !win.mine
                Layout.fillWidth: true
                Layout.leftMargin: 20
                wrapMode: Text.WordWrap
                color: Theme.fgSurfaceVariant
                text: "Права может менять только владелец."
            }
            Group {
                visible: win.tab === "perms" && win.mine
                title: "Доступ"
                Repeater {
                    model: [["Владелец", "person"], ["Группа", "group"], ["Остальные", "public"]]
                    ChoiceItem {
                        required property var modelData
                        required property int index
                        icon: modelData[1]
                        title: modelData[0]
                        options: win.accessOptions
                        current: win.perm[index]
                        onSelected: v => {
                            const p = win.perm.slice();
                            p[index] = v;
                            win.perm = p;
                            win.applyPerms();
                        }
                    }
                }
                SwitchItem {
                    visible: !win.isDir
                    icon: "terminal"
                    title: "Выполнять как программу"
                    checked: win.execBit
                    onToggled: v => {
                        win.execBit = v;
                        win.applyPerms();
                    }
                }
            }

            // --- Открывать в ---
            MText {
                visible: win.tab === "open"
                Layout.fillWidth: true
                Layout.leftMargin: 20
                wrapMode: Text.WordWrap
                color: Theme.fgSurfaceVariant
                text: "Приложение по умолчанию для всех файлов типа «" + win.mime + "»"
            }
            Group {
                visible: win.tab === "open"
                Repeater {
                    model: win.apps
                    AppListItem {
                        required property var modelData
                        appIcon: modelData.icon || "application-x-executable"
                        title: modelData.name
                        subtitle: modelData.id === win.defApp ? "По умолчанию" : ""
                        selected: modelData.id === win.defApp
                        onClicked: {
                            Files.setDefaultApp(win.path, modelData.id);
                            win.defApp = modelData.id;
                        }
                    }
                }
                ListItem {
                    visible: win.appsLoaded && win.apps.length === 0
                    icon: "block"
                    title: "Нет приложений для этого типа"
                    clickable: false
                }
            }
        }
    }

    component Prop: ListItem {
        property string value
        subtitle: value
        clickable: false
    }
}
