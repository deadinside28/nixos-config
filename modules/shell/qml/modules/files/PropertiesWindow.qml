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
            case "$m" in image/*|video/*|audio/*)
                ffprobe -v error -show_entries format=duration,bit_rate:stream=codec_type,codec_name,width,height,sample_rate,channels,avg_frame_rate -of default=nw=1 -- "$f" 2>/dev/null | sed 's/^/ff_/' ;;
            esac
            true`, "sh", win.path]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                let stream = "";
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i < 0)
                        continue;
                    let k = l.slice(0, i);
                    const v = l.slice(i + 1);
                    // первый видео- и первый аудиопоток
                    if (k === "ff_codec_type") {
                        stream = v;
                        continue;
                    }
                    if (k.startsWith("ff_") && k !== "ff_duration" && k !== "ff_bit_rate")
                        k = "ff_" + stream + "_" + k.slice(3);
                    if (!(k in o))
                        o[k] = v;
                }
                win.info = o;
                win.syncPerms();
            }
        }
    }
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
                // Медиа: размер картинки, длительность, кодеки
                Prop {
                    visible: (win.info.ff_video_width ?? "") !== ""
                    icon: "aspect_ratio"
                    title: win.mime.startsWith("image/") ? "Размер изображения" : "Видео"
                    value: (win.info.ff_video_width ?? "") + " × " + (win.info.ff_video_height ?? "") + (win.mime.startsWith("video/") ? " · " + (win.info.ff_video_codec_name ?? "") : "")
                }
                Prop {
                    visible: win.duration(win.info.ff_duration) !== "" && !win.mime.startsWith("image/")
                    icon: "schedule"
                    title: "Длительность"
                    value: win.duration(win.info.ff_duration)
                }
                Prop {
                    visible: (win.info.ff_audio_codec_name ?? "") !== ""
                    icon: "graphic_eq"
                    title: "Звук"
                    value: (win.info.ff_audio_codec_name ?? "") + (win.info.ff_audio_sample_rate ? " · " + Math.round(Number(win.info.ff_audio_sample_rate) / 100) / 10 + " кГц" : "") + (win.info.ff_audio_channels ? " · " + (win.info.ff_audio_channels === "2" ? "стерео" : win.info.ff_audio_channels === "1" ? "моно" : win.info.ff_audio_channels + " канала") : "")
                }
                Prop {
                    icon: "hard_drive"
                    title: "Свободно на диске"
                    value: win.info.free ? Files.humanSize(Number(win.info.free)) + " из " + Files.humanSize(Number(win.info.disk)) + " (" + win.info.mount + ")" : "—"
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
