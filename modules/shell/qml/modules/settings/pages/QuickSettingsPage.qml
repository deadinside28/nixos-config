import QtQuick
import QtQuick.Layouts
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

SettingsPage {
    id: page
    title: "Быстрые настройки"
    description: "Шторка, которая открывается по клику на часы. Включённые плитки идут в шторке в этом порядке, по две в ряд."

    readonly property var enabled: Settings.data.qsTiles.filter(id => QsTiles.byId(id))
    readonly property var disabled: QsTiles.all.filter(t => !Settings.data.qsTiles.includes(t.id))

    function move(i, d) {
        const a = [...enabled];
        const j = i + d;
        if (j < 0 || j >= a.length)
            return;
        [a[i], a[j]] = [a[j], a[i]];
        Settings.data.qsTiles = a;
    }

    Group {
        title: "В шторке"
        Repeater {
            model: page.enabled
            ListItem {
                id: row
                required property string modelData
                required property int index
                readonly property var t: QsTiles.byId(modelData)
                icon: t.icon()
                iconTinted: true
                iconBg: Theme.primaryContainer
                iconFg: Theme.fgPrimaryContainer
                title: t.label
                subtitle: t.sub()
                clickable: false

                IconButton {
                    icon: "arrow_upward"
                    visible: row.index > 0
                    onClicked: page.move(row.index, -1)
                }
                IconButton {
                    icon: "arrow_downward"
                    visible: row.index < page.enabled.length - 1
                    onClicked: page.move(row.index, 1)
                }
                IconButton {
                    icon: "remove_circle"
                    onClicked: Settings.data.qsTiles = page.enabled.filter(id => id !== row.modelData)
                }
            }
        }
    }

    Group {
        title: "Можно добавить"
        visible: page.disabled.length > 0
        Repeater {
            model: page.disabled
            ListItem {
                id: add
                required property var modelData
                icon: modelData.icon()
                iconTinted: true
                title: modelData.label
                subtitle: modelData.sub()
                onClicked: Settings.data.qsTiles = [...page.enabled, modelData.id]
                IconButton {
                    icon: "add_circle"
                    onClicked: Settings.data.qsTiles = [...page.enabled, add.modelData.id]
                }
            }
        }
    }

    Group {
        title: "Ещё в шторке"
        SwitchItem {
            icon: "music_note"
            title: "Плеер"
            subtitle: "Что сейчас играет и управление воспроизведением"
            checked: Settings.data.qsShowMedia
            onToggled: v => Settings.data.qsShowMedia = v
        }
        SwitchItem {
            icon: "brightness_6"
            title: "Яркость"
            subtitle: Brightness.available ? "Слайдер под громкостью — для монитора, на котором открыта шторка" : "Мониторы не отвечают по DDC/CI — слайдер скрыт"
            checked: Settings.data.qsShowBrightness
            disabled: !Brightness.available
            onToggled: v => Settings.data.qsShowBrightness = v
        }
        ListItem {
            icon: "restart_alt"
            title: "Вернуть как было"
            subtitle: "Стандартный набор плиток"
            onClicked: Settings.data.qsTiles = ["internet", "bluetooth", "dnd", "night", "dark", "mic", "caffeine", "record", "screenshot", "clipboard"]
        }
    }
}
