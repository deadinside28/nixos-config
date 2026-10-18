// «Календарь» — отдельное окно: месяц, неделя, день и повестка, справа —
// правка события. Данные и повторения — services/Calendar.qml и calendar.js.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import qs.common
import qs.widgets
import qs.services

FloatingWindow {
    id: win
    title: "Календарь"
    implicitWidth: 1180
    implicitHeight: 780
    minimumSize: Qt.size(820, 560)
    color: Theme.surfaceContainer
    visible: true
    onVisibleChanged: if (!visible)
        Ui.calendarOpen = false

    readonly property var loc: Qt.locale("ru_RU")
    property string view: "month" // month | week | day | agenda
    property date cursor: new Date() // выбранный день
    property var editing: null // копия события в правке или null
    property var editingOcc: null // вхождение, из которого открыли правку

    function startOfDay(d) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    }
    function addDays(d, n) {
        return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
    }
    readonly property date today: startOfDay(new Date())
    // Диапазон текущего представления
    readonly property date rangeFrom: {
        const c = startOfDay(cursor);
        if (view === "month") {
            const first = new Date(c.getFullYear(), c.getMonth(), 1);
            return addDays(first, -((first.getDay() + 6) % 7));
        }
        if (view === "week")
            return addDays(c, -((c.getDay() + 6) % 7));
        return c;
    }
    readonly property date rangeTo: view === "month" ? addDays(rangeFrom, 42) : view === "week" ? addDays(rangeFrom, 7) : view === "day" ? addDays(rangeFrom, 1) : addDays(rangeFrom, 60)
    readonly property var occ: {
        const _ = Calendar.events;
        return Calendar.occurrences(rangeFrom, rangeTo);
    }
    function occOn(day) {
        const next = addDays(day, 1);
        return occ.filter(o => o.start < next && o.end > day || (o.start >= day && o.start < next));
    }
    function step(n) {
        const c = cursor;
        cursor = view === "month" ? new Date(c.getFullYear(), c.getMonth() + n, 1) : addDays(c, n * (view === "week" ? 7 : view === "day" ? 1 : 30));
    }
    function timeText(o) {
        return o.ev.allDay ? "Весь день" : o.start.toLocaleTimeString(loc, "HH:mm") + "–" + o.end.toLocaleTimeString(loc, "HH:mm");
    }

    function newEvent(day) {
        const d = day ?? cursor;
        const h = new Date().getHours() + 1;
        const s = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.min(h, 22), 0);
        editingOcc = null;
        editing = {
            id: Calendar.newId(),
            title: "",
            start: Calendar.formatLocal(s, false),
            end: Calendar.formatLocal(new Date(s.getTime() + 3600000), false),
            allDay: false,
            rrule: null,
            exdates: [],
            location: "",
            notes: "",
            remind: 10,
            isNew: true
        };
    }
    function edit(o) {
        editingOcc = o;
        editing = JSON.parse(JSON.stringify(o.ev));
    }

    Shortcut {
        sequence: "Escape"
        onActivated: win.editing ? win.editing = null : Ui.calendarOpen = false
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: win.newEvent()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // --- Шапка -----------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                MText {
                    Layout.leftMargin: 8
                    Layout.preferredWidth: 280
                    text: win.view === "month" ? win.cursor.toLocaleDateString(win.loc, "LLLL yyyy") : win.view === "day" ? win.cursor.toLocaleDateString(win.loc, "d MMMM yyyy, dddd") : win.rangeFrom.toLocaleDateString(win.loc, "d MMM") + " — " + win.addDays(win.rangeTo, -1).toLocaleDateString(win.loc, "d MMM yyyy")
                    size: Theme.type.headlineS
                    elide: Text.ElideRight
                }
                IconButton {
                    icon: "chevron_left"
                    onClicked: win.step(-1)
                }
                Button {
                    variant: "tonal"
                    text: "Сегодня"
                    onClicked: win.cursor = new Date()
                }
                IconButton {
                    icon: "chevron_right"
                    onClicked: win.step(1)
                }
                SegmentedButtons {
                    Layout.fillWidth: true
                    options: [
                        {
                            value: "month",
                            label: "Месяц"
                        },
                        {
                            value: "week",
                            label: "Неделя"
                        },
                        {
                            value: "day",
                            label: "День"
                        },
                        {
                            value: "agenda",
                            label: "Повестка"
                        }
                    ]
                    current: win.view
                    onSelected: v => win.view = v
                }
                Button {
                    icon: "add"
                    text: "Событие"
                    disabled: Calendar.error !== ""
                    onClicked: win.newEvent()
                }
                IconButton {
                    icon: "more_vert"
                    tooltip: "Импорт и экспорт .ics"
                    onClicked: icsBox.visible = !icsBox.visible
                }
            }
            MText {
                Layout.fillWidth: true
                visible: Calendar.error !== ""
                text: Calendar.error
                color: Theme.error
                wrapMode: Text.WordWrap
            }
            RowLayout {
                id: icsBox
                visible: false
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: icsPath
                    Layout.fillWidth: true
                    implicitHeight: 48
                    icon: "description"
                    placeholder: "Путь к .ics"
                    text: Settings.home + "/Documents/Календарь.ics"
                }
                Button {
                    variant: "tonal"
                    text: "Импорт"
                    disabled: Calendar.error !== ""
                    onClicked: Calendar.importIcs(icsPath.text.trim())
                }
                Button {
                    variant: "tonal"
                    text: "Экспорт"
                    onClicked: Calendar.exportIcs(icsPath.text.trim())
                }
                MText {
                    text: Calendar.icsMessage
                    color: Theme.fgSurfaceVariant
                    size: Theme.type.bodyS
                }
            }

            // --- Месяц -------------------------------------------------
            ColumnLayout {
                visible: win.view === "month"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                        MText {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            size: Theme.type.labelL
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4
                    Repeater {
                        model: 42
                        Rectangle {
                            id: cell
                            required property int index
                            readonly property date day: win.addDays(win.rangeFrom, index)
                            readonly property bool inMonth: day.getMonth() === win.cursor.getMonth()
                            readonly property bool isToday: day.getTime() === win.today.getTime()
                            readonly property var items: win.occOn(day)
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 1
                            radius: 12
                            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                            opacity: inMonth ? 1 : 0.55
                            clip: true
                            StateLayer {
                                onClicked: win.cursor = cell.day
                                onDoubleClicked: win.newEvent(cell.day)
                            }
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 2
                                Rectangle {
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    radius: 14
                                    color: cell.isToday ? Theme.primary : cell.day.getTime() === win.startOfDay(win.cursor).getTime() ? Theme.secondaryContainer : "transparent"
                                    MText {
                                        anchors.centerIn: parent
                                        text: cell.day.getDate()
                                        color: cell.isToday ? Theme.fgPrimary : Theme.fgSurface
                                        size: Theme.type.labelL
                                    }
                                }
                                Repeater {
                                    model: cell.items.slice(0, 3)
                                    EventChip {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        occ: modelData
                                        compact: true
                                    }
                                }
                                MText {
                                    visible: cell.items.length > 3
                                    text: "ещё " + (cell.items.length - 3)
                                    size: Theme.type.labelS
                                    color: Theme.fgSurfaceVariant
                                }
                                Item {
                                    Layout.fillHeight: true
                                }
                            }
                        }
                    }
                }
            }

            // --- Неделя / день ------------------------------------------
            RowLayout {
                visible: win.view === "week" || win.view === "day"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                Repeater {
                    model: win.view === "week" ? 7 : win.view === "day" ? 1 : 0
                    Rectangle {
                        id: col
                        required property int index
                        readonly property date day: win.addDays(win.rangeFrom, index)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 12
                        color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4
                            MText {
                                text: col.day.toLocaleDateString(win.loc, "ddd, d MMM")
                                weight: Theme.strongWeight
                                color: col.day.getTime() === win.today.getTime() ? Theme.primary : Theme.fgSurface
                            }
                            Repeater {
                                model: win.occOn(col.day)
                                EventChip {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    occ: modelData
                                }
                            }
                            Item {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                StateLayer {
                                    onDoubleClicked: win.newEvent(col.day)
                                }
                            }
                        }
                    }
                }
            }

            // --- Повестка --------------------------------------------------
            ListView {
                visible: win.view === "agenda"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: win.view === "agenda" ? win.occ : []
                delegate: EventChip {
                    required property var modelData
                    width: ListView.view.width
                    occ: modelData
                    showDate: true
                }
                MText {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: "В ближайшие 60 дней событий нет"
                    color: Theme.fgSurfaceVariant
                }
            }
        }

        // --- Правка события --------------------------------------------------
        Rectangle {
            visible: win.editing !== null
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            radius: Theme.radius.xl
            color: Theme.surface
            EventEditor {
                anchors.fill: parent
                anchors.margins: 16
            }
        }
    }

    // Событие в сетке и списках
    component EventChip: Rectangle {
        id: chip
        property var occ
        property bool compact: false
        property bool showDate: false
        implicitHeight: compact ? 22 : chipCol.implicitHeight + 12
        radius: 8
        color: Theme.primaryContainer
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            visible: chip.compact
            MText {
                Layout.fillWidth: true
                text: (chip.occ.ev.allDay ? "" : chip.occ.start.toLocaleTimeString(win.loc, "HH:mm") + " ") + chip.occ.ev.title
                size: Theme.type.labelS
                color: Theme.fgPrimaryContainer
                elide: Text.ElideRight
            }
        }
        ColumnLayout {
            id: chipCol
            visible: !chip.compact
            x: 10
            y: 6
            width: parent.width - 20
            spacing: 0
            MText {
                Layout.fillWidth: true
                text: chip.occ.ev.title || "Без названия"
                weight: Theme.strongWeight
                color: Theme.fgPrimaryContainer
                elide: Text.ElideRight
            }
            MText {
                Layout.fillWidth: true
                text: (chip.showDate ? chip.occ.start.toLocaleDateString(win.loc, "ddd, d MMM") + " · " : "") + win.timeText(chip.occ) + (chip.occ.ev.rrule ? " · повтор" : "") + (chip.occ.ev.location ? " · " + chip.occ.ev.location : "")
                size: Theme.type.bodyS
                color: Theme.fgPrimaryContainer
                elide: Text.ElideRight
            }
        }
        StateLayer {
            onClicked: win.edit(chip.occ)
        }
    }

    // Правка: поля события и повтора
    component EventEditor: ColumnLayout {
        id: ed
        readonly property var e: win.editing ?? {}
        function set(k, v) {
            const n = Object.assign({}, win.editing);
            n[k] = v;
            win.editing = n;
        }
        // "2026-10-18" + "10:00" → "2026-10-18T10:00"
        function joinDT(date, time) {
            return ed.e.allDay ? date : date + "T" + (time || "09:00");
        }
        spacing: 10
        MText {
            text: ed.e.isNew ? "Новое событие" : "Событие"
            size: Theme.type.titleL
        }
        TextField {
            Layout.fillWidth: true
            implicitHeight: 48
            placeholder: "Название"
            text: ed.e.title ?? ""
            onTextChanged: if (text !== ed.e.title)
                ed.set("title", text)
        }
        SwitchItem {
            title: "Весь день"
            checked: !!ed.e.allDay
            onToggled: v => {
                const n = Object.assign({}, win.editing);
                n.allDay = v;
                n.start = (n.start ?? "").slice(0, 10) + (v ? "" : "T09:00");
                n.end = (n.end ?? n.start).slice(0, 10) + (v ? "" : "T10:00");
                win.editing = n;
            }
        }
        // Даты и время читаются из полей при сохранении
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            TextField {
                id: startDate
                Layout.fillWidth: true
                implicitHeight: 48
                placeholder: "ГГГГ-ММ-ДД"
                text: (ed.e.start ?? "").slice(0, 10)
            }
            TextField {
                id: startTime
                Layout.fillWidth: true
                implicitHeight: 48
                visible: !ed.e.allDay
                placeholder: "ЧЧ:ММ"
                text: (ed.e.start ?? "").slice(11, 16)
            }
            TextField {
                id: endDate
                Layout.fillWidth: true
                implicitHeight: 48
                placeholder: "Конец: ГГГГ-ММ-ДД"
                text: (ed.e.end ?? "").slice(0, 10)
            }
            TextField {
                id: endTime
                Layout.fillWidth: true
                implicitHeight: 48
                visible: !ed.e.allDay
                placeholder: "ЧЧ:ММ"
                text: (ed.e.end ?? "").slice(11, 16)
            }
        }
        ChoiceItem {
            icon: "repeat"
            title: "Повтор"
            options: [
                {
                    value: "",
                    label: "Не повторять"
                },
                {
                    value: "daily",
                    label: "Каждый день"
                },
                {
                    value: "weekly",
                    label: "Каждую неделю"
                },
                {
                    value: "monthly",
                    label: "Каждый месяц"
                },
                {
                    value: "yearly",
                    label: "Каждый год"
                }
            ]
            current: ed.e.rrule?.freq ?? ""
            onSelected: v => ed.set("rrule", v ? Object.assign({
                    interval: 1,
                    byday: []
                }, ed.e.rrule ?? {}, {
                    freq: v
                }) : null)
        }
        Flow {
            Layout.fillWidth: true
            visible: ed.e.rrule?.freq === "weekly"
            spacing: 4
            Repeater {
                model: [["MO", "Пн"], ["TU", "Вт"], ["WE", "Ср"], ["TH", "Чт"], ["FR", "Пт"], ["SA", "Сб"], ["SU", "Вс"]]
                Rectangle {
                    required property var modelData
                    readonly property bool on: (ed.e.rrule?.byday ?? []).includes(modelData[0])
                    implicitWidth: 40
                    implicitHeight: 32
                    radius: 8
                    color: on ? Theme.secondaryContainer : "transparent"
                    border.width: on ? 0 : 1
                    border.color: Theme.outlineVariant
                    MText {
                        anchors.centerIn: parent
                        text: parent.modelData[1]
                        size: Theme.type.labelL
                    }
                    StateLayer {
                        onClicked: {
                            const r = Object.assign({}, ed.e.rrule);
                            const d = parent.modelData[0];
                            r.byday = parent.on ? r.byday.filter(x => x !== d) : [...(r.byday ?? []), d];
                            ed.set("rrule", r);
                        }
                    }
                }
            }
        }
        TextField {
            id: untilField
            Layout.fillWidth: true
            implicitHeight: 48
            visible: !!ed.e.rrule
            placeholder: "Повторять до (ГГГГ-ММ-ДД), пусто — всегда"
            text: ed.e.rrule?.until ?? ""
        }
        ChoiceItem {
            icon: "notifications"
            title: "Напомнить"
            options: [
                {
                    value: -1,
                    label: "Не напоминать"
                },
                {
                    value: 0,
                    label: "В момент начала"
                },
                {
                    value: 10,
                    label: "За 10 минут"
                },
                {
                    value: 30,
                    label: "За 30 минут"
                },
                {
                    value: 60,
                    label: "За час"
                },
                {
                    value: 1440,
                    label: "За день"
                }
            ]
            current: ed.e.remind === null || ed.e.remind === undefined ? -1 : ed.e.remind
            onSelected: v => ed.set("remind", v < 0 ? null : v)
        }
        TextField {
            Layout.fillWidth: true
            implicitHeight: 48
            icon: "location_on"
            placeholder: "Место"
            text: ed.e.location ?? ""
            onTextChanged: if (text !== (ed.e.location ?? ""))
                ed.set("location", text)
        }
        QQC.TextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: "Заметки"
            wrapMode: TextEdit.Wrap
            font.family: Theme.font
            color: Theme.fgSurface
            text: ed.e.notes ?? ""
            onTextChanged: if (activeFocus && text !== (ed.e.notes ?? ""))
                ed.set("notes", text)
        }
        MText {
            id: edError
            Layout.fillWidth: true
            visible: text !== ""
            color: Theme.error
            wrapMode: Text.WordWrap
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Button {
                icon: "check"
                text: "Сохранить"
                onClicked: {
                    const n = Object.assign({}, win.editing);
                    n.start = ed.joinDT(startDate.text.trim(), startTime.text.trim());
                    n.end = endDate.text.trim() ? ed.joinDT(endDate.text.trim(), endTime.text.trim()) : "";
                    if (n.rrule)
                        n.rrule = Object.assign({}, n.rrule, {
                            until: untilField.text.trim()
                        });
                    const s = Calendar.parseLocal(n.start), e = Calendar.parseLocal(n.end);
                    if (!s) {
                        edError.text = "Неверная дата начала";
                        return;
                    }
                    if (n.rrule?.until && !Calendar.parseLocal(n.rrule.until)) {
                        edError.text = "Неверная дата «повторять до»";
                        return;
                    }
                    if (n.end && (!e || e < s)) {
                        edError.text = "Конец раньше начала";
                        return;
                    }
                    delete n.isNew;
                    if (Calendar.upsert(n))
                        win.editing = null;
                    edError.text = "";
                }
            }
            Button {
                visible: !ed.e.isNew && !!ed.e.rrule && win.editingOcc !== null
                variant: "tonal"
                text: "Удалить только это"
                onClicked: {
                    Calendar.skipOccurrence(ed.e.id, win.editingOcc.start);
                    win.editing = null;
                }
            }
            Button {
                visible: !ed.e.isNew
                variant: "danger"
                text: ed.e.rrule ? "Удалить все" : "Удалить"
                onClicked: {
                    Calendar.remove(ed.e.id);
                    win.editing = null;
                }
            }
            Button {
                variant: "text"
                text: "Отмена"
                onClicked: win.editing = null
            }
        }
    }
}
