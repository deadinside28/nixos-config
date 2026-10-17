// Значок Material Symbols Rounded. Имя — лигатура: "wifi", "settings"…
// fill — заливка (0…1), у M3 активные значки залитые.
import QtQuick
import qs.common

Text {
    property string icon: ""
    property real size: 24
    property real fill: 0
    property int weight: 400

    text: icon
    color: Theme.onSurface
    font.family: Theme.iconFont
    font.pixelSize: size
    font.weight: weight
    font.variableAxes: ({
            "FILL": fill,
            "opsz": Math.min(48, Math.max(20, size)),
            "wght": weight
        })
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill {
        NumberAnimation {
            duration: Theme.anim.fast
        }
    }
}
