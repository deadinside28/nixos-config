pragma Singleton

// Окна-хосты экранов (modules/frame/ScreenHost.qml): на каждом мониторе
// одно постоянное полноэкранное окно, в нём рамка и все выдвижные панели
// (widgets/Overlay.qml). Панель — элемент внутри хоста, а не своё окно:
// открытие ничего не создаёт и не отображает заново, и анимация идёт с
// первого кадра. Так же устроен Caelestia (ContentWindow).
import QtQuick
import Quickshell

Singleton {
    id: root

    // имя экрана → элемент хоста, куда встают панели
    property var items: ({})
    // все панели (Overlay), открытые и закрытые
    property var overlays: []

    function register(screenName, item) {
        const o = Object.assign({}, items);
        o[screenName] = item;
        items = o;
    }
    function unregister(screenName, item) {
        if (items[screenName] !== item)
            return;
        const o = Object.assign({}, items);
        delete o[screenName];
        items = o;
    }
    function addOverlay(ov) {
        overlays = [...overlays, ov];
    }
    function removeOverlay(ov) {
        overlays = overlays.filter(x => x !== ov);
    }
    // OSD и уведомления: свои места на экране, без затемнения; уведомлениям
    // нужен ввод (takesInput) — хост пропускает мышь только в их область
    property var floaters: []
    function addFloater(f) {
        floaters = [...floaters, f];
    }
    function removeFloater(f) {
        floaters = floaters.filter(x => x !== f);
    }
    function floatersOn(screenName) {
        return floaters.filter(f => f.hostShown && (f.hostScreen ?? f.screenName) === screenName);
    }

    // панели, которые сейчас видны на экране (открыты или закрываются)
    function shownOn(screenName) {
        return overlays.filter(o => o.shown && o.screenName === screenName);
    }
}
