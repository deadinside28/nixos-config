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
        // архив — в отдельном окне архиватора
        if (isArchive(p.split("/").pop())) {
            openArchiveWindow(p);
            return;
        }
        windows = [...windows, {
                id: nextId,
                path: p,
                archive: ""
            }];
        nextId++;
    }
    // Окна архиватора: [{ id, path }]
    property var archiveWindows: []
    function openArchiveWindow(path) {
        let p = String(path);
        if (p.startsWith("file://"))
            p = decodeURIComponent(p.slice(7));
        archiveWindows = [...archiveWindows, {
                id: nextId,
                path: p
            }];
        nextId++;
    }
    function closeArchiveWindow(id) {
        archiveWindows = archiveWindows.filter(w => w.id !== id);
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
    // Вставка. Источник — системный буфер: файлы (text/uri-list — из «Файлов»,
    // Nemo, браузера…) копируются, картинка (скриншот) сохраняется файлом.
    // Вырезанное в «Файлах» — перемещается. Совпали имена — «имя (2).ext».
    function paste(dir) {
        const cut = clipboard.mode === "cut" && clipboard.paths.length > 0;
        run(["sh", "-c", `
            dest="$1"; mode="$2"; shift 2
            unique() {
                base=$(basename -- "$1"); target="$dest/$base"; n=2
                while [ -e "$target" ]; do
                    case "$base" in
                        ?*.*) target="$dest/\${base%.*} ($n).\${base##*.}" ;;
                        *) target="$dest/$base ($n)" ;;
                    esac
                    n=$((n + 1))
                done
                printf '%s' "$target"
            }
            if [ "$mode" != cut ]; then
                types=$(wl-paste --list-types 2>/dev/null || true)
                if printf '%s\\n' "$types" | grep -qx 'text/uri-list'; then
                    list=$(mktemp)
                    wl-paste --type text/uri-list 2>/dev/null | tr -d '\\r' | sed -n 's|^file://||p' > "$list"
                    set --
                    while IFS= read -r u; do
                        set -- "$@" "$(printf '%b' "$(printf '%s' "$u" | sed 's/%/\\\\x/g')")"
                    done < "$list"
                    rm -f "$list"
                else
                    img=$(printf '%s\\n' "$types" | grep -m1 '^image/' || true)
                    [ -n "$img" ] || exit 0
                    ext=\${img#image/}; [ "$ext" = jpeg ] && ext=jpg
                    f=$(unique "$dest/Снимок экрана $(date '+%Y-%m-%d %H-%M-%S').$ext")
                    wl-paste --type "$img" > "$f"
                    exit 0
                fi
            fi
            for src in "$@"; do
                [ -e "$src" ] || continue
                if [ "$mode" = cut ] && [ "$(dirname -- "$src")" = "$dest" ]; then continue; fi
                target=$(unique "$src")
                if [ "$mode" = cut ]; then mv -- "$src" "$target"; else cp -a -- "$src" "$target"; fi
            done
        `, "sh", dir, cut ? "cut" : "copy", ...(cut ? clipboard.paths : [])], dir);
        if (cut)
            clipboard = {
                mode: "",
                paths: []
            };
    }
    // Копирование или перемещение конкретных путей (перетаскивание)
    function transfer(paths, dir, move) {
        run(["sh", "-c", `
            dest="$1"; mode="$2"; shift 2
            for src in "$@"; do
                [ -e "$src" ] || continue
                if [ "$mode" = move ] && [ "$(dirname -- "$src")" = "$dest" ]; then continue; fi
                b=$(basename -- "$src"); t="$dest/$b"; n=2
                while [ -e "$t" ]; do
                    case "$b" in ?*.*) t="$dest/\${b%.*} ($n).\${b##*.}" ;; *) t="$dest/$b ($n)" ;; esac
                    n=$((n + 1))
                done
                if [ "$mode" = move ]; then mv -- "$src" "$t"; else cp -a -- "$src" "$t"; fi
            done
        `, "sh", dir, move ? "move" : "copy", ...paths], dir);
    }

    // --- Архивы: внутрь как в папку, распаковка, сжатие (bsdtar) ---------------
    readonly property string archiveCache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/pixel-shell/archives"
    function isArchive(name) {
        return /\.(zip|7z|rar|tar|tgz|tbz2|txz|tzst|tar\.(gz|bz2|xz|zst|lz4)|gz|xz|bz2|zst|iso|cab|jar|deb|rpm)$/i.test(name);
    }
    function archiveBase(name) {
        return name.replace(/\.(tar\.(gz|bz2|xz|zst|lz4)|[^.]+)$/i, "");
    }
    // Содержимое архива распаковывается в кеш, и окно ходит по нему как по
    // обычной папке: открывать, копировать и перетаскивать файлы куда угодно.
    function openArchive(path, cb) {
        const dir = archiveCache + "/" + Qt.md5(path);
        const p = archProc.createObject(root, {
            path,
            dir
        });
        p.done.connect(cb);
        busy++;
        p.running = true;
    }
    property Component archProc: Component {
        Process {
            id: arp
            property string path
            property string dir
            signal done(bool ok, string dir)
            command: ["sh", "-c", `
                find "$3" -mindepth 1 -maxdepth 1 -mtime +1 -exec rm -rf {} + 2>/dev/null
                if [ ! -e "$2/.pixel-done" ] || [ "$1" -nt "$2/.pixel-done" ]; then
                    rm -rf "$2"; mkdir -p "$2"
                    bsdtar -xf "$1" -C "$2" && touch "$2/.pixel-done"
                fi
            `, "sh", path, dir, root.archiveCache]
            stderr: StdioCollector {
                id: arErr
            }
            onExited: code => {
                root.busy--;
                root.lastError = code === 0 ? "" : "Не удалось открыть архив: " + arErr.text.trim().split("\n").pop();
                arp.done(code === 0, arp.dir);
                arp.destroy();
            }
        }
    }
    // Добавить файлы в архив: кладём их в распакованную копию и собираем
    // архив заново в том же формате (bsdtar выбирает его по расширению)
    function addToArchive(archive, rootDir, dir, paths) {
        const suffix = archive.split("/").pop().slice(archiveBase(archive.split("/").pop()).length);
        run(["sh", "-c", `
            archive="$1"; root="$2"; dir="$3"; suffix="$4"; shift 4
            cp -a -- "$@" "$dir"/ || exit 1
            tmp="$(dirname -- "$archive")/.pixel-repack-$$$suffix"
            (cd "$root" && find . -mindepth 1 -maxdepth 1 ! -name .pixel-done -printf '%P\\0' | xargs -0 bsdtar -a -cf "$tmp") || { rm -f "$tmp"; exit 1; }
            mv -f -- "$tmp" "$archive"
            touch "$root/.pixel-done"
        `, "sh", archive, rootDir, dir, suffix, ...paths], dir);
    }

    // Распаковать рядом: в папку с именем архива (если внутри один каталог —
    // просто его), как на ChromeOS
    function extract(path, destDir) {
        const dir = destDir || path.slice(0, path.lastIndexOf("/"));
        run(["sh", "-c", `
            src="$1"; dest="$2"; name="$3"
            tmp=$(mktemp -d "$dest/.pixel-extract.XXXXXX") || exit 1
            if ! bsdtar -xf "$src" -C "$tmp"; then rm -rf "$tmp"; exit 1; fi
            items=0; one=""
            for f in "$tmp"/* "$tmp"/.[!.]*; do [ -e "$f" ] && { items=$((items + 1)); one="$f"; }; done
            if [ "$items" -eq 1 ] && [ -d "$one" ]; then from="$one"; name=$(basename -- "$one"); else from="$tmp"; fi
            target="$dest/$name"; n=2
            while [ -e "$target" ]; do target="$dest/$name ($n)"; n=$((n + 1)); done
            mv -- "$from" "$target"
            rm -rf "$tmp"
        `, "sh", path, dir, archiveBase(path.split("/").pop())], dir);
    }
    function compress(paths, dir) {
        const name = paths.length === 1 ? archiveBase(paths[0].split("/").pop()) || paths[0].split("/").pop() : "Архив";
        run(["sh", "-c", 'dir="$1"; name="$2"; shift 2; cd "$dir" || exit 1; t="$name.zip"; i=2; while [ -e "$t" ]; do t="$name ($i).zip"; i=$((i+1)); done; bsdtar -a -cf "$t" -- "$@"', "sh", dir, name, ...paths.map(p => p.split("/").pop())], dir);
    }

    // --- Программы и скрипты ---------------------------------------------------
    function isScript(name) {
        return /\.(sh|bash|run|py|pl|rb)$/i.test(name);
    }
    function isAppImage(name) {
        return /\.appimage$/i.test(name);
    }
    // Запуск: AppImage — через appimage-run (если есть), скрипт — в терминале.
    // Права на выполнение выставляются сами, chmod руками не нужен.
    function launch(path) {
        Quickshell.execDetached(["sh", "-c", `
            f="$1"; term="$2"
            chmod +x -- "$f"
            cd "$(dirname -- "$f")" || exit 1
            case "$f" in
                *.[Aa]pp[Ii]mage|*.APPIMAGE)
                    if command -v appimage-run >/dev/null; then exec appimage-run "$f"; else exec "$f"; fi ;;
                *.sh|*.bash|*.run|*.py|*.pl|*.rb)
                    exec "$term" --hold -- "$f" ;;
                *) exec "$f" ;;
            esac
        `, "sh", path, Nix.terminal]);
    }
    function setExecutable(path, on) {
        run(["chmod", on ? "+x" : "-x", "--", path], path.slice(0, path.lastIndexOf("/")));
    }
    // Узнать, исполняемый ли файл и есть ли он уже в меню приложений
    readonly property string appsDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/applications"
    function desktopIdFor(path) {
        return "pixel-files-" + Qt.md5(path).slice(0, 10);
    }
    function inspect(path, cb) {
        const p = inspProc.createObject(root, {
            path
        });
        p.done.connect(cb);
        p.running = true;
    }
    property Component inspProc: Component {
        Process {
            id: ip
            property string path
            signal done(bool exec, bool inMenu)
            command: ["sh", "-c", '[ -x "$1" ] && echo x; [ -e "$2" ] && echo m; true', "sh", path, root.appsDir + "/" + root.desktopIdFor(path) + ".desktop"]
            stdout: StdioCollector {
                id: ipOut
            }
            onExited: {
                ip.done(ipOut.text.includes("x"), ipOut.text.includes("m"));
                ip.destroy();
            }
        }
    }
    // Ярлык в меню приложений (лаунчер оболочки и все остальные)
    function addToMenu(path) {
        const name = path.split("/").pop().replace(/\.(appimage|sh|bash|run|py)$/i, "").replace(/[-_.]+(x86_64|amd64|linux|v?\d[\w.]*)$/i, "").replace(/[-_]+/g, " ");
        run(["sh", "-c", `
            f="$1"; out="$2"; name="$3"; term=false
            chmod +x -- "$f"
            exec_line="\\"$f\\""
            case "$f" in
                *.[Aa]pp[Ii]mage|*.APPIMAGE) command -v appimage-run >/dev/null && exec_line="appimage-run \\"$f\\"" ;;
                *.sh|*.bash|*.run|*.py|*.pl|*.rb) term=true ;;
            esac
            mkdir -p "$(dirname "$out")"
            printf '[Desktop Entry]\\nType=Application\\nName=%s\\nExec=%s\\nPath=%s\\nIcon=application-x-executable\\nTerminal=%s\\nCategories=Utility;\\nComment=Добавлено из «Файлов»: %s\\n' \\
                "$name" "$exec_line" "$(dirname -- "$f")" "$term" "$f" > "$out"
        `, "sh", path, appsDir + "/" + desktopIdFor(path) + ".desktop", name]);
    }
    function removeFromMenu(path) {
        run(["rm", "-f", appsDir + "/" + desktopIdFor(path) + ".desktop"]);
    }

    // --- Сетевые папки (gvfs: smb, sftp, ftp, webdav) ---------------------------
    readonly property string gvfsDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user") + "/gvfs"
    property var mounts: []
    function refreshMounts() {
        mountsProc.running = true;
    }
    Process {
        id: mountsProc
        command: ["sh", "-c", 'for d in "$1"/*; do [ -d "$d" ] && printf "%s\\n" "$d"; done; true', "sh", root.gvfsDir]
        stdout: StdioCollector {
            onStreamFinished: root.mounts = text.split("\n").filter(l => l).map(path => {
                const id = path.split("/").pop();
                const kv = {};
                for (const part of (id.split(":")[1] ?? "").split(","))
                    kv[part.split("=")[0]] = decodeURIComponent(part.split("=")[1] ?? "");
                const proto = id.split(":")[0].replace("-share", "");
                const name = kv.share ? kv.share + " на " + kv.server : (kv.user ? kv.user + "@" : "") + (kv.host ?? kv.server ?? id);
                return {
                    path,
                    name,
                    proto,
                    icon: proto === "smb" ? "lan" : "cloud"
                };
            })
        }
    }
    Timer {
        running: root.windows.length > 0
        interval: 4000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshMounts()
    }
    // Подключить: логин и пароль уходят в gio mount через stdin
    function connect(uri, user, pass, save, cb) {
        const p = mountProc.createObject(root, {
            uri,
            user,
            pass
        });
        p.done.connect((ok, path, err) => {
            if (ok && save && !Settings.data.netPlaces.some(n => n.uri === uri))
                Settings.data.netPlaces = [...Settings.data.netPlaces, {
                        uri,
                        user
                    }];
            refreshMounts();
            cb(ok, path, err);
        });
        busy++;
        p.running = true;
    }
    property Component mountProc: Component {
        Process {
            id: mp
            property string uri
            property string user
            property string pass
            signal done(bool ok, string path, string err)
            command: ["sh", "-c", `
                uri="$1"; user="$2"; pass="$3"
                if ! gio info "$uri" >/dev/null 2>&1; then
                    if [ -z "$user" ] && [ -z "$pass" ]; then
                        gio mount -a "$uri" </dev/null || exit 1
                    else
                        case "$uri" in
                            smb://*) printf '%s\\n%s\\n%s\\n' "$user" "WORKGROUP" "$pass" | gio mount "$uri" || exit 1 ;;
                            *) printf '%s\\n%s\\n' "$user" "$pass" | gio mount "$uri" || exit 1 ;;
                        esac
                    fi
                fi
                gio info "$uri" | sed -n 's/^local path: //p'
            `, "sh", uri, user, pass]
            stdout: StdioCollector {
                id: mpOut
            }
            stderr: StdioCollector {
                id: mpErr
            }
            onExited: code => {
                root.busy--;
                mp.done(code === 0 && mpOut.text.trim() !== "", mpOut.text.trim(), mpErr.text.trim().split("\n").pop());
                mp.destroy();
            }
        }
    }
    function disconnect(path) {
        run(["gio", "mount", "-u", path]);
        Qt.callLater(refreshMounts);
    }
    function forgetPlace(uri) {
        Settings.data.netPlaces = Settings.data.netPlaces.filter(n => n.uri !== uri);
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
            // LC_ALL=C: заголовки gio mime иначе приходят по-русски, и разбор их не находит
            command: ["sh", "-c", 'export LC_ALL=C; m=$(xdg-mime query filetype "$1" 2>/dev/null); echo "#$m"; gio mime "$m" 2>/dev/null', "sh", path]
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
