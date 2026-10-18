// Системный диалог открытия и сохранения файлов (backend портала
// FileChooser, services/FileChooser.qml). Места, значки и даты — как в
// «Файлах»: открыть, несколько файлов, папку, сохранить и сохранить
// несколько в папку.
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.common
import qs.widgets
import qs.services

FloatingWindow {
    id: win
    required property var req

    readonly property bool saving: req.kind === "save"
    readonly property bool pickDir: req.directory || req.kind === "saveFiles"
    // Суффикс — для правила Hyprland (windowrules.lua): окно без родителя
    // иначе встало бы в тайлинг, а диалогу место по центру поверх
    title: (req.title || (saving ? "Сохранить" : pickDir ? "Выбрать папку" : "Открыть")) + " — выбор файла"
    implicitWidth: 920
    implicitHeight: 620
    minimumSize: Qt.size(640, 420)
    color: Theme.surfaceContainer
    visible: true
    // Закрыли окно — это отмена
    onVisibleChanged: if (!visible)
        FileChooser.finish(req, {
            response: 1
        })

    function startDir() {
        if (req.currentFolder)
            return req.currentFolder;
        if (req.currentFile)
            return req.currentFile.slice(0, req.currentFile.lastIndexOf("/")) || "/";
        return Settings.data.chooserLastDir || Settings.home;
    }
    property string dir: startDir()
    property var history: []
    function go(p) {
        if (!p || p === dir)
            return;
        history = [...history, dir];
        dir = p.length > 1 ? p.replace(/\/+$/, "") : p;
        selected = {};
    }
    function up() {
        go(dir.slice(0, dir.lastIndexOf("/")) || "/");
    }
    property bool hidden: false
    property var filter: req.filters.find(f => f.name === req.currentFilter) ?? req.filters[0] ?? null
    property var selected: ({}) // путь → true
    readonly property var selectedPaths: Object.keys(selected).filter(k => selected[k])
    property var choices: (req.choices ?? []).map(c => [c.id, c.selected])
    property bool confirmOverwrite: false

    function accept() {
        let paths;
        if (saving) {
            const name = nameField.text.trim();
            if (!name || name.includes("/"))
                return;
            const p = dir + "/" + name;
            if (!confirmOverwrite && model.exists(name)) {
                confirmOverwrite = true;
                return;
            }
            paths = [p];
        } else if (req.kind === "saveFiles") {
            // портал ждёт по пути на каждый сохраняемый файл в выбранной папке
            const base = selectedPaths[0] ?? dir;
            paths = (req.files ?? []).map(f => base + "/" + f.split("/").pop());
        } else if (pickDir) {
            paths = selectedPaths.length ? selectedPaths : [dir];
        } else {
            paths = selectedPaths;
            if (!paths.length)
                return;
        }
        FileChooser.finish(req, {
            response: 0,
            paths,
            filter: filter?.name ?? "",
            choices
        });
        win.visible = false;
    }
    function cancel() {
        FileChooser.finish(req, {
            response: 1
        });
        win.visible = false;
    }

    FolderListModel {
        id: model
        folder: "file://" + win.dir
        showDirsFirst: true
        showHidden: win.hidden
        showFiles: !win.pickDir
        showDotAndDotDot: false
        caseSensitive: false
        nameFilters: win.pickDir ? [] : FileChooser.globsFor(win.filter)
        function exists(name) {
            for (let i = 0; i < count; i++)
                if (get(i, "fileName") === name)
                    return true;
            return false;
        }
    }
    // Отмена из приложения закрывает окно
    Connections {
        target: FileChooser
        function onRequestsChanged() {
            if (!FileChooser.requests.some(r => r.id === win.req.id))
                win.visible = false;
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: win.cancel()
    }
    Shortcut {
        sequences: ["Backspace", "Alt+Up"]
        enabled: !nameField.input.activeFocus && !pathField.input.activeFocus
        onActivated: win.up()
    }
    Shortcut {
        sequence: "Ctrl+H"
        onActivated: win.hidden = !win.hidden
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // --- Места -----------------------------------------------------------
        ListView {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: [...Files.places, ...Files.bookmarks, ...Files.drives]
            delegate: Rectangle {
                id: place
                required property var modelData
                width: ListView.view.width
                height: 44
                radius: 22
                color: win.dir === modelData.path ? Theme.secondaryContainer : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    spacing: 12
                    MIcon {
                        icon: place.modelData.icon
                        color: Theme.fgSurfaceVariant
                    }
                    MText {
                        Layout.fillWidth: true
                        text: place.modelData.name
                        elide: Text.ElideRight
                    }
                }
                StateLayer {
                    onClicked: win.go(place.modelData.path)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // --- Путь ------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                IconButton {
                    icon: "arrow_back"
                    opacity: win.history.length ? 1 : 0.38
                    onClicked: if (win.history.length) {
                        win.dir = win.history[win.history.length - 1];
                        win.history = win.history.slice(0, -1);
                    }
                }
                IconButton {
                    icon: "arrow_upward"
                    onClicked: win.up()
                }
                TextField {
                    id: pathField
                    Layout.fillWidth: true
                    implicitHeight: 44
                    text: win.dir.replace(Settings.home, "~")
                    onAccepted: win.go(text.trim().replace(/^~/, Settings.home))
                }
                IconButton {
                    icon: win.hidden ? "visibility" : "visibility_off"
                    tooltip: "Скрытые файлы (Ctrl+H)"
                    onClicked: win.hidden = !win.hidden
                }
            }

            // --- Файлы -------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radius.xl
                color: Theme.surface
                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: model
                    delegate: Rectangle {
                        id: row
                        required property string fileName
                        required property string filePath
                        required property bool fileIsDir
                        required property var fileModified
                        required property var fileSize
                        required property int index
                        readonly property bool sel: !!win.selected[filePath]
                        width: list.width
                        height: 44
                        radius: 12
                        color: sel ? Theme.secondaryContainer : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12
                            AppIcon {
                                size: 24
                                styled: false
                                icon: Files.iconFor(row.fileName, row.filePath, row.fileIsDir)
                            }
                            MText {
                                Layout.fillWidth: true
                                text: row.fileName
                                elide: Text.ElideMiddle
                            }
                            MText {
                                text: row.fileIsDir ? "" : Files.humanSize(row.fileSize)
                                color: Theme.fgSurfaceVariant
                                size: Theme.type.bodyS
                            }
                            MText {
                                Layout.preferredWidth: 120
                                text: Files.humanDate(row.fileModified)
                                color: Theme.fgSurfaceVariant
                                size: Theme.type.bodyS
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: mouse => {
                                if (win.saving && !row.fileIsDir) {
                                    nameField.text = row.fileName;
                                    return;
                                }
                                // Папка в режиме выбора файлов — выделять незачем
                                if (row.fileIsDir && !win.pickDir)
                                    return;
                                const s = (win.req.multiple && (mouse.modifiers & Qt.ControlModifier)) ? Object.assign({}, win.selected) : {};
                                s[row.filePath] = !win.selected[row.filePath] || !(mouse.modifiers & Qt.ControlModifier);
                                win.selected = s;
                            }
                            onDoubleClicked: {
                                if (row.fileIsDir)
                                    win.go(row.filePath);
                                else if (!win.saving) {
                                    win.selected = {
                                        [row.filePath]: true
                                    };
                                    win.accept();
                                } else {
                                    nameField.text = row.fileName;
                                    win.accept();
                                }
                            }
                        }
                    }
                    MText {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: win.pickDir ? "Вложенных папок нет" : "Здесь нет подходящих файлов"
                        color: Theme.fgSurfaceVariant
                    }
                }
            }

            // --- Параметры приложения (choices) ------------------------------------
            Repeater {
                model: win.req.choices ?? []
                RowLayout {
                    id: ch
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8
                    MText {
                        text: ch.modelData.label
                    }
                    // без вариантов — флажок, иначе выбор из списка
                    MSwitch {
                        visible: !ch.modelData.options.length
                        checked: win.choices[ch.index][1] === "true"
                        onToggled: v => {
                            const c = win.choices.slice();
                            c[ch.index] = [ch.modelData.id, v ? "true" : "false"];
                            win.choices = c;
                        }
                    }
                    SegmentedButtons {
                        visible: ch.modelData.options.length > 0
                        Layout.fillWidth: true
                        options: ch.modelData.options.map(o => ({
                                    value: o[0],
                                    label: o[1]
                                }))
                        current: win.choices[ch.index][1]
                        onSelected: v => {
                            const c = win.choices.slice();
                            c[ch.index] = [ch.modelData.id, v];
                            win.choices = c;
                        }
                    }
                }
            }

            // --- Имя, фильтр, кнопки ----------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                TextField {
                    id: nameField
                    visible: win.saving
                    Layout.fillWidth: true
                    implicitHeight: 48
                    placeholder: "Имя файла"
                    text: win.req.currentName || (win.req.currentFile ? win.req.currentFile.split("/").pop() : "")
                    onTextChanged: win.confirmOverwrite = false
                    onAccepted: win.accept()
                    Component.onCompleted: if (win.saving)
                        forceFocus()
                }
                MText {
                    visible: !win.saving
                    Layout.fillWidth: true
                    text: win.pickDir ? (win.selectedPaths[0] ?? win.dir).replace(Settings.home, "~") : win.selectedPaths.length > 1 ? "Выбрано: " + win.selectedPaths.length : (win.selectedPaths[0] ?? "").split("/").pop()
                    elide: Text.ElideMiddle
                    color: Theme.fgSurfaceVariant
                }
                ChoiceItem {
                    visible: (win.req.filters ?? []).length > 1 && !win.pickDir
                    Layout.fillWidth: false
                    Layout.preferredWidth: 260
                    icon: "filter_list"
                    title: "Тип файлов"
                    options: (win.req.filters ?? []).map(f => ({
                                value: f.name,
                                label: f.name
                            }))
                    current: win.filter?.name ?? ""
                    onSelected: v => win.filter = win.req.filters.find(f => f.name === v)
                }
                Button {
                    variant: "text"
                    text: "Отмена"
                    onClicked: win.cancel()
                }
                Button {
                    variant: win.confirmOverwrite ? "danger" : "filled"
                    text: win.confirmOverwrite ? "Заменить файл" : win.req.acceptLabel ? win.req.acceptLabel.replace(/_/g, "") : win.saving ? "Сохранить" : win.pickDir ? "Выбрать" : "Открыть"
                    disabled: win.saving ? nameField.text.trim() === "" : !win.pickDir && win.selectedPaths.length === 0
                    onClicked: win.accept()
                }
            }
        }
    }
}
