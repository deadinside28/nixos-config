// Окно «Календаря» — по требованию (pixel-shell calendar open, клик по часам).
import QtQuick
import Quickshell
import qs.common

Scope {
    LazyLoader {
        active: Ui.calendarOpen
        CalendarWindow {}
    }
}
