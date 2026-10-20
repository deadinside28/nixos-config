// DnD Spring — «пружинящие» воркспейсы для перетаскивания файлов.
//
// Hyprland сам ничего не знает о drag-and-drop между клиентами: это
// протокол wl_data_device, и события получает та поверхность, над которой
// сейчас курсор. Поэтому по краям экрана лежат тонкие (2px) прозрачные
// зоны — элементы окна-хоста экрана (modules/frame/ScreenHost.qml), он
// пропускает в них мышь. Когда над ними тащат файл, они это видят и:
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
// [dndSpring]  →  journalctl --user -u pixel-shell -f | grep dndSpring

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

// Зоны одного экрана; ScreenHost кладёт их в своё окно и держит в маске.
Item {
    id: root
    required property ShellScreen screen
    // окно-хост: от его размера считаются зоны
    required property var window
    readonly property string screenName: screen.name

    // зоны для маски ввода окна-хоста
    readonly property Item topZone: topStrip
    readonly property Item leftZone: edges.count > 0 ? edges.itemAt(0) : null
    readonly property Item rightZone: edges.count > 1 ? edges.itemAt(1) : null
    // файл над зоной — окну-хосту пора наверх, поверх полноэкранных окон
    readonly property bool engaged: topStrip.expanded || (leftZone?.active ?? false) || (rightZone?.active ?? false)

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
        Hyprland.dispatch(`hl.dsp.layout("move ${arg}")`);
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

    // Где кончается панель задач: зоны встают рядом с ней, а не поверх.
    function barAt(side) {
        return Bar.edge === side && Bar.shownOn(screenName) ? Bar.size : 0;
    }
    // Рамка экрана: зона ложится на неё от самого края экрана.
    function frameInset(side) {
        return barAt(side) > 0 ? 0 : Bar.inset(screenName, side);
    }

    // ─── Верх: ряд воркспейсов ───────────────────────────────
    // Рядом с панелью задач, а не поверх неё; на рамку — от самого
    // края экрана. Окно-хост поднимается в слой Overlay (поверх
    // полноэкранных окон) только во время перетаскивания: даже
    // 2 пикселя в нём лишают игру прямого вывода на экран.
    Item {
        id: topStrip

        property bool expanded: false
        property var wsList: []
        readonly property int inset: root.frameInset("top")

        x: root.barAt("left")
        y: root.barAt("top")
        width: root.window.width - x - root.barAt("right")
        height: inset + (expanded ? 88 : 2)

        function expand() {
            collapseTimer.stop();
            if (expanded)
                return;
            // Список берём один раз при раскрытии: если пересобирать
            // его на каждый enter, Repeater пересоздаёт плитки прямо
            // под курсором и таймер пружины сбрасывается.
            wsList = root.workspacesFor(root.screenName);
            root.log(root.screenName, "файл у верхнего края → показываю воркспейсы:", wsList.map(w => w.id).join(","));
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
            border.color: Theme.alpha(Theme.primary, 0.3)

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
                            color: progress.width > chip.width / 2 ? Theme.fgPrimary : Theme.fgSurface
                            font.pixelSize: 16
                            font.weight: Theme.strongWeight
                        }

                        Timer {
                            id: springTimer
                            interval: root.springDelay
                            onTriggered: {
                                root.log("пружина →", "воркспейс", chip.modelData.id);
                                Hypr.focusWorkspace(chip.modelData.id);
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
    Repeater {
        id: edges
        model: ["left", "right"]

        Item {
            id: edge
            required property string modelData
            readonly property string side: modelData
            property bool active: false
            readonly property int inset: root.frameInset(side)

            x: side === "left" ? root.barAt("left") : root.window.width - root.barAt("right") - width
            y: root.barAt("top")
            width: inset + (active ? 56 : 2)
            height: root.window.height - y - root.barAt("bottom")

            property real stepFraction: root.edgeStartFraction

            function activate() {
                edgeCollapse.stop();
                if (edge.active)
                    return;
                edge.active = true;
                edge.stepFraction = root.edgeStartFraction;
                scrollTimer.interval = root.edgeFirstDelay;
                scrollTimer.restart();
                root.log(root.screenName, "файл у края:", edge.side);
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
                    const step = Math.round(root.screen.width * edge.stepFraction);
                    edge.stepFraction = Math.min(1, edge.stepFraction * root.edgeAccel);
                    root.log(root.screenName, "лента →", edge.side, step + "px");
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
                        color: edge.side === "left" ? Theme.alpha(Theme.primary, 0.35) : "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: edge.side === "left" ? "transparent" : Theme.alpha(Theme.primary, 0.35)
                    }
                }
            }

            MIcon {
                id: chevron
                visible: edge.active
                anchors.centerIn: parent
                icon: edge.side === "left" ? "chevron_left" : "chevron_right"
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
