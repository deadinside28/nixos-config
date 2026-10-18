// «Настройки» — обычное окно, как приложение настроек на Pixel в режиме
// рабочего стола / в Aluminium OS: слева поиск и разделы с цветными
// кружками, справа страница раздела с группами пунктов.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import "pages"
import Pixel.MD3E

Scope {
    id: root

    LazyLoader {
        active: Ui.settingsOpen

        FloatingWindow {
            id: win
            title: "Настройки"
            implicitWidth: 1180
            implicitHeight: 800
            minimumSize: Qt.size(820, 560)
            color: Theme.surfaceContainer
            visible: true
            onVisibleChanged: if (!visible)
                Ui.settingsOpen = false

            readonly property bool narrow: width < 980
            property string query: ""

            Shortcut {
                sequence: "Ctrl+F"
                onActivated: search.forceFocus()
            }
            Shortcut {
                sequence: "Escape"
                onActivated: search.text !== "" ? search.text = "" : Ui.settingsOpen = false
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // --- Навигация -------------------------------------------
                ColumnLayout {
                    Layout.preferredWidth: win.narrow ? 300 : 360
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: 12

                    MText {
                        Layout.leftMargin: 16
                        Layout.topMargin: 16
                        text: "Настройки"
                        size: Theme.type.headlineM
                    }

                    TextField {
                        id: search
                        Layout.fillWidth: true
                        icon: "search"
                        placeholder: "Поиск в настройках"
                        fieldColor: Theme.surfaceContainerHighest
                        onTextChanged: win.query = text
                        onAccepted: {
                            const r = SettingsIndex.search(win.query);
                            if (r.length) {
                                Ui.goSettings(r[0].page);
                                text = "";
                            }
                        }
                    }

                    ListView {
                        id: nav
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.query === "" ? SettingsIndex.pages : SettingsIndex.search(win.query)

                        delegate: Rectangle {
                            id: item
                            required property var modelData
                            required property int index
                            readonly property bool isPage: win.query === ""
                            readonly property bool sel: isPage && Ui.settingsPage === modelData.page
                            readonly property var accent: Theme.accents[(modelData.accent ?? 0) % Theme.accents.length]

                            width: nav.width
                            height: isPage ? 72 : 64
                            radius: height / 2
                            color: sel ? Theme.secondaryContainer : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.anim.fast
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 16
                                spacing: 16

                                Rectangle {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44
                                    radius: 22
                                    color: item.accent.bg
                                    MIcon {
                                        anchors.centerIn: parent
                                        icon: item.modelData.icon
                                        fill: 1
                                        color: item.accent.fg
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    MText {
                                        Layout.fillWidth: true
                                        text: item.modelData.title
                                        size: Theme.type.titleM
                                        color: item.sel ? Theme.fgSecondaryContainer : Theme.fgSurface
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        text: item.modelData.subtitle
                                        size: Theme.type.bodyM
                                        color: item.sel ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                                    }
                                }
                            }

                            StateLayer {
                                onClicked: {
                                    Ui.goSettings(item.modelData.page);
                                    if (!item.isPage)
                                        search.text = "";
                                }
                            }
                        }

                        MText {
                            anchors.centerIn: parent
                            visible: nav.count === 0
                            text: "Ничего не найдено"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }

                // --- Страница ---------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius.xl
                    color: Theme.dark ? Theme.surface : Theme.surfaceContainerLow
                    clip: true

                    Loader {
                        id: page
                        anchors.fill: parent
                        source: "pages/" + (SettingsIndex.pages.find(p => p.page === Ui.settingsPage)?.file ?? "NetworkPage") + ".qml"
                        opacity: status === Loader.Ready ? 1 : 0

                        onSourceChanged: enter.restart()
                        NumberAnimation {
                            id: enter
                            target: page.item
                            property: "y"
                            from: 24
                            to: 0
                            duration: Theme.anim.normal
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.anim.emphasizedDecel
                        }
                    }
                }
            }
        }
    }
}
