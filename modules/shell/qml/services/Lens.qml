pragma Singleton

// «Обвести и найти» и перевод экрана, как на Pixel. Снимок экрана с фокусом
// замирает, поверх рисуется интерфейс; распознавание, перевод и поиск делает
// pixel-lens (PaddleOCR + tesseract, перевод Google, Google Lens).
//   mode: search — обвести и найти; translate — перевести снимок целиком;
//         live — перевод в реальном времени поверх живого экрана.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property bool active: false
    property string mode: "search"
    property string screen: ""
    property string shot: ""
    property size shotSize: Qt.size(0, 0)
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pixel-lens"

    // Выделенная область (в пикселях снимка) и её вырезка
    property rect area: Qt.rect(0, 0, 0, 0)
    property string crop: ""
    // Распознанный текст области и его перевод
    property string text: ""
    property string textTranslated: ""
    // Перевод: [{ x, y, w, h, lh, bg, fg, text }] в пикселях снимка
    property var boxes: []
    property bool busy: false
    property string status: ""
    // в живом режиме слой прячется на время снимка
    property bool capturing: false

    readonly property string langs: Settings.data.ocrLangs
    readonly property string target: Settings.data.translateTo

    readonly property var languages: [
        {
            value: "ru",
            label: "Русский"
        },
        {
            value: "en",
            label: "Английский"
        },
        {
            value: "uk",
            label: "Украинский"
        },
        {
            value: "de",
            label: "Немецкий"
        },
        {
            value: "fr",
            label: "Французский"
        },
        {
            value: "es",
            label: "Испанский"
        },
        {
            value: "it",
            label: "Итальянский"
        },
        {
            value: "pl",
            label: "Польский"
        },
        {
            value: "ja",
            label: "Японский"
        },
        {
            value: "zh-CN",
            label: "Китайский"
        },
        {
            value: "ko",
            label: "Корейский"
        }
    ]

    function start(m) {
        if (active && mode === m) {
            stop();
            return;
        }
        // открытая панель не должна попасть в снимок — даём ей закрыться
        const wait = Ui.panel !== "";
        Ui.close();
        mode = m;
        screen = Ui.focusedScreen;
        area = Qt.rect(0, 0, 0, 0);
        crop = "";
        text = "";
        textTranslated = "";
        boxes = [];
        status = "";
        if (m === "live")
            active = true;
        if (wait)
            startDelay.restart();
        else
            capture();
    }
    Timer {
        id: startDelay
        interval: Theme.anim.normal + 80
        onTriggered: root.capture()
    }
    function stop() {
        active = false;
        liveTimer.stop();
        boxes = [];
        busy = false;
    }

    // --- Снимок ---------------------------------------------------------------
    function capture() {
        const f = dir + "/shot-" + Date.now() + ".png";
        if (mode === "live") {
            capturing = true;
            // дать слою один кадр, чтобы исчезнуть
            shotDelay.file = f;
            shotDelay.restart();
            return;
        }
        shotProc.file = f;
        shotProc.running = true;
    }
    Timer {
        id: shotDelay
        property string file
        interval: 60
        onTriggered: {
            shotProc.file = file;
            shotProc.running = true;
        }
    }
    Process {
        id: shotProc
        property string file
        command: ["sh", "-c", 'mkdir -p "$1"; find "$1" -name "shot-*.png" -mmin +2 -delete; pixel-lens shot "$2" "$3"', "sh", root.dir, root.screen, file]
        onExited: code => {
            root.capturing = false;
            if (code !== 0) {
                root.status = "Не получилось сделать снимок экрана";
                if (root.mode !== "live")
                    root.active = false;
                return;
            }
            root.shot = file;
            if (root.mode !== "live")
                root.active = true;
            if (root.mode === "translate" || root.mode === "live")
                root.translateShot();
        }
    }

    // --- Перевод снимка (абзацы на своих местах) --------------------------------
    function translateShot() {
        busy = true;
        status = "Перевожу…";
        trProc.running = false;
        trProc.command = ["pixel-lens", "translate", crop || shot, langs, target];
        trProc.running = true;
    }
    Process {
        id: trProc
        stdout: StdioCollector {
            id: trOut
        }
        // перезапущенный (убитый) процесс не должен затирать результат
        onExited: code => {
            if (code !== 0) {
                if (root.mode === "live" && root.active)
                    liveTimer.restart();
                return;
            }
            const text = trOut.text;
            {
                const ox = root.crop ? root.area.x : 0;
                const oy = root.crop ? root.area.y : 0;
                root.boxes = text.split("\n").filter(l => l).map(l => {
                    // цвета фона и текста — с оригинала (их считает pixel-lens)
                    const [x, y, w, h, lh, bg, fg, ...rest] = l.split("\t");
                    return {
                        x: parseInt(x) + ox,
                        y: parseInt(y) + oy,
                        w: parseInt(w),
                        h: parseInt(h),
                        lh: parseInt(lh),
                        bg: "#" + bg,
                        fg: "#" + fg,
                        text: rest.join(" ").trim()
                    };
                }).filter(b => b.text);
                root.busy = false;
                root.status = root.boxes.length ? "" : "Текста не нашлось";
                if (root.mode === "live" && root.active)
                    liveTimer.restart();
            }
        }
    }
    // Живой перевод: снимок каждые несколько секунд, пока включён
    Timer {
        id: liveTimer
        interval: 1200
        onTriggered: if (root.active && root.mode === "live")
            root.capture()
    }

    // --- Область ----------------------------------------------------------------
    function select(r) {
        area = r;
        text = "";
        textTranslated = "";
        boxes = [];
        const f = dir + "/crop-" + Date.now() + ".png";
        cropProc.file = f;
        cropProc.running = false;
        cropProc.command = ["pixel-lens", "crop", shot, `${Math.round(r.width)}x${Math.round(r.height)}+${Math.round(r.x)}+${Math.round(r.y)}`, f];
        cropProc.running = true;
    }
    Process {
        id: cropProc
        property string file
        onExited: code => {
            if (code === 0)
                root.crop = file;
        }
    }

    function searchCrop() {
        if (!crop)
            return;
        Quickshell.execDetached(["pixel-lens", "search", crop]);
        stop();
    }
    function recognize() {
        busy = true;
        status = "Распознаю текст…";
        ocrProc.running = false;
        ocrProc.command = ["pixel-lens", "ocr", crop || shot, langs];
        ocrProc.running = true;
    }
    Process {
        id: ocrProc
        stdout: StdioCollector {
            id: ocrOut
        }
        onExited: code => {
            if (code !== 0)
                return;
            root.text = ocrOut.text.trim();
            root.busy = false;
            root.status = root.text ? "" : "Текста не нашлось";
        }
    }
    function translateText() {
        if (!text)
            return;
        busy = true;
        txtProc.running = false;
        txtProc.command = ["pixel-lens", "text", target, text];
        txtProc.running = true;
    }
    Process {
        id: txtProc
        stdout: StdioCollector {
            id: txtOut
        }
        onExited: code => {
            if (code !== 0)
                return;
            root.textTranslated = txtOut.text.trim();
            root.busy = false;
        }
    }
    function copyImage() {
        Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", crop || shot]);
    }
    function copyText(t) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", t]);
    }
    function saveImage() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$HOME/Pictures/Screenshots"; f="$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"; cp "$1" "$f" && notify-send -a "Скриншот" -i "$f" "Сохранено" "Pictures/Screenshots"', "sh", crop || shot]);
    }
    function webSearch(q) {
        Quickshell.execDetached(["xdg-open", Settings.data.searchEngine + encodeURIComponent(q)]);
        stop();
    }
}
