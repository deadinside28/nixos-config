// Витрина Pixel.MD3E — самостоятельное приложение без Quickshell:
//   QML_IMPORT_PATH=<pixel-md3e>/lib/qt-6/qml QML_XHR_ALLOW_FILE_READ=1 \
//     qml gallery.qml
// Цвета и тёмная тема — из файлов Pixel Shell (ThemeFile).
// --quit — закрыться через полторы секунды (проверка в nix flake check),
// --shot=<файл.png> — перед этим сохранить снимок окна.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Pixel.MD3E

Window {
    id: win
    width: 520
    height: 760
    visible: true
    title: "Pixel MD3E"
    color: Theme.surfaceContainer

    ThemeFile {}

    Timer {
        running: Qt.application.arguments.includes("--quit")
        interval: 1500
        onTriggered: {
            const shot = Qt.application.arguments.find(a => a.startsWith("--shot="));
            if (shot)
                win.contentItem.grabToImage(r => {
                    r.saveToFile(shot.slice(7));
                    Qt.quit();
                });
            else
                Qt.quit();
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        ColumnLayout {
            id: col
            x: 24
            y: 24
            width: win.width - 48
            spacing: 16

            MText {
                text: "Pixel MD3E"
                size: Theme.type.headlineM
            }
            MText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.fgSurfaceVariant
                text: "Тема и виджеты Pixel Shell на чистом Qt Quick"
            }

            RowLayout {
                spacing: 8
                Button {
                    text: "Готово"
                    icon: "check"
                }
                Button {
                    text: "Тональная"
                    variant: "tonal"
                }
                Button {
                    text: "Контурная"
                    variant: "outlined"
                }
                IconButton {
                    icon: "dark_mode"
                    tooltip: "Тёмная тема"
                    onClicked: Theme.dark = !Theme.dark
                }
            }

            SegmentedButtons {
                id: seg
                Layout.fillWidth: true
                options: [
                    {
                        value: "day",
                        label: "День"
                    },
                    {
                        value: "week",
                        label: "Неделя"
                    },
                    {
                        value: "month",
                        label: "Месяц"
                    }
                ]
                current: "week"
                onSelected: v => current = v
            }

            TextField {
                Layout.fillWidth: true
                icon: "search"
                placeholder: "Поиск"
            }

            Group {
                title: "Список"
                ListItem {
                    icon: "wifi"
                    title: "Wi-Fi"
                    subtitle: "Подключено"
                    chevron: true
                }
                SwitchItem {
                    icon: "bluetooth"
                    title: "Bluetooth"
                    checked: true
                }
                SliderItem {
                    icon: "brightness_6"
                    title: "Яркость"
                    value: 0.6
                }
            }

            Card {
                Layout.fillWidth: true
                implicitHeight: 96
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    MText {
                        text: "Карточка"
                        size: Theme.type.titleM
                    }
                    LinearProgress {
                        Layout.fillWidth: true
                        value: 0.4
                    }
                }
            }

            RowLayout {
                spacing: 16
                CircularProgress {
                    implicitWidth: 40
                    implicitHeight: 40
                }
                MSwitch {
                    checked: true
                }
                MIcon {
                    icon: "favorite"
                    fill: 1
                    color: Theme.primary
                }
            }
        }
    }
}
