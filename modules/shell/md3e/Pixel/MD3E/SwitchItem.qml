// Пункт с переключателем: клик по всей строке переключает.
import QtQuick

ListItem {
    id: root
    property bool checked: false
    signal toggled(bool value)

    onClicked: if (!disabled)
        toggled(!checked)

    MSwitch {
        checked: root.checked
        disabled: root.disabled
        onToggled: v => root.toggled(v)
    }
}
