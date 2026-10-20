// Окно-хост экрана — одно постоянное полноэкранное окно на монитор, как
// ContentWindow в Caelestia. У каждого окна оболочки свой GL-контекст и
// потоки драйвера, поэтому всё постоянное на экране живёт здесь:
//  • рамка экрана со скруглёнными внутренними углами, как у телефона (со
//    стороны панели задач рамкой служит сама панель; толщина 0 — углы);
//  • панель задач (modules/taskbar/Taskbar.qml);
//  • зоны перетаскивания файлов у краёв (modules/dnd/DndSpring.qml);
//  • все выдвижные панели (widgets/Overlay.qml), OSD и уведомления;
//  • перехват клика на других мониторах, пока открыта панель.
// Пока ничего не открыто, окно ловит мышь только над панелью задач,
// уведомлениями и зонами у краёв и живёт в слое Top — под полноэкранными
// окнами, игре оно не мешает. Место под панель и рамку резервирует
// Hyprland (reserved в правиле монитора, services/HyprConf.qml).
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
import qs.modules.taskbar
import qs.modules.dnd
import Pixel.MD3E

Scope {
    id: root
    required property ShellScreen modelData
    readonly property int w: Settings.data.frameWidth
    readonly property int r: Settings.data.frameRadius
    readonly property color color: Theme.frame
    // Сколько места у каждой стороны занято: панелью или рамкой
    function inset(side) {
        return Bar.inset(modelData.name, side);
    }

    readonly property string name: modelData.name
    // панели на этом экране (открыты или закрываются)
    readonly property var panels: Hosts.shownOn(name)
    readonly property bool active: panels.length > 0
    // панель открыта на другом мониторе — клик здесь её закрывает
    readonly property bool catching: Ui.panel !== "" && Ui.activeScreen !== name
    readonly property var keyPanel: panels.find(p => p.open && p.grabKeyboard) ?? null
    readonly property var floating: Hosts.floatersOn(name)
    readonly property var inputFloater: floating.find(f => f.takesInput) ?? null

    PanelWindow {
        id: win
        screen: root.modelData
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        // весь ввод — пока открыта панель или её надо закрыть кликом;
        // иначе — только панель задач, уведомления и зоны у краёв
        mask: root.active || root.catching ? null : idleRegion
        Region {
            id: idleRegion
            Region {
                item: taskbar.item
            }
            Region {
                item: root.inputFloater
            }
            Region {
                item: dnd.topZone
            }
            Region {
                item: dnd.leftZone
            }
            Region {
                item: dnd.rightZone
            }
        }
        // поверх полноэкранных окон — только пока что-то показано
        WlrLayershell.layer: root.active || root.catching || root.floating.length > 0 || dnd.engaged ? WlrLayer.Overlay : WlrLayer.Top
        WlrLayershell.namespace: "pixel-shell:host"
        WlrLayershell.keyboardFocus: !root.keyPanel ? WlrKeyboardFocus.None : root.keyPanel.exclusiveFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

        // Фокус клавиатуры открытой панели; клик мимо окон оболочки её закрывает
        HyprlandFocusGrab {
            active: root.keyPanel !== null && !root.keyPanel.exclusiveFocus
            windows: [win]
            onCleared: if (root.keyPanel)
                root.keyPanel.dismissed()
        }

        // клик на этом мониторе, когда панель открыта на другом
        MouseArea {
            anchors.fill: parent
            visible: root.catching && !root.active
            acceptedButtons: Qt.AllButtons
            onPressed: Ui.close()
            onWheel: Ui.close()
        }

        Loader {
            id: taskbar
            z: 0.5
            active: Bar.shownOn(root.name)
            sourceComponent: Taskbar {
                modelData: root.modelData
                window: win
            }
        }

        DndSpring {
            id: dnd
            z: 0.6
            screen: root.modelData
            window: win
        }

        // сюда встают панели (Overlay)
        Item {
            id: panelLayer
            anchors.fill: parent
            z: 1
            Component.onCompleted: Hosts.register(root.name, panelLayer)
            Component.onDestruction: Hosts.unregister(root.name, panelLayer)
        }

        Shape {
            visible: Bar.frameOn(root.name)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.color
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                // снаружи — весь экран, включая место под панелью задач: её
                // фон и есть рамка, того же цвета
                PathRectangle {
                    x: 0
                    y: 0
                    width: win.width
                    height: win.height
                }
                // внутри — скруглённое «окно» рабочего стола
                PathRectangle {
                    x: root.inset("left")
                    y: root.inset("top")
                    width: win.width - root.inset("left") - root.inset("right")
                    height: win.height - root.inset("top") - root.inset("bottom")
                    radius: root.r
                }
            }
        }
    }
}
