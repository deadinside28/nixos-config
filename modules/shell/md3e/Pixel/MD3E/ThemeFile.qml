// Тема Pixel Shell в самостоятельном приложении: читает colors.json и
// settings.json оболочки (~/.local/state/pixel-shell) и задаёт входы Theme.
// Положить один раз в корневое окно:  ThemeFile {}
// Чтение локальных файлов через XMLHttpRequest требует
// QML_XHR_ALLOW_FILE_READ=1 — его ставит обёртка приложения.
import QtQuick
import QtCore

QtObject {
    id: root

    property url stateDir: StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/pixel-shell"
    // Оболочка меняет файлы на лету (смена обоев, тёмная тема) — опрос
    property int interval: 2000

    property string _colors: ""
    property string _settings: ""

    function read(name, done) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState === XMLHttpRequest.DONE && x.responseText)
                done(x.responseText);
        };
        x.open("GET", stateDir + "/" + name);
        x.send();
    }
    function reload() {
        read("colors.json", t => {
            if (t === _colors)
                return;
            _colors = t;
            try {
                Theme.scheme = JSON.parse(t);
            } catch (e) {}
        });
        read("settings.json", t => {
            if (t === _settings)
                return;
            _settings = t;
            let s;
            try {
                s = JSON.parse(t);
            } catch (e) {
                return;
            }
            if (typeof s.darkMode === "boolean")
                Theme.dark = s.darkMode;
            if (s.uiFont)
                Theme.font = s.uiFont;
            if (s.monoFont)
                Theme.monoFont = s.monoFont;
            if (s.uiFontWeight)
                Theme.fontWeightName = s.uiFontWeight;
            if (s.uiFontSize)
                Theme.fontSize = s.uiFontSize;
            if (typeof s.animationScale === "number")
                Theme.animationScale = s.animationScale;
        });
    }

    property Timer _poll: Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.reload()
    }
}
