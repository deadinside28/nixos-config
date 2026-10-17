pragma Singleton

import QtQuick
import Quickshell
import qs.common

Singleton {
    id: root

    readonly property date now: clock.date
    readonly property string time: Qt.formatDateTime(now, Settings.data.use24h ? (Settings.data.showSeconds ? "HH:mm:ss" : "HH:mm") : (Settings.data.showSeconds ? "h:mm:ss AP" : "h:mm AP"))
    readonly property string dateShort: now.toLocaleDateString(Qt.locale("ru_RU"), "d MMM")
    readonly property string dateLong: now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM")

    SystemClock {
        id: clock
        precision: Settings.data.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
