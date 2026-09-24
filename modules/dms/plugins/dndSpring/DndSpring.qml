// DnD Spring — «пружинящие» воркспейсы для перетаскивания файлов.
//
// Hyprland сам ничего не знает о drag-and-drop между клиентами: это
// протокол wl_data_device, и события получает та поверхность, над которой
// сейчас курсор. Поэтому по краям экрана лежат тонкие (2px) прозрачные
// layer-поверхности. Когда над ними тащат файл, они это видят и:
//   - верхняя полоска разворачивается в ряд воркспейсов этого монитора;
//     задержишь файл над воркспейсом ~полсекунды — он откроется, а файл
//     останется «в руке»;
//   - левая и правая полоски прокручивают ленту scrolling-layout, пока
//     файл держат у края.
//
// Сам файл мы никогда не принимаем: при отпускании над полоской drop
// отклоняется, так что источник (Nemo и т.п.) ничего не копирует и не
// удаляет.
//
// Это пробная версия: всё, что происходит, пишется в журнал с префиксом
// [dndSpring]  →  journalctl --user -u dms -f | grep dndSpring

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var pluginService: null
    property string pluginId: "dndSpring"

    // Задержка «пружины» над воркспейсом и шаг прокрутки ленты, мс.
    readonly property int springDelay: 350
    // Сколько пикселей курсор может «дрожать» над плиткой, не сбрасывая
    // пружину. Больше — значит, ведёшь мимо, а не целишься.
    readonly property int springSlop: 6
    readonly property int edgeFirstDelay: 180
    readonly property int edgeRepeat: 300
    // Разгон ленты: первый шаг — доля ширины экрана, дальше каждый шаг
    // в edgeAccel раз больше, но не больше целого экрана.
    readonly property real edgeStartFraction: 0.33
    readonly property real edgeAccel: 1.35

    // Файлы, ссылки, текст — всё, что обычно таскают между окнами.
    readonly property var dragKeys: ["text/uri-list", "text/plain", "application/x-qabstractitemmodeldatalist"]

    function log(...args) {
        console.info("[dndSpring]", ...args);
    }

    // Прокрутка ленты scrolling-layout на px пикселей.
    // Не через смену фокуса и не через «move +col»: оба варианта в
    // Hyprland переносят курсор в центр окна (warpTo), и файл «выпрыгивал»
    // из руки в середину экрана — так было во второй пробе. Сдвиг на
    // пиксели двигает только камеру, курсор остаётся на месте.
    // «move +N» двигает саму ленту вправо, то есть камеру влево.
    function scrollTape(dir, px) {
        const arg = (dir === "left" ? "+" : "-") + px;
        if (HyprlandService.luaConfigActive)
            Hyprland.dispatch(`hl.dsp.layout("move ${arg}")`);
        else
            Hyprland.dispatch(`layoutmsg move ${arg}`);
    }

    function workspacesFor(screenName) {
        const all = Hyprland.workspaces?.values ?? [];
        return all.filter(ws => ws.id > 0 && ws.monitor?.name === screenName).sort((a, b) => a.id - b.id);
    }

    // Отпустили над нашей полоской — вежливо отказываемся от файла.
    function refuse(drop) {
        root.log("drop над полоской — отклоняю, источник ничего не сделает");
        drop.accepted = false;
    }

    Component.onCompleted: log("загружен, экранов:", Quickshell.screens.length, "lua:", HyprlandService.luaConfigActive)

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData
            readonly property string screenName: modelData.name

            // Рамка DMS (Настройки → «Рамка») рисуется поверх краёв экрана,
            // но ввод пропускает насквозь, и отдаёт свою толщину под
            // exclusive zone. С ExclusionMode.Normal наши полоски вставали
            // ВНУТРЬ рамки, и курсор на самой рамке их не задевал.
            // Поэтому там, где рамка, полоска ложится на неё целиком
            // (рамка всё равно не кликабельна), а там, где панель DMS, —
            // по-прежнему рядом с панелью, чтобы не отбирать у неё клики.
            readonly property var barEdges: {
                SettingsData.barConfigs;
                return SettingsData.getActiveBarEdgesForScreen(modelData);
            }
            readonly property bool frameOn: {
                SettingsData.frameEnabled;
                return CompositorService.frameWindowVisibleForScreen(modelData);
            }

            function frameInset(side) {
                if (!frameOn || barEdges.includes(side))
                    return 0;
                return Math.ceil(SettingsData.frameThickness);
            }

            // ─── Верх: ряд воркспейсов ───────────────────────────────
            PanelWindow {
                id: topStrip
                screen: perScreen.modelData

                property bool expanded: false
                property var wsList: []
                readonly property int inset: perScreen.frameInset("top")

                anchors {
                    top: true
                    left: true
                    right: true
                }
                // Normal — встаём рядом с панелью DMS, а не поверх неё;
                // Ignore — ложимся на рамку от самого края экрана.
                exclusionMode: inset > 0 ? ExclusionMode.Ignore : ExclusionMode.Normal
                exclusiveZone: 0
                implicitHeight: inset + (expanded ? 88 : 2)
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "dms:dnd-spring"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                function expand() {
                    collapseTimer.stop();
                    if (expanded)
                        return;
                    // Список берём один раз при раскрытии: если пересобирать
                    // его на каждый enter, Repeater пересоздаёт плитки прямо
                    // под курсором и таймер пружины сбрасывается.
                    wsList = root.workspacesFor(perScreen.screenName);
                    root.log(perScreen.screenName, "файл у верхнего края → показываю воркспейсы:", wsList.map(w => w.id).join(","));
                    expanded = true;
                }

                Timer {
                    id: collapseTimer
                    interval: 300
                    onTriggered: topStrip.expanded = false
                }

                DropArea {
                    anchors.fill: parent
                    keys: root.dragKeys
                    onEntered: drag => {
                        drag.accept(Qt.CopyAction);
                        topStrip.expand();
                    }
                    onExited: collapseTimer.restart()
                    onDropped: drop => {
                        root.refuse(drop);
                        topStrip.expanded = false;
                    }
                }

                Rectangle {
                    visible: topStrip.expanded
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: topStrip.inset + 12
                    width: row.implicitWidth + 16
                    height: 64
                    radius: 20
                    color: Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.primary, 0.3)

                    Row {
                        id: row
                        anchors.centerIn: parent
                        spacing: 8

                        Repeater {
                            model: topStrip.wsList

                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool current: modelData.active
                                property bool hovered: false

                                width: 72
                                height: 48
                                radius: 14
                                clip: true
                                color: current ? Theme.primaryContainer : Theme.surfaceContainer
                                border.width: current ? 2 : 0
                                border.color: Theme.primary

                                // Заполнение слева направо — сколько осталось
                                // держать файл, чтобы воркспейс открылся.
                                Rectangle {
                                    id: progress
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 0
                                    color: Theme.primary
                                    radius: parent.radius
                                }

                                NumberAnimation {
                                    id: fill
                                    target: progress
                                    property: "width"
                                    from: 0
                                    to: chip.width
                                    duration: root.springDelay
                                    easing.type: Easing.InOutQuad
                                }

                                onCurrentChanged: {
                                    if (current)
                                        disarm();
                                }

                                property point anchorPos: Qt.point(0, 0)

                                // Пружина срабатывает, только если файл
                                // задержали над плиткой. Если просто ведёшь
                                // вдоль ряда, отсчёт каждый раз начинается
                                // заново — иначе воркспейсы перещёлкиваются
                                // один за другим, как в игровом автомате.
                                function arm(x, y) {
                                    anchorPos = Qt.point(x, y);
                                    if (current)
                                        return;
                                    springTimer.restart();
                                    fill.restart();
                                }

                                function disarm() {
                                    springTimer.stop();
                                    fill.stop();
                                    progress.width = 0;
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        const n = chip.modelData.name;
                                        return (n && n !== String(chip.modelData.id)) ? n : chip.modelData.id;
                                    }
                                    color: progress.width > chip.width / 2 ? Theme.onPrimary : Theme.surfaceText
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                }

                                Timer {
                                    id: springTimer
                                    interval: root.springDelay
                                    onTriggered: {
                                        root.log("пружина →", "воркспейс", chip.modelData.id);
                                        HyprlandService.focusWorkspace(chip.modelData.id);
                                    }
                                }

                                DropArea {
                                    anchors.fill: parent
                                    keys: root.dragKeys
                                    onEntered: drag => {
                                        drag.accept(Qt.CopyAction);
                                        topStrip.expand();
                                        chip.hovered = true;
                                        chip.arm(drag.x, drag.y);
                                    }
                                    onPositionChanged: drag => {
                                        const dx = drag.x - chip.anchorPos.x;
                                        const dy = drag.y - chip.anchorPos.y;
                                        if (Math.hypot(dx, dy) > root.springSlop)
                                            chip.arm(drag.x, drag.y);
                                    }
                                    onExited: {
                                        chip.hovered = false;
                                        chip.disarm();
                                    }
                                    onDropped: drop => {
                                        root.refuse(drop);
                                        chip.hovered = false;
                                        chip.disarm();
                                        topStrip.expanded = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─── Бока: прокрутка ленты ───────────────────────────────
            // В покое полоска 2px. Как только над ней появляется файл, она
            // раздувается в зону ~56px: иначе курсор, который у края всё
            // время чуть гуляет, выскакивает из 2px раньше, чем успеет
            // сработать прокрутка (так и было в первой пробе).
            Variants {
                model: ["left", "right"]

                PanelWindow {
                    id: edge
                    required property string modelData
                    readonly property string side: modelData
                    property bool active: false
                    readonly property int inset: perScreen.frameInset(side)

                    screen: perScreen.modelData
                    anchors {
                        top: true
                        bottom: true
                        left: side === "left"
                        right: side === "right"
                    }
                    exclusionMode: inset > 0 ? ExclusionMode.Ignore : ExclusionMode.Normal
                    exclusiveZone: 0
                    implicitWidth: inset + (active ? 56 : 2)
                    color: "transparent"

                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "dms:dnd-spring"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                    property real stepFraction: root.edgeStartFraction

                    function activate() {
                        edgeCollapse.stop();
                        if (edge.active)
                            return;
                        edge.active = true;
                        edge.stepFraction = root.edgeStartFraction;
                        scrollTimer.interval = root.edgeFirstDelay;
                        scrollTimer.restart();
                        root.log(perScreen.screenName, "файл у края:", edge.side);
                    }

                    function deactivate() {
                        edge.active = false;
                        scrollTimer.stop();
                        edgeCollapse.stop();
                    }

                    // Небольшая пауза перед сворачиванием: при изменении
                    // размера поверхности Qt может прислать лишний exit/enter.
                    Timer {
                        id: edgeCollapse
                        interval: 200
                        onTriggered: edge.deactivate()
                    }

                    Timer {
                        id: scrollTimer
                        interval: root.edgeFirstDelay
                        repeat: true
                        onTriggered: {
                            interval = root.edgeRepeat;
                            // Чем дольше держишь файл у края, тем крупнее шаг.
                            const step = Math.round(perScreen.modelData.width * edge.stepFraction);
                            edge.stepFraction = Math.min(1, edge.stepFraction * root.edgeAccel);
                            root.log(perScreen.screenName, "лента →", edge.side, step + "px");
                            root.scrollTape(edge.side, step);
                            pulse.restart();
                        }
                    }

                    // Подсветка: мягкий градиент от края и шеврон.
                    Rectangle {
                        anchors.fill: parent
                        visible: edge.active
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0
                                color: edge.side === "left" ? Theme.withAlpha(Theme.primary, 0.35) : "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: edge.side === "left" ? "transparent" : Theme.withAlpha(Theme.primary, 0.35)
                            }
                        }
                    }

                    DankIcon {
                        id: chevron
                        visible: edge.active
                        anchors.centerIn: parent
                        name: edge.side === "left" ? "chevron_left" : "chevron_right"
                        size: 32
                        color: Theme.primary

                        transform: Translate {
                            id: nudge
                        }

                        SequentialAnimation {
                            id: pulse
                            NumberAnimation {
                                target: nudge
                                property: "x"
                                to: edge.side === "left" ? -8 : 8
                                duration: 120
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: nudge
                                property: "x"
                                to: 0
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: root.dragKeys
                        onEntered: drag => {
                            drag.accept(Qt.CopyAction);
                            edge.activate();
                        }
                        onExited: edgeCollapse.restart()
                        onDropped: drop => {
                            root.refuse(drop);
                            edge.deactivate();
                        }
                    }
                }
            }
        }
    }
}
