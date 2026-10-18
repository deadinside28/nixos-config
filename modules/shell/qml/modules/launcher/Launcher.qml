// Лаунчер в духе Aluminium OS: выезжает снизу слева над панелью задач.
// Сверху строка поиска, ниже — частые приложения и сетка всех по алфавиту.
// Поиск по названию, ключевым словам и описанию; Enter запускает первое,
// стрелки ходят по сетке. «=2+2» — калькулятор, «>команда» — запуск в
// терминале, иначе последним пунктом — поиск в интернете.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

Overlay {
    id: root
    name: "launcher"
    open: Ui.panel === "launcher"
    onDismissed: Ui.close()

    property string query: ""
    readonly property bool searching: query.trim() !== ""
    // Открытая папка меню («Настройки → Приложения → Меню приложений»)
    property string folder: ""
    readonly property var results: searching ? Apps.search(query) : Apps.launcherItems(folder)
    readonly property int columns: Math.max(3, Math.min(10, Settings.data.launcherColumns))
    property int current: 0

    onOpenChanged: {
        if (open) {
            query = "";
            search.text = "";
            folder = "";
            current = 0;
            search.forceFocus();
        }
    }
    onQueryChanged: current = 0
    onFolderChanged: current = 0

    // Калькулятор: только цифры, скобки и операторы — ничего не исполняем.
    readonly property string calc: {
        const q = query.trim().replace(/^=/, "").replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/");
        if (!/^[\d\s.+\-*/()%^]+$/.test(q) || !/\d\s*[+\-*/%^]\s*[\d(]/.test(q))
            return "";
        try {
            const v = Function(`"use strict"; return (${q.replace(/\^/g, "**")})`)();
            return Number.isFinite(v) ? String(Math.round(v * 1e10) / 1e10) : "";
        } catch (e) {
            return "";
        }
    }

    function activate(i) {
        if (i >= results.length)
            return;
        if (results[i].isFolder) {
            folder = results[i].folder;
            return;
        }
        Apps.launch(results[i]);
        Ui.close();
    }
    function runQuery() {
        const q = query.trim();
        if (calc !== "") {
            Quickshell.clipboardText = calc;
            Ui.close();
        } else if (q.startsWith(">")) {
            Apps.run([Nix.terminal, "--hold", "sh", "-c", q.slice(1)]);
            Ui.close();
        } else if (results.length > 0) {
            activate(current);
        } else if (q !== "") {
            webSearch();
        }
    }
    function webSearch() {
        Quickshell.execDetached(["xdg-open", Settings.data.searchEngine + encodeURIComponent(query.trim())]);
        Ui.close();
    }

    Card {
        id: card
        width: 660
        height: Math.min(720, root.height - root.insetTop - root.insetBottom - 24)
        // Рядом с кнопкой лаунчера: она в начале панели
        // Снизу по центру экрана (сверху — если панель сверху)
        x: root.insetLeft + (root.width - root.insetLeft - root.insetRight - width) / 2
        y: (Bar.edge === "top" ? root.insetTop + 12 : root.height - root.insetBottom - 12 - height) + root.slideY((1 - root.progress) * 40)
        opacity: root.progress
        scale: 0.94 + 0.06 * root.progress
        transformOrigin: Bar.edge === "top" ? Item.Top : Item.Bottom
        color: Theme.panel

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            TextField {
                id: search
                Layout.fillWidth: true
                icon: "search"
                placeholder: "Поиск приложений, расчёты, интернет"
                fieldColor: Theme.surfaceContainerHighest
                onTextChanged: root.query = text
                onAccepted: root.runQuery()
                onEscapePressed: root.folder !== "" ? root.folder = "" : Ui.close()
                input.Keys.onPressed: event => {
                    // Backspace в пустом поиске — из папки наверх
                    if (event.key === Qt.Key_Backspace && search.text === "" && root.folder !== "") {
                        root.folder = "";
                        event.accepted = true;
                        return;
                    }
                    const n = root.results.length;
                    if (n === 0)
                        return;
                    let c = root.current;
                    switch (event.key) {
                    case Qt.Key_Right:
                        if (search.input.cursorPosition < search.text.length)
                            return;
                        c = Math.min(n - 1, c + 1);
                        break;
                    case Qt.Key_Left:
                        if (search.input.cursorPosition > 0)
                            return;
                        c = Math.max(0, c - 1);
                        break;
                    case Qt.Key_Down:
                        c = Math.min(n - 1, c + (root.searching ? 1 : root.columns));
                        break;
                    case Qt.Key_Up:
                        c = Math.max(0, c - (root.searching ? 1 : root.columns));
                        break;
                    case Qt.Key_Tab:
                        c = (c + 1) % n;
                        break;
                    default:
                        return;
                    }
                    root.current = c;
                    event.accepted = true;
                }
            }

            // Калькулятор / команда / интернет
            ListItem {
                visible: root.calc !== ""
                icon: "calculate"
                iconTinted: true
                iconBg: Theme.tertiaryContainer
                iconFg: Theme.fgTertiaryContainer
                title: "= " + root.calc
                subtitle: "Enter — скопировать результат"
                onClicked: root.runQuery()
            }
            ListItem {
                visible: root.query.trim().startsWith(">")
                icon: "terminal"
                iconTinted: true
                title: root.query.trim().slice(1) || "команда"
                subtitle: "Выполнить в терминале"
                onClicked: root.runQuery()
            }

            // Открытая папка: заголовок и возврат
            RowLayout {
                visible: !root.searching && root.folder !== ""
                Layout.fillWidth: true
                spacing: 8
                IconButton {
                    icon: "arrow_back"
                    onClicked: root.folder = ""
                }
                MIcon {
                    icon: "folder"
                    fill: 1
                    color: Theme.primary
                }
                MText {
                    Layout.fillWidth: true
                    text: root.folder
                    size: Theme.type.titleM
                    weight: Theme.strongWeight
                }
            }

            // Частые — только без поиска
            ColumnLayout {
                visible: !root.searching && root.folder === "" && Apps.frequent.length > 0
                Layout.fillWidth: true
                spacing: 8
                MText {
                    text: "Часто используемые"
                    color: Theme.fgSurfaceVariant
                    size: Theme.type.labelL
                    weight: Theme.strongWeight
                    Layout.leftMargin: 8
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: Apps.frequent.slice(0, root.columns)
                        AppTile {
                            required property var modelData
                            Layout.fillWidth: true
                            app: modelData
                            onLaunch: {
                                Apps.launch(modelData);
                                Ui.close();
                            }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    height: 1
                    color: Theme.outlineVariant
                }
            }

            // Результаты поиска списком, все приложения — сеткой
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    visible: !root.searching
                    clip: true
                    cellWidth: width / root.columns
                    cellHeight: Settings.data.launcherIconSize + (Settings.data.launcherLabels ? 60 : 24)
                    model: root.searching ? [] : root.results
                    currentIndex: root.current
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    delegate: AppTile {
                        required property var modelData
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        app: modelData
                        highlighted: index === root.current
                        onLaunch: root.activate(index)
                    }
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    visible: root.searching
                    clip: true
                    spacing: 2
                    model: root.searching ? root.results : []
                    currentIndex: root.current
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 60
                        radius: Theme.radius.l
                        color: index === root.current ? Theme.secondaryContainer : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 16
                            AppIcon {
                                size: 36
                                icon: row.modelData.icon
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                MText {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    size: Theme.type.bodyL
                                    color: row.index === root.current ? Theme.fgSecondaryContainer : Theme.fgSurface
                                }
                                MText {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: row.modelData.comment || row.modelData.genericName || ""
                                    size: Theme.type.bodyS
                                    color: Theme.fgSurfaceVariant
                                }
                            }
                            MIcon {
                                visible: row.index === root.current
                                icon: "keyboard_return"
                                size: 20
                                color: Theme.fgSecondaryContainer
                            }
                        }
                        StateLayer {
                            onClicked: root.activate(row.index)
                            onContainsMouseChanged: if (containsMouse)
                                root.current = row.index
                        }
                    }
                    footer: ListItem {
                        width: list.width
                        visible: root.searching && root.calc === "" && !root.query.trim().startsWith(">")
                        icon: "travel_explore"
                        iconTinted: true
                        title: "Искать «" + root.query.trim() + "» в интернете"
                        onClicked: root.webSearch()
                    }
                }

                MText {
                    anchors.centerIn: parent
                    visible: root.searching && root.results.length === 0 && root.calc === ""
                    anchors.verticalCenterOffset: -40
                    text: "Ничего не нашлось"
                    color: Theme.fgSurfaceVariant
                    size: Theme.type.bodyL
                }
            }
        }
    }
}
