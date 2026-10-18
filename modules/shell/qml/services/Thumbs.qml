pragma Singleton

// Превью видео для «Файлов»: кадр через ffmpeg в ~/.cache/pixel-shell/thumbs.
// Картинки показываются как есть, а видео — по кешированному кадру.
//
// Кадры делаются в общей очереди: не больше `parallel` ffmpeg сразу, с
// пониженным приоритетом. Превью, ушедшее с экрана до старта, из очереди
// убирается. Ключ кеша — путь и время изменения: изменённое видео получает
// новый кадр, а не старый из кеша.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Settings.home + "/.cache") + "/pixel-shell/thumbs"
    readonly property int parallel: 2
    // Кадр готов — превью с этим ключом перечитывает файл
    signal ready(string key)

    function keyFor(path, modified) {
        return Qt.md5(path + "\n" + (new Date(modified).getTime() || 0));
    }
    function urlFor(key) {
        return "file://" + dir + "/" + key + ".jpg";
    }

    property var tried: ({}) // ключ → уже пробовали (повторно не мучаем битые файлы)
    property var queue: [] // [{ key, path }]
    property int active: 0

    function make(path, key) {
        if (tried[key])
            return;
        tried[key] = true;
        queue.push({
            key,
            path
        });
        pump();
    }
    // Превью уничтожено (прокрутили, сменили папку) — не делать его кадр
    function cancel(key) {
        const i = queue.findIndex(j => j.key === key);
        if (i < 0)
            return;
        queue.splice(i, 1);
        delete tried[key];
    }
    function pump() {
        while (active < parallel && queue.length > 0) {
            const j = queue.shift();
            active++;
            proc.createObject(root, {
                path: j.path,
                key: j.key
            }).running = true;
        }
    }

    // Раз за сессию — убрать кадры, к которым давно не обращались
    property bool cleaned: false
    onActiveChanged: if (active > 0 && !cleaned) {
        cleaned = true;
        Quickshell.execDetached(["find", dir, "-maxdepth", "1", "-type", "f", "-atime", "+60", "-delete"]);
    }

    property Component proc: Component {
        Process {
            id: pr
            property string path
            property string key
            // Пишем во временный файл: недописанный кадр не попадёт в кеш.
            // timeout — битые и сетевые файлы не держат очередь.
            command: ["sh", "-c", `
                mkdir -p "$1"; tmp="$3.part.jpg"
                shot() { timeout 20 nice -n 10 ffmpeg -nostdin -loglevel error -threads 1 -y "$@" -frames:v 1 -vf "scale=320:-2" "$tmp"; }
                { shot -ss 3 -i "$2" && [ -s "$tmp" ]; } || shot -i "$2" || { rm -f "$tmp"; exit 1; }
                mv -f "$tmp" "$3"
            `, "sh", root.dir, path, root.dir + "/" + key + ".jpg"]
            onExited: code => {
                root.active--;
                if (code === 0)
                    root.ready(pr.key);
                root.pump();
                pr.destroy();
            }
        }
    }
}
