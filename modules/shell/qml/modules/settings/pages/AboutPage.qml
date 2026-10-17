import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "О системе"
    readonly property var i: SysInfo.info

    Component.onCompleted: SysInfo.refresh()

    // Карточка «устройства», как на Pixel
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 180
        radius: Theme.radius.xxl
        color: Theme.primaryContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 24
            Rectangle {
                Layout.preferredWidth: 112
                Layout.preferredHeight: 112
                radius: Theme.radius.xl
                color: Theme.primary
                MIcon {
                    anchors.centerIn: parent
                    icon: "computer"
                    size: 64
                    fill: 1
                    color: Theme.onPrimary
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                MText {
                    text: page.i.host ?? Nix.hostname
                    size: Theme.type.headlineL
                    color: Theme.onPrimaryContainer
                }
                MText {
                    text: page.i.os ?? "NixOS"
                    size: Theme.type.titleM
                    color: Theme.onPrimaryContainer
                }
                MText {
                    text: "Поколение " + (page.i.generation ?? "?") + " · включён " + (page.i.uptime ?? "")
                    color: Theme.alpha(Theme.onPrimaryContainer, 0.8)
                }
            }
        }
    }

    Group {
        title: "Железо"
        ListItem {
            icon: "memory"
            title: "Процессор"
            subtitle: (page.i.cpu ?? "—") + (page.i.cores ? " · " + page.i.cores + " потоков" : "")
            clickable: false
        }
        ListItem {
            icon: "developer_board"
            title: "Видеокарта"
            subtitle: page.i.gpu || "—"
            clickable: false
        }
        ListItem {
            icon: "memory_alt"
            title: "Оперативная память"
            subtitle: (page.i.mem ?? "?") + " ГБ"
            clickable: false
        }
        ListItem {
            icon: "hard_drive"
            title: "Системный диск"
            subtitle: page.i.disk ? "Занято " + page.i.disk : "—"
            clickable: false
        }
    }

    Group {
        title: "Программы"
        ListItem {
            icon: "deployed_code"
            title: "Версия NixOS"
            subtitle: page.i.nixpkgs || page.i.version || "—"
            clickable: false
        }
        ListItem {
            icon: "terminal"
            title: "Ядро"
            subtitle: page.i.kernel ?? "—"
            clickable: false
        }
        ListItem {
            icon: "space_dashboard"
            title: "Оболочка"
            subtitle: "Pixel Shell на Quickshell " + Nix.quickshellVersion + " · Hyprland"
            clickable: false
        }
        ListItem {
            icon: "content_copy"
            title: "Скопировать сведения"
            subtitle: "Для отчёта об ошибке или вопроса на форуме"
            onClicked: Quickshell.clipboardText = Object.keys(page.i).map(k => k + ": " + page.i[k]).join("\n")
        }
    }
}
