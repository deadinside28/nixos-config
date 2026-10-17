pragma Singleton

// «Файлы» — свой проводник в духе Aluminium OS. Здесь общее для всех
// окон: список открытых окон, буфер копирования, места в боковой панели,
// значки по типам и операции над файлами (cp/mv/gio).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property string home: Settings.home

    // Открытые окна: [{ id, path }]
    property var windows: []
    property int nextId: 1
    function open(path) {
        let p = String(path || home);
        if (p.startsWith("file://"))
            p = decodeURIComponent(p.slice(7));
        if (p.startsWith("~"))
            p = home + p.slice(1);
        if (p.length > 1 && p.endsWith("/"))
            p = p.slice(0, -1);
        windows = [...windows, {
                id: nextId,
                path: p
            }];
        nextId++;
    }
    function closeWindow(id) {
        windows = windows.filter(w => w.id !== id);
    }

    // Буфер копирования между окнами: { mode: "copy" | "cut", paths: [] }
    property var clipboard: ({
            mode: "",
            paths: []
        })
    function setClipboard(mode, paths) {
        clipboard = {
            mode,
            paths
        };
        // и в системный буфер — чтобы вставлялось в другие приложения
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$@" | sed "s|^|file://|" | wl-copy --type text/uri-list', "sh", ...paths]);
    }

    // --- Места ---------------------------------------------------------------
    readonly property var places: [
        {
            path: home,
            name: "Мои файлы",
            icon: "home"
        },
        {
            path: home + "/Desktop",
            name: "Рабочий стол",
            icon: "desktop_windows"
        },
        {
            path: home + "/Documents",
            name: "Документы",
            icon: "description"
        },
        {
            path: home + "/Downloads",
            name: "Загрузки",
            icon: "download"
        },
        {
            path: home + "/Pictures",
            name: "Изображения",
            icon: "image"
        },
        {
            path: home + "/Music",
            name: "Музыка",
            icon: "music_note"
        },
        {
            path: home + "/Videos",
            name: "Видео",
            icon: "movie"
        }
    ]
    // Закладки GTK (их же видят диалоги выбора файлов)
    property var bookmarks: []
    FileView {
        path: Settings.configDir + "/gtk-3.0/bookmarks"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.bookmarks = text().split("\n").filter(l => l.startsWith("file://")).map(l => {
            const sp = l.indexOf(" ");
            const path = decodeURIComponent((sp > 0 ? l.slice(0, sp) : l).slice(7));
            return {
                path,
                name: sp > 0 ? l.slice(sp + 1) : path.split("/").pop(),
                icon: "bookmark"
            };
        })
    }
    function addBookmark(path) {
        if (bookmarks.some(b => b.path === path))
            return;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")"; printf "file://%s\\n" "$2" >> "$1"', "sh", Settings.configDir + "/gtk-3.0/bookmarks", encodeURI(path)]);
    }
    function removeBookmark(path) {
        Quickshell.execDetached(["sh", "-c", 'grep -v -x -F "file://$2" "$1" > "$1.tmp"; grep -v "^file://$2 " "$1.tmp" > "$1"; rm -f "$1.tmp"', "sh", Settings.configDir + "/gtk-3.0/bookmarks", encodeURI(path)]);
    }

    // Подключённые диски (кроме системных разделов)
    property var drives: []
    function refreshDrives() {
        drivesProc.running = true;
    }
    Process {
        id: drivesProc
        command: ["sh", "-c", "lsblk -rno MOUNTPOINT,LABEL,SIZE,RM,TRAN 2>/dev/null | awk '$1 ~ /^\\// && $1 !~ /^\\/(boot|nix|efi)/ && $1 != \"/\" && $1 !~ /^\\[SWAP\\]/'"]
        stdout: StdioCollector {
            onStreamFinished: root.drives = text.split("\n").filter(l => l).map(l => {
                const [mp, label, size, rm, tran] = l.split(" ");
                const lbl = (label || "").replace(/\\x20/g, " ");
                return {
                    path: mp.replace(/\\x20/g, " "),
                    name: lbl || mp.split("/").pop() || mp,
                    size,
                    icon: rm === "1" || tran === "usb" ? "usb" : "hard_drive"
                };
            })
        }
    }
    Timer {
        // флешки появляются и пропадают — опрашиваем, пока открыто окно
        running: root.windows.length > 0
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDrives()
    }

    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/Trash/files"

    // --- Типы и значки -------------------------------------------------------
    readonly property var kinds: ({
            image: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif", "heic", "tiff", "ico", "jxl"],
            video: ["mp4", "mkv", "webm", "mov", "avi", "m4v", "wmv", "flv", "ts"],
            audio: ["mp3", "flac", "ogg", "opus", "wav", "m4a", "aac", "wma"],
            document: ["pdf", "doc", "docx", "odt", "rtf", "txt", "md", "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp", "epub", "djvu"],
            archive: ["zip", "rar", "7z", "tar", "gz", "xz", "zst", "bz2", "tgz", "iso"],
            code: ["nix", "qml", "js", "ts", "py", "rs", "c", "cpp", "h", "go", "java", "lua", "sh", "json", "toml", "yaml", "yml", "html", "css", "xml", "kt"],
            app: ["appimage", "exe", "msi", "deb", "rpm", "flatpakref", "desktop"]
        })
    function kindOf(name, isDir) {
        if (isDir)
            return "folder";
        const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";
        for (const k in kinds)
            if (kinds[k].includes(ext))
                return k;
        return "file";
    }
    function kindLabel(k) {
        return ({
                folder: "Папка",
                image: "Изображение",
                video: "Видео",
                audio: "Аудио",
                document: "Документ",
                archive: "Архив",
                code: "Код",
                app: "Программа",
                file: "Файл"
            })[k] ?? "Файл";
    }
    // Значок темы по типу файла
    function iconFor(name, path, isDir) {
        if (isDir) {
            const special = {
                [home + "/Desktop"]: "user-desktop",
                [home + "/Documents"]: "folder-documents",
                [home + "/Downloads"]: "folder-download",
                [home + "/Pictures"]: "folder-pictures",
                [home + "/Music"]: "folder-music",
                [home + "/Videos"]: "folder-videos",
                [home + "/Public"]: "folder-publicshare",
                [home + "/Templates"]: "folder-templates",
                [home]: "user-home"
            };
            return special[path] ?? "folder";
        }
        const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : "";
        const byExt = {
            pdf: "application-pdf",
            zip: "application-zip",
            appimage: "application-x-executable",
            exe: "application-x-ms-dos-executable",
            iso: "application-x-cd-image",
            sh: "application-x-shellscript",
            html: "text-html",
            json: "application-json",
            md: "text-markdown",
            torrent: "application-x-bittorrent",
            doc: "x-office-document",
            docx: "x-office-document",
            odt: "x-office-document",
            xls: "x-office-spreadsheet",
            xlsx: "x-office-spreadsheet",
            ods: "x-office-spreadsheet",
            ppt: "x-office-presentation",
            pptx: "x-office-presentation",
            odp: "x-office-presentation"
        };
        if (byExt[ext])
            return byExt[ext];
        return ({
                image: "image-x-generic",
                video: "video-x-generic",
                audio: "audio-x-generic",
                document: "text-x-generic",
                archive: "package-x-generic",
                code: "text-x-script",
                app: "application-x-executable",
                file: "text-x-generic"
            })[kindOf(name, false)];
    }

    function humanSize(b) {
        if (b < 1024)
            return b + " Б";
        const u = ["КБ", "МБ", "ГБ", "ТБ"];
        let i = -1;
        do {
            b /= 1024;
            i++;
        } while (b >= 1024 && i < u.length - 1)
        return (b < 10 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }
    function humanDate(d) {
        if (!d)
            return "";
        const now = new Date();
        const t = new Date(d);
        const day = 86400000;
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const hm = t.toLocaleTimeString(Qt.locale("ru_RU"), "HH:mm");
        if (t.getTime() >= start)
            return "Сегодня, " + hm;
        if (t.getTime() >= start - day)
            return "Вчера, " + hm;
        return t.toLocaleDateString(Qt.locale("ru_RU"), t.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
    }

    // --- Операции ------------------------------------------------------------
    // Идущие операции (для полоски прогресса в окнах)
    property int busy: 0
    signal changed(string dir)

    function run(cmd, dir) {
        const p = opProc.createObject(root, {
            cmd,
            dir: dir ?? ""
        });
        busy++;
        p.running = true;
    }
    property string lastError: ""
    property Component opProc: Component {
        Process {
            id: op
            property var cmd: []
            property string dir
            command: cmd
            stderr: StdioCollector {
                id: err
            }
            onExited: code => {
                root.busy--;
                root.lastError = code === 0 ? "" : err.text.trim().split("\n").pop();
                root.changed(op.dir);
                op.destroy();
            }
        }
    }

    function openFile(path) {
        Quickshell.execDetached(["gio", "open", path]);
    }
    function openWith(desktopId, path) {
        Quickshell.execDetached(["gtk-launch", desktopId, path]);
    }
    function openTerminal(dir) {
        Quickshell.execDetached([Nix.terminal, "--directory", dir]);
    }
    function trash(paths) {
        run(["gio", "trash", "--", ...paths]);
    }
    function deleteForever(paths) {
        run(["rm", "-rf", "--", ...paths]);
    }
    function restore(paths) {
        // gio восстанавливает по trash:///имя
        run(["gio", "trash", "--restore", ...paths.map(p => "trash:///" + encodeURIComponent(p.split("/").pop()))]);
    }
    function emptyTrash() {
        run(["gio", "trash", "--empty"]);
    }
    function mkdir(dir, name) {
        run(["mkdir", "-p", "--", dir + "/" + name], dir);
    }
    function rename(path, name) {
        const dir = path.slice(0, path.lastIndexOf("/"));
        run(["mv", "-n", "--", path, dir + "/" + name], dir);
    }
    // Вставка: при совпадении имён — «имя (2).ext»
    function paste(dir) {
        if (!clipboard.paths.length)
            return;
        const mode = clipboard.mode;
        run(["sh", "-c", `
            mode="$1"; dest="$2"; shift 2
            for src in "$@"; do
                base=$(basename -- "$src")
                target="$dest/$base"
                if [ "$mode" = cut ] && [ "$(dirname -- "$src")" = "$dest" ]; then continue; fi
                n=2
                while [ -e "$target" ]; do
                    case "$base" in
                        ?*.*) target="$dest/\${base%.*} ($n).\${base##*.}" ;;
                        *) target="$dest/$base ($n)" ;;
                    esac
                    n=$((n + 1))
                done
                if [ "$mode" = cut ]; then mv -- "$src" "$target"; else cp -a -- "$src" "$target"; fi
            done
        `, "sh", mode, dir, ...clipboard.paths], dir);
        if (mode === "cut")
            clipboard = {
                mode: "",
                paths: []
            };
    }
    function extract(path) {
        const dir = path.slice(0, path.lastIndexOf("/"));
        run(["sh", "-c", 'cd "$(dirname -- "$1")" && (command -v file-roller >/dev/null && file-roller --extract-here "$1" || (case "$1" in *.zip) unzip -o "$1";; *) tar xf "$1";; esac))', "sh", path], dir);
    }
    function compress(paths, dir) {
        const name = paths.length === 1 ? paths[0].split("/").pop() : "Архив";
        run(["sh", "-c", 'dir="$1"; name="$2"; shift 2; cd "$dir" && n=""; i=2; while [ -e "$dir/$name$n.zip" ]; do n=" ($i)"; i=$((i+1)); done; zip -qr "$name$n.zip" "$@" 2>/dev/null || tar czf "$name$n.tar.gz" "$@"', "sh", dir, name, ...paths.map(p => p.split("/").pop())], dir);
    }

    // Приложения, которые умеют открывать этот файл (для «Открыть с помощью»)
    function appsFor(path, cb) {
        const p = appsProc.createObject(root, {
            path
        });
        p.done.connect(cb);
        p.running = true;
    }
    property Component appsProc: Component {
        Process {
            id: ap
            property string path
            signal done(var apps, string current)
            command: ["sh", "-c", 'm=$(xdg-mime query filetype "$1" 2>/dev/null); echo "#$m"; gio mime "$m" 2>/dev/null', "sh", path]
            stdout: StdioCollector {
                onStreamFinished: {
                    let def = "";
                    const ids = [];
                    let section = "";
                    for (const l of text.split("\n")) {
                        if (l.startsWith("Default application"))
                            def = (l.split(":")[1] ?? "").trim();
                        else if (l.startsWith("Registered applications") || l.startsWith("Recommended applications"))
                            section = "apps";
                        else if (section === "apps" && l.startsWith("\t")) {
                            const id = l.trim();
                            if (!ids.includes(id))
                                ids.push(id);
                        }
                    }
                    const apps = ids.map(id => DesktopEntries.byId(id.replace(/\.desktop$/, ""))).filter(e => e && !e.noDisplay);
                    ap.done(apps, def.replace(/\.desktop$/, ""));
                    ap.destroy();
                }
            }
        }
    }
    function setDefaultApp(path, desktopId) {
        Quickshell.execDetached(["sh", "-c", 'xdg-mime default "$2.desktop" "$(xdg-mime query filetype "$1")"', "sh", path, desktopId]);
    }
}
