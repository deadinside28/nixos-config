// Окно-хост экрана — одно постоянное полноэкранное окно на монитор, как
// ContentWindow в Caelestia. В нём:
//  • рамка экрана со скруглёнными внутренними углами, как у телефона (со
//    стороны панели задач рамкой служит сама панель; толщина 0 — углы);
//  • все выдвижные панели (widgets/Overlay.qml) — элементы этого окна;
//  • перехват клика на других мониторах, пока открыта панель.
// Пока ничего не открыто, окно не ловит мышь (пустая маска) и живёт в
// слое Top — под полноэкранными окнами, игре оно не мешает.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.common
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
        // ввод — только когда есть что показать или что закрыть
        mask: root.active || root.catching ? null : emptyRegion
        Region {
            id: emptyRegion
        }
        WlrLayershell.layer: root.active || root.catching ? WlrLayer.Overlay : WlrLayer.Top
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
                // снаружи — весь экран, включая место под панелью задач: полоски
                // рамки сдвигают панель на свою толщину, и у её концов иначе
                // просвечивали бы обои. Цвет у панели тот же, стыка не видно.
                PathRectangle {
                    x: 0
                    y: 0
                    width: win.width
                    height: win.height
                }
                // сама панель задач (сдвинута полосками рамки на их толщину)
                PathRectangle {
                    readonly property bool has: Bar.shownOn(root.modelData.name)
                    readonly property int t: root.w
                    x: !has ? 0 : Bar.edge === "right" ? win.width - Bar.size : Bar.vertical ? 0 : t
                    y: !has ? 0 : Bar.edge === "bottom" ? win.height - Bar.size : Bar.vertical ? t : 0
                    width: !has ? 0 : Bar.vertical ? Bar.size : win.width - 2 * t
                    height: !has ? 0 : Bar.vertical ? win.height - 2 * t : Bar.size
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

    // Окна не заходят под рамку: невидимые полоски с exclusiveZone
    Variants {
        model: Bar.frameOn(root.name) && root.w > 0 ? ["top", "bottom", "left", "right"].filter(s => !(Bar.edge === s && Bar.shownOn(root.modelData.name))) : []
        PanelWindow {
            required property string modelData
            screen: root.modelData
            anchors.top: modelData !== "bottom"
            anchors.bottom: modelData !== "top"
            anchors.left: modelData !== "right"
            anchors.right: modelData !== "left"
            implicitWidth: root.w
            implicitHeight: root.w
            exclusiveZone: root.w
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "pixel-shell:frame-zone"
        }
    }
}
