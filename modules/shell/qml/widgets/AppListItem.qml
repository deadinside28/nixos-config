// Пункт списка со значком приложения из темы иконок (AppIcon) —
// ListItem библиотеки Pixel.MD3E со своим элементом слева.
import QtQuick
import Pixel.MD3E

ListItem {
    id: root
    property string appIcon: ""
    leading: appIcon !== "" ? appIconComponent : null

    Component {
        id: appIconComponent
        AppIcon {
            size: 32
            icon: root.appIcon
        }
    }
}
