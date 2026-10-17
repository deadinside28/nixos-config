import QtQuick
import qs.common

Text {
    property int size: Theme.type.bodyM
    property int weight: Theme.fontWeight

    color: Theme.fgSurface
    font.family: Theme.font
    font.pixelSize: size
    font.weight: weight
    elide: Text.ElideRight
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
