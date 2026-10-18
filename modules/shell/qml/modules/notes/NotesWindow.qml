// «Заметки» — отдельное окно: слева список (папки, поиск, закреплённые
// сверху), справа заметка. Файлы и сохранение — services/Notes.qml.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services

Scope {
    LazyLoader {
        active: Ui.notesOpen

        FloatingWindow {
            id: win
            title: "Заметки"
            implicitWidth: 1040
            implicitHeight: 720
            minimumSize: Qt.size(720, 480)
            color: Theme.surfaceContainer
            visible: true
            onVisibleChanged: if (!visible) {
                win.flush();
                Ui.notesOpen = false;
            }
            Component.onCompleted: Notes.refresh()

            property string folder: "" // фильтр по папке; "" — все
            property string current: "" // путь открытой заметки
            property bool preview: false
            readonly property var shown: Notes.notes.filter(n => (!folder || n.folder === folder) && (Notes.matches === null || Notes.matches.includes(n.path)))

            // --- Открытая заметка ---------------------------------------------
            property bool dirty: false
            property bool loading: false
            property bool externalChange: false
            function open(path) {
                flush();
                current = path;
                externalChange = false;
                dirty = false;
                loading = true;
                titleField.text = path ? path.split("/").pop().replace(/\.md$/, "") : "";
            }
            function flush() {
                if (dirty && current) {
                    file.setText(editor.text);
                    dirty = false;
                }
            }
            FileView {
                id: file
                path: win.current
                watchChanges: true
                printErrors: false
                atomicWrites: true
                onLoaded: {
                    win.loading = false;
                    if (!win.dirty)
                        editor.text = text();
                }
                onLoadFailed: win.loading = false
                // Изменили снаружи: без своих правок — перечитать, с правками —
                // не затирать ни то ни другое, спросить
                onFileChanged: {
                    if (win.dirty)
                        win.externalChange = true;
                    else
                        reload();
                }
                onSaved: Notes.refresh()
            }
            Timer {
                id: autosave
                interval: 800
                onTriggered: win.flush()
            }

            Shortcut {
                sequence: "Ctrl+N"
                onActivated: win.open(Notes.create(win.folder))
            }
            Shortcut {
                sequence: "Ctrl+S"
                onActivated: win.flush()
            }
            Shortcut {
                sequence: "Ctrl+F"
                onActivated: search.forceFocus()
            }
            Shortcut {
                sequence: "Ctrl+E"
                onActivated: win.preview = !win.preview
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // --- Список -------------------------------------------------
                ColumnLayout {
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        MText {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            text: "Заметки"
                            size: Theme.type.headlineM
                        }
                        IconButton {
                            icon: "folder_open"
                            tooltip: "Открыть папку заметок"
                            onClicked: Files.open(Notes.dir)
                        }
                        IconButton {
                            icon: "edit_square"
                            tooltip: "Новая заметка (Ctrl+N)"
                            onClicked: win.open(Notes.create(win.folder))
                        }
                    }
                    TextField {
                        id: search
                        Layout.fillWidth: true
                        implicitHeight: 48
                        icon: "search"
                        placeholder: "Поиск по заметкам"
                        onTextChanged: Notes.search(text)
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: Notes.folders.length > 0
                        Repeater {
                            model: ["", ...Notes.folders]
                            Rectangle {
                                required property var modelData
                                readonly property bool on: win.folder === modelData
                                implicitWidth: chipText.implicitWidth + 24
                                implicitHeight: 32
                                radius: 8
                                color: on ? Theme.secondaryContainer : "transparent"
                                border.width: on ? 0 : 1
                                border.color: Theme.outlineVariant
                                MText {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: parent.modelData || "Все"
                                    size: Theme.type.labelL
                                }
                                StateLayer {
                                    onClicked: win.folder = parent.modelData
                                }
                            }
                        }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: win.shown
                        delegate: Rectangle {
                            id: nrow
                            required property var modelData
                            width: ListView.view.width
                            height: 64
                            radius: Theme.radius.l
                            color: win.current === modelData.path ? Theme.secondaryContainer : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    MText {
                                        Layout.fillWidth: true
                                        text: nrow.modelData.title
                                        weight: Theme.strongWeight
                                        elide: Text.ElideRight
                                    }
                                    MText {
                                        Layout.fillWidth: true
                                        text: Files.humanDate(nrow.modelData.mtime) + (nrow.modelData.folder ? " · " + nrow.modelData.folder : "")
                                        size: Theme.type.bodyS
                                        color: Theme.fgSurfaceVariant
                                    }
                                }
                                MIcon {
                                    visible: Notes.isPinned(nrow.modelData.path)
                                    icon: "keep"
                                    size: 18
                                    fill: 1
                                    color: Theme.primary
                                }
                            }
                            StateLayer {
                                onClicked: win.open(nrow.modelData.path)
                            }
                        }
                        MText {
                            anchors.centerIn: parent
                            visible: parent.count === 0
                            text: Notes.matches !== null ? "Ничего не нашлось" : "Заметок пока нет — Ctrl+N"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }

                // --- Заметка -------------------------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radius.xl
                    color: Theme.surface
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 12
                        visible: win.current !== ""
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            TextField {
                                id: titleField
                                Layout.fillWidth: true
                                implicitHeight: 48
                                placeholder: "Название"
                                onAccepted: {
                                    win.flush();
                                    Notes.rename(win.current, text.trim(), p => {
                                        win.current = p;
                                        titleField.text = p.split("/").pop().replace(/\.md$/, "");
                                    });
                                    editor.forceActiveFocus();
                                }
                            }
                            IconButton {
                                icon: win.preview ? "edit" : "visibility"
                                tooltip: win.preview ? "Редактировать (Ctrl+E)" : "Просмотр Markdown (Ctrl+E)"
                                onClicked: win.preview = !win.preview
                            }
                            IconButton {
                                icon: "keep"
                                tooltip: Notes.isPinned(win.current) ? "Открепить" : "Закрепить сверху"
                                onClicked: {
                                    Notes.setPinned(win.current, !Notes.isPinned(win.current));
                                    Notes.refresh();
                                }
                            }
                            IconButton {
                                icon: "drive_file_move"
                                tooltip: "В папку…"
                                onClicked: folderBox.visible = !folderBox.visible
                            }
                            IconButton {
                                icon: "delete"
                                tooltip: "В корзину"
                                onClicked: {
                                    const p = win.current;
                                    win.dirty = false;
                                    win.current = "";
                                    Notes.trash(p);
                                }
                            }
                        }
                        TextField {
                            id: folderBox
                            visible: false
                            Layout.fillWidth: true
                            implicitHeight: 48
                            icon: "folder"
                            placeholder: "Папка (пусто — без папки), Enter — перенести"
                            onAccepted: {
                                win.flush();
                                Notes.moveTo(win.current, text.trim().replace(/^\/+|\/+$/g, "").replace(/\.\.+/g, ""), p => win.current = p);
                                visible = false;
                                text = "";
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            visible: win.externalChange
                            implicitHeight: extRow.implicitHeight + 16
                            radius: 12
                            color: Theme.errorContainer
                            RowLayout {
                                id: extRow
                                x: 12
                                y: 8
                                width: parent.width - 24
                                MText {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    color: Theme.fgErrorContainer
                                    text: "Файл изменили в другой программе, а здесь есть несохранённые правки."
                                }
                                Button {
                                    variant: "text"
                                    text: "Взять оттуда"
                                    onClicked: {
                                        win.dirty = false;
                                        win.externalChange = false;
                                        file.reload();
                                    }
                                }
                                Button {
                                    variant: "tonal"
                                    text: "Оставить мои"
                                    onClicked: {
                                        win.externalChange = false;
                                        win.flush();
                                    }
                                }
                            }
                        }
                        QQC.ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            QQC.TextArea {
                                id: editor
                                visible: !win.preview
                                wrapMode: TextEdit.Wrap
                                font.family: Theme.font
                                font.pixelSize: Theme.type.bodyL
                                color: Theme.fgSurface
                                selectionColor: Theme.alpha(Theme.primary, 0.3)
                                placeholderText: "Текст заметки. Markdown: # заголовок, **жирный**, - список"
                                background: null
                                // Пока заметка грузится или выключен автосейв на чтении,
                                // программные замены текста — не правки
                                onTextChanged: if (!win.loading && activeFocus) {
                                    win.dirty = true;
                                    autosave.restart();
                                }
                            }
                        }
                        QQC.ScrollView {
                            visible: win.preview
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            TextEdit {
                                width: parent.width
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.Wrap
                                textFormat: TextEdit.MarkdownText
                                text: editor.text
                                font.family: Theme.font
                                font.pixelSize: Theme.type.bodyL
                                color: Theme.fgSurface
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            text: win.dirty ? "Сохраняю…" : "Сохранено · " + win.current.replace(Settings.home, "~")
                            size: Theme.type.bodyS
                            color: Theme.fgSurfaceVariant
                            elide: Text.ElideMiddle
                        }
                    }
                    MText {
                        anchors.centerIn: parent
                        visible: win.current === ""
                        text: "Выбери заметку или создай новую"
                        color: Theme.fgSurfaceVariant
                    }
                }
            }
        }
    }
}
