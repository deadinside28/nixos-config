// Рамка экрана со скруглёнными внутренними углами — как у экрана
// телефона. Рисуется поверх окон и не ловит мышь; со стороны панели задач
// рамкой служит сама панель. Толщина 0 — остаются только углы.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.common

Scope {
    id: root
    required property ShellScreen modelData
    readonly property int w: Settings.data.frameWidth
    readonly property int r: Settings.data.frameRadius
    readonly property color color: Settings.data.frameColor === "black" ? "black" : Theme.panel
    // Сколько места у каждой стороны занято: панелью или рамкой
    function inset(side) {
        return Bar.inset(modelData.name, side);
    }

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
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "pixel-shell:frame"

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.color
                strokeWidth: -1
                fillRule: ShapePath.OddEvenFill
                // снаружи — весь экран без панели задач
                PathRectangle {
                    x: Bar.edge === "left" && Bar.shownOn(root.modelData.name) ? Bar.size : 0
                    y: Bar.edge === "top" && Bar.shownOn(root.modelData.name) ? Bar.size : 0
                    width: win.width - x - (Bar.edge === "right" && Bar.shownOn(root.modelData.name) ? Bar.size : 0)
                    height: win.height - y - (Bar.edge === "bottom" && Bar.shownOn(root.modelData.name) ? Bar.size : 0)
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
        model: root.w > 0 ? ["top", "bottom", "left", "right"].filter(s => !(Bar.edge === s && Bar.shownOn(root.modelData.name))) : []
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
