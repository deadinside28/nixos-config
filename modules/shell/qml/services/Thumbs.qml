pragma Singleton

// Превью видео для «Файлов»: кадр через ffmpeg в ~/.cache/pixel-shell/thumbs.
// Картинки показываются как есть, а видео — по кешированному кадру.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Settings.home + "/.cache") + "/pixel-shell/thumbs"
    // растёт, когда готов новый кадр, — Image перечитывает источник
    property int revision: 0
    property var tried: ({})

    function urlFor(path, rev) {
        return "file://" + dir + "/" + Qt.md5(path) + ".jpg?r=" + rev;
    }
    function make(path) {
        if (tried[path])
            return;
        const t = Object.assign({}, tried);
        t[path] = true;
        tried = t;
        const p = proc.createObject(root, {
            path
        });
        p.running = true;
    }
    property Component proc: Component {
        Process {
            id: pr
            property string path
            command: ["sh", "-c", 'mkdir -p "$1"; ffmpeg -loglevel error -y -ss 3 -i "$2" -frames:v 1 -vf "scale=320:-2" "$3" || ffmpeg -loglevel error -y -i "$2" -frames:v 1 -vf "scale=320:-2" "$3"', "sh", root.dir, path, root.dir + "/" + Qt.md5(path) + ".jpg"]
            onExited: code => {
                if (code === 0)
                    root.revision++;
                pr.destroy();
            }
        }
    }
}
