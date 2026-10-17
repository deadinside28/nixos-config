import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Экран"

    // Мониторы из `hyprctl monitors all -j`
    property var monitors: []
    property string selectedName: ""
    readonly property var sel: monitors.find(m => m.name === selectedName) ?? monitors[0] ?? null

    // Черновик изменений для выбранных мониторов: { name: {mode, position, scale, vrr, disabled} }
    property var draft: ({})
    property var backup: null
    property int countdown: 0

    function refresh() {
        query.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.monitors = JSON.parse(text);
                    if (!page.selectedName && page.monitors.length)
                        page.selectedName = page.monitors[0].name;
                } catch (e) {
                    page.monitors = [];
                }
            }
        }
    }

    function cfg(m) {
        const saved = Settings.data.monitors[m.name] ?? {};
        const d = draft[m.name] ?? {};
        const cur = {
            mode: `${m.width}x${m.height}@${(m.refreshRate ?? 60).toFixed(2)}`,
            position: `${m.x}x${m.y}`,
            scale: m.scale,
            vrr: m.vrr ? 1 : 0,
            disabled: m.disabled ?? false
        };
        return Object.assign(cur, saved, d);
    }
    function setDraft(name, key, value) {
        const d = Object.assign({}, draft);
        d[name] = Object.assign({}, d[name] ?? {}, {
            [key]: value
        });
        draft = d;
    }
    readonly property bool dirty: Object.keys(draft).length > 0

    function apply() {
        backup = JSON.parse(JSON.stringify(Settings.data.monitors));
        const m = Object.assign({}, Settings.data.monitors);
        for (const mon of monitors) {
            if (draft[mon.name])
                m[mon.name] = cfg(mon);
        }
        Settings.data.monitors = m;
        draft = {};
        countdown = 15;
        refreshLater.restart();
    }
    function keep() {
        backup = null;
        countdown = 0;
    }
    function revert() {
        if (backup !== null)
            Settings.data.monitors = backup;
        backup = null;
        countdown = 0;
        refreshLater.restart();
    }

    Timer {
        id: refreshLater
        interval: 800
        onTriggered: page.refresh()
    }
    Timer {
        running: page.countdown > 0
        interval: 1000
        repeat: true
        onTriggered: {
            page.countdown--;
            if (page.countdown === 0)
                page.revert();
        }
    }

    // --- Подтверждение после применения ---------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: page.countdown > 0
        implicitHeight: 80
        radius: Theme.radius.xl
        color: Theme.tertiaryContainer
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 16
            spacing: 12
            MIcon {
                icon: "timer"
                color: Theme.fgTertiaryContainer
            }
            MText {
                Layout.fillWidth: true
                text: "Оставить эти параметры экрана? Возврат через " + page.countdown + " с"
                color: Theme.fgTertiaryContainer
                wrapMode: Text.WordWrap
            }
            Button {
                variant: "text"
                text: "Вернуть"
                onClicked: page.revert()
            }
            Button {
                text: "Оставить"
                onClicked: page.keep()
            }
        }
    }

    // --- Схема расположения -----------------------------------------------
    Rectangle {
        id: map
        Layout.fillWidth: true
        implicitHeight: 240
        radius: Theme.radius.xl
        color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
        visible: page.monitors.length > 0

        readonly property var boxes: page.monitors.filter(m => !page.cfg(m).disabled).map(m => {
            const c = page.cfg(m);
            const [w, h] = c.mode.split("@")[0].split("x").map(Number);
            const [x, y] = c.position === "auto" ? [m.x, m.y] : c.position.split("x").map(Number);
            const s = Number(c.scale) || 1;
            return {
                m,
                x,
                y,
                w: w / s,
                h: h / s
            };
        })
        readonly property real minX: Math.min(...boxes.map(b => b.x))
        readonly property real minY: Math.min(...boxes.map(b => b.y))
        readonly property real spanW: Math.max(...boxes.map(b => b.x + b.w)) - minX
        readonly property real spanH: Math.max(...boxes.map(b => b.y + b.h)) - minY
        readonly property real k: Math.min((width - 80) / Math.max(1, spanW), (height - 60) / Math.max(1, spanH))
        readonly property real ox: (width - spanW * k) / 2
        readonly property real oy: (height - spanH * k) / 2

        Repeater {
            model: map.boxes
            Rectangle {
                id: box
                required property var modelData
                readonly property bool isSel: modelData.m.name === page.selectedName
                x: map.ox + (modelData.x - map.minX) * map.k
                y: map.oy + (modelData.y - map.minY) * map.k
                width: modelData.w * map.k
                height: modelData.h * map.k
                radius: Theme.radius.m
                color: isSel ? Theme.primaryContainer : Theme.surfaceContainerHighest
                border.width: isSel ? 2 : 0
                border.color: Theme.primary

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    MText {
                        Layout.alignment: Qt.AlignHCenter
                        text: box.modelData.m.model || box.modelData.m.name
                        weight: Theme.strongWeight
                        color: box.isSel ? Theme.fgPrimaryContainer : Theme.fgSurface
                    }
                    MText {
                        Layout.alignment: Qt.AlignHCenter
                        text: box.modelData.m.name
                        size: Theme.type.bodyS
                        color: box.isSel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                    }
                }

                // Перетаскивание: при отпускании монитор прилипает к краю соседа.
                DragHandler {
                    id: dragger
                    onActiveChanged: {
                        page.selectedName = box.modelData.m.name;
                        if (active)
                            return;
                        const me = box.modelData;
                        const others = map.boxes.filter(b => b.m.name !== me.m.name);
                        let nx = Math.round(map.minX + (box.x - map.ox) / map.k);
                        let ny = Math.round(map.minY + (box.y - map.oy) / map.k);
                        // Прилипаем к ближайшей стороне соседа, а вдоль стороны
                        // монитор можно сдвигать свободно (по центру, со смещением);
                        // рядом с краем или центром — мягко выравниваем.
                        const align = (v, lo, hi, size, osize) => {
                            v = Math.max(lo - size + 1, Math.min(hi - 1, v));
                            const snapD = 48;
                            for (const t of [lo, lo + (osize - size) / 2, lo + osize - size])
                                if (Math.abs(v - t) < snapD)
                                    return t;
                            return v;
                        };
                        let best = null;
                        for (const o of others) {
                            const cands = [
                                [o.x + o.w, align(ny, o.y, o.y + o.h, me.h, o.h)],
                                [o.x - me.w, align(ny, o.y, o.y + o.h, me.h, o.h)],
                                [align(nx, o.x, o.x + o.w, me.w, o.w), o.y - me.h],
                                [align(nx, o.x, o.x + o.w, me.w, o.w), o.y + o.h]
                            ];
                            for (const [cx, cy] of cands) {
                                const overlaps = others.some(q => cx < q.x + q.w && cx + me.w > q.x && cy < q.y + q.h && cy + me.h > q.y);
                                if (overlaps)
                                    continue;
                                const d = Math.hypot(cx - nx, cy - ny);
                                if (!best || d < best.d)
                                    best = {
                                        d,
                                        cx,
                                        cy
                                    };
                            }
                        }
                        if (best) {
                            nx = best.cx;
                            ny = best.cy;
                        }
                        // Hyprland хочет, чтобы левый верхний угол раскладки был в 0x0
                        const all = [...others.map(o => [o.x, o.y]), [nx, ny]];
                        const sx = Math.min(...all.map(p => p[0])), sy = Math.min(...all.map(p => p[1]));
                        if (sx !== 0 || sy !== 0)
                            for (const o of others)
                                page.setDraft(o.m.name, "position", `${Math.round(o.x - sx)}x${Math.round(o.y - sy)}`);
                        nx -= sx;
                        ny -= sy;
                        page.setDraft(me.m.name, "position", `${Math.round(nx)}x${Math.round(ny)}`);
                    }
                }
                TapHandler {
                    onTapped: page.selectedName = box.modelData.m.name
                }
            }
        }

        MText {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 14
            text: "Перетащи монитор, чтобы изменить расположение"
            size: Theme.type.bodyS
            color: Theme.fgSurfaceVariant
        }
    }

    // Выбор монитора
    SegmentedButtons {
        Layout.fillWidth: true
        visible: page.monitors.length > 1
        options: page.monitors.map(m => ({
                    value: m.name,
                    label: m.name,
                    icon: "desktop_windows"
                }))
        current: page.selectedName
        onSelected: v => page.selectedName = v
    }

    Group {
        title: page.sel ? (page.sel.make + " " + page.sel.model).trim() || page.sel.name : ""
        visible: page.sel !== null

        readonly property var c: page.sel ? page.cfg(page.sel) : ({})
        readonly property var modes: {
            if (!page.sel)
                return [];
            const list = (page.sel.availableModes ?? []).map(s => {
                const [res, hz] = s.replace("Hz", "").split("@");
                return {
                    res,
                    hz: parseFloat(hz)
                };
            });
            return list;
        }
        readonly property var resolutions: [...new Set(modes.map(m => m.res))].sort((a, b) => {
            const [aw, ah] = a.split("x").map(Number);
            const [bw, bh] = b.split("x").map(Number);
            return bw * bh - aw * ah;
        })
        readonly property string curRes: (c.mode ?? "").split("@")[0]
        readonly property real curHz: parseFloat((c.mode ?? "").split("@")[1] ?? 60)
        readonly property var rates: modes.filter(m => m.res === curRes).map(m => m.hz).sort((a, b) => b - a)

        id: grp

        SwitchItem {
            icon: "power_settings_new"
            title: "Включён"
            subtitle: "Выключенный монитор не используется в сессии"
            checked: !(grp.c.disabled ?? false)
            disabled: page.monitors.filter(m => !page.cfg(m).disabled).length <= 1 && !(grp.c.disabled ?? false)
            onToggled: v => page.setDraft(page.sel.name, "disabled", !v)
        }
        ChoiceItem {
            icon: "aspect_ratio"
            title: "Разрешение"
            options: grp.resolutions.map(r => ({
                        value: r,
                        label: r.replace("x", " × ")
                    }))
            current: grp.curRes
            onSelected: v => {
                const rates = grp.modes.filter(m => m.res === v).map(m => m.hz).sort((a, b) => b - a);
                page.setDraft(page.sel.name, "mode", `${v}@${(rates[0] ?? 60).toFixed(2)}`);
            }
        }
        ChoiceItem {
            icon: "speed"
            title: "Частота обновления"
            options: grp.rates.map(hz => ({
                        value: hz.toFixed(2),
                        label: (Math.round(hz * 100) / 100) + " Гц"
                    }))
            current: grp.curHz.toFixed(2)
            onSelected: v => page.setDraft(page.sel.name, "mode", `${grp.curRes}@${v}`)
        }
        ChoiceItem {
            icon: "zoom_in"
            title: "Масштаб"
            options: [1, 1.25, 1.333333, 1.5, 1.6, 1.75, 2].map(s => ({
                        value: s,
                        label: Math.round(s * 100) + "%"
                    }))
            current: Number(grp.c.scale)
            onSelected: v => page.setDraft(page.sel.name, "scale", v)
        }
        ChoiceItem {
            icon: "animation"
            title: "Адаптивная частота (VRR / FreeSync)"
            options: [
                {
                    value: 0,
                    label: "Выключена"
                },
                {
                    value: 1,
                    label: "Всегда"
                },
                {
                    value: 2,
                    label: "Только в полноэкранных приложениях"
                }
            ]
            current: Number(grp.c.vrr ?? 0)
            onSelected: v => page.setDraft(page.sel.name, "vrr", v)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: page.dirty
        Item {
            Layout.fillWidth: true
        }
        Button {
            variant: "text"
            text: "Отмена"
            onClicked: page.draft = {}
        }
        Button {
            icon: "check"
            text: "Применить"
            onClicked: page.apply()
        }
    }

    Group {
        title: "Цвет"
        SwitchItem {
            icon: "nightlight"
            title: "Ночной режим"
            subtitle: "Тёплые оттенки снижают нагрузку на глаза вечером"
            checked: Settings.data.nightLight
            onToggled: v => Settings.data.nightLight = v
        }
        SliderItem {
            icon: "thermostat"
            title: "Температура"
            valueText: Settings.data.nightTemp + " K"
            from: 2500
            to: 6000
            stepSize: 100
            value: Settings.data.nightTemp
            onMoved: v => Settings.data.nightTemp = Math.round(v)
        }
    }

    Group {
        title: "Яркость"
        // У каждого монитора своя: внешние — по DDC/CI, ноутбук — подсветка
        Repeater {
            model: ScriptModel {
                values: Brightness.names
            }
            SliderItem {
                required property string modelData
                readonly property real level: Brightness.valueFor(modelData)
                icon: "brightness_6"
                title: Brightness.label(modelData)
                valueText: Math.round(level * 100) + "%"
                value: level
                onMoved: v => Brightness.set(v, modelData)
            }
        }
        ListItem {
            visible: !Brightness.available
            icon: "brightness_low"
            title: Brightness.detecting ? "Ищу мониторы с регулировкой яркости…" : "Мониторы не отвечают по DDC/CI"
            subtitle: Brightness.detecting ? "" : "Включи DDC/CI в меню самого монитора. Нужна пересборка с hardware.i2c и перезаход в сессию"
            clickable: !Brightness.detecting
            onClicked: Brightness.refresh()
        }
    }

    Group {
        title: "Запись экрана"
        ListItem {
            icon: "speed"
            title: "Частота кадров"
            clickable: false
            SegmentedButtons {
                options: [30, 60, 120, 144].map(f => ({
                            value: f,
                            label: f + ""
                        }))
                current: Settings.data.recFps
                onSelected: v => Settings.data.recFps = v
            }
        }
        ChoiceItem {
            icon: "movie"
            title: "Кодек"
            options: [
                {
                    value: "av1",
                    label: "AV1 — меньше файл, нужна новая видеокарта"
                },
                {
                    value: "hevc",
                    label: "HEVC (H.265)"
                },
                {
                    value: "h264",
                    label: "H.264 — открывается везде"
                }
            ]
            current: Settings.data.recCodec
            onSelected: v => Settings.data.recCodec = v
        }
        ChoiceItem {
            icon: "high_quality"
            title: "Качество"
            options: [
                {
                    value: "medium",
                    label: "Среднее"
                },
                {
                    value: "high",
                    label: "Высокое"
                },
                {
                    value: "very_high",
                    label: "Очень высокое"
                },
                {
                    value: "ultra",
                    label: "Максимальное"
                }
            ]
            current: Settings.data.recQuality
            onSelected: v => Settings.data.recQuality = v
        }
        ListItem {
            icon: "video_file"
            title: "Формат файла"
            clickable: false
            SegmentedButtons {
                options: [
                    {
                        value: "mp4",
                        label: "MP4"
                    },
                    {
                        value: "mkv",
                        label: "MKV"
                    }
                ]
                current: Settings.data.recContainer
                onSelected: v => Settings.data.recContainer = v
            }
        }
        SwitchItem {
            icon: "arrow_selector_tool"
            title: "Показывать курсор"
            checked: Settings.data.recCursor
            onToggled: v => Settings.data.recCursor = v
        }
        ListItem {
            icon: "folder"
            title: "Папка для записей"
            clickable: false
            TextField {
                implicitWidth: 280
                implicitHeight: 44
                id: recDirField
                text: Settings.data.recDir
                Connections {
                    target: recDirField.input
                    function onEditingFinished() {
                        Settings.data.recDir = recDirField.text.replace(/\/+$/, "") || Settings.home + "/Videos";
                    }
                }
            }
        }
    }
}
