import QtQuick
import qs.common

Text {
    property int size: Theme.type.bodyM
    property int weight: Theme.fontWeight

    color: Theme.fgSurface
    font.family: Theme.font
    font.pixelSize: size
    font.weight: weight
    // Google Sans вариативный (оси wght и opsz). GTK/Pango ставит оптический
    // размер по кеглю — мелкий текст получается плотнее; Qt берёт значение по
    // умолчанию «для заголовков», и текст оболочки выглядел тоньше, чем в
    // приложениях. Задаём оси так же, как Pango (opsz — размер в пунктах).
    font.variableAxes: ({
            "wght": weight,
            "opsz": Math.round(size * 0.75 * 10) / 10
        })
    elide: Text.ElideRight
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
