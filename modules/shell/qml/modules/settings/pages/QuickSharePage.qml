import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

// «Quick Share» — как раздел на Pixel: имя, видимость, свои устройства.
// Служба — modules/shell/quickshare, связь — services/QuickShare.qml.
SettingsPage {
    id: page
    title: "Quick Share"
    description: "Обмен файлами, ссылками и текстом с телефонами Android рядом: в одной сети Wi‑Fi, по Bluetooth или напрямую через Wi‑Fi Direct."

    Group {
        visible: !QuickShare.enabled
        ListItem {
            icon: "share_off"
            title: "Quick Share выключен"
            subtitle: "Включи в «Система → Службы → Quick Share с Android» и нажми «Применить»"
            chevron: true
            onClicked: Ui.goSettings("system")
        }
    }
    Group {
        visible: QuickShare.enabled && !QuickShare.available
        ListItem {
            icon: "error"
            title: "Служба не отвечает"
            subtitle: "Перезапусти её или посмотри журнал: journalctl --user -u pixel-quickshare"
            clickable: false
            Button {
                variant: "tonal"
                text: "Перезапустить"
                onClicked: Quickshell.execDetached(["systemctl", "--user", "restart", "pixel-quickshare.service"])
            }
        }
    }

    Group {
        visible: QuickShare.available
        title: "Это устройство"
        ChoiceItem {
            icon: QuickShare.visibility === "hidden" ? "visibility_off" : "visibility"
            title: "Кто может отправлять"
            options: [
                {
                    value: "hidden",
                    label: "Никто"
                },
                {
                    value: "temporary",
                    label: "Все — на 1 минуту"
                },
                {
                    value: "visible",
                    label: "Все"
                }
            ]
            current: QuickShare.visibility
            onSelected: v => QuickShare.setVisibility(v)
        }
        ListItem {
            icon: "badge"
            title: "Имя устройства"
            subtitle: "Так компьютер видят телефоны. После смены служба перезапустится"
            clickable: false
        }
        RowLayout {
            readonly property bool groupItem: true
            property bool first: false
            property bool last: true
            Layout.fillWidth: true
            Layout.leftMargin: 20
            Layout.rightMargin: 12
            spacing: 8
            TextField {
                id: nameField
                Layout.fillWidth: true
                icon: "computer"
                placeholder: "Имя компьютера"
                text: QuickShare.name
                onAccepted: if (text.trim() && text.trim() !== QuickShare.name)
                    QuickShare.rename(text.trim())
            }
            Button {
                text: "Сохранить"
                disabled: nameField.text.trim() === "" || nameField.text.trim() === QuickShare.name
                onClicked: QuickShare.rename(nameField.text.trim())
            }
        }
    }

    Group {
        visible: QuickShare.available
        title: "Мои устройства"
        ListItem {
            visible: QuickShare.trusted.length === 0
            icon: "devices"
            title: "Пока нет"
            subtitle: "Нажми «Принимать всегда» в уведомлении о входящей передаче — дальше файлы с этого телефона будут сохраняться без вопроса"
            clickable: false
        }
        Repeater {
            model: QuickShare.trusted
            ListItem {
                required property string modelData
                icon: "smartphone"
                title: modelData
                subtitle: "Передачи принимаются без вопроса"
                clickable: false
                IconButton {
                    icon: "delete"
                    tooltip: "Больше не доверять"
                    onClicked: QuickShare.trust(modelData, false)
                }
            }
        }
    }
    MText {
        visible: QuickShare.available
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        wrapMode: Text.WordWrap
        size: Theme.type.bodyS
        color: Theme.fgSurfaceVariant
        text: "Доверие держится на имени телефона: в режиме «Все» его видят все рядом, и кто-то может назваться так же. Поэтому доверенным файлы принимаются без вопроса, но уведомление о полученном приходит всегда."
    }

    // Аккаунт Google: честно о том, почему входа нет
    Group {
        title: "Аккаунт Google"
        ListItem {
            icon: "account_circle"
            title: "Вход в аккаунт недоступен"
            subtitle: "Вместо него — «Мои устройства» выше"
            clickable: false
        }
    }
    MText {
        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        wrapMode: Text.WordWrap
        size: Theme.type.bodyS
        color: Theme.fgSurfaceVariant
        text: "«Ваши устройства» на Pixel держатся на сертификатах, которые серверы Google выдают только Android и Quick Share для Windows. Открытого способа получить их нет ни у одного стороннего клиента, а обычный вход в Google не делает компьютер доверенным устройством. Когда такой способ появится, вход будет здесь."
    }
}
