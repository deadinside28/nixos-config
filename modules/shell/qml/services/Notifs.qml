pragma Singleton

// Сервер уведомлений: история (центр уведомлений) и всплывающие карточки.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.common

Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values.slice().reverse()
    readonly property int count: list.length
    // Всплывающие сейчас (объекты Notification)
    property var popups: []

    signal notified(var notification)

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: n => {
            n.tracked = true;
            const critical = n.urgency === NotificationUrgency.Critical;
            // Скриншоты и запись экрана можно не показывать вовсе
            if (!Settings.data.notifyScreenshots && ["Скриншот", "Запись экрана"].includes(n.appName)) {
                n.dismiss();
                return;
            }
            if (critical || (!Settings.data.dnd && Settings.data.notifPopups)) {
                root.popups = [n, ...root.popups].slice(0, 5);
            }
            root.notified(n);
        }
    }

    function dismissPopup(n) {
        popups = popups.filter(p => p !== n);
    }
    function dismiss(n) {
        dismissPopup(n);
        n.dismiss();
    }
    function clearAll() {
        popups = [];
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.expireTimeout > 0 ? Math.min(n.expireTimeout, 30000) : Settings.data.notifTimeout;
    }
    function icon(n) {
        if (n.appIcon)
            return n.appIcon;
        if (n.desktopEntry) {
            const e = DesktopEntries.byId(n.desktopEntry);
            if (e)
                return e.icon;
        }
        const h = DesktopEntries.heuristicLookup(n.appName);
        return h?.icon ?? "";
    }
}
