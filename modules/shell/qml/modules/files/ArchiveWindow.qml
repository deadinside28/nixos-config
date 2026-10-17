// Архиватор: отдельное окно для zip, 7z, rar, tar… в стиле «Файлов».
// Архив распаковывается в кеш (bsdtar), и по нему ходишь как по папке:
// файлы можно перетащить куда угодно, перетащить в окно — добавятся в архив.
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.common
import qs.widgets
import qs.services

FloatingWindow {
    id: win
    required property var entry // { id, path }

    readonly property string archive: entry.path
    readonly property string name: archive.split("/").pop()
    readonly property string parentDir: archive.slice(0, archive.lastIndexOf("/")) || "/"
    // rar и подобные bsdtar только читает
    readonly property bool writable: /\.(zip|7z|tar|tgz|tbz2|txz|tar\.(gz|bz2|xz|zst))$/i.test(name)

    title: "Архив — " + name
    implicitWidth: 860
    implicitHeight: 640
    minimumSize: Qt.size(560, 420)
    color: Theme.surfaceContainer
    visible: true
    onVisibleChanged: if (!visible)
        Files.closeArchiveWindow(entry.id)

    property string root: ""
    property string path: ""
    property bool failed: false
    property var selected: ({})
    readonly property var selectedPaths: Object.keys(selected).filter(k => selected[k])

    function load() {
        failed = false;
        Files.openArchive(archive, (ok, dir) => {
            win.failed = !ok;
            if (ok) {
                win.root = dir;
                if (!win.path.startsWith(dir))
                    win.path = dir;
            }
        });
    }
    Component.onCompleted: load()

    FolderListModel {
        id: model
        folder: win.path ? "file://" + win.path : ""
        showDirsFirst: true
        showHidden: true
        nameFilters: ["*"]
        caseSensitive: false
    }
    // служебная отметка распаковки — не показываем
    readonly property var rows: {
        const _ = model.count;
        const out = [];
        for (let i = 0; i < model.count; i++) {
            const n = model.get(i, "fileName");
            if (n === ".pixel-done")
                continue;
            out.push({
                name: n,
                path: model.get(i, "filePath"),
                isDir: model.get(i, "fileIsDir"),
                size: model.get(i, "fileSize"),
                modified: model.get(i, "fileModified")
            });
        }
        return out;
    }
    property var info: ({
            size: 0
        })

    function goUp() {
        if (path !== root)
            path = path.slice(0, path.lastIndexOf("/"));
        selected = {};
    }

    Shortcut {
        sequence: "Escape"
        onActivated: picker.visible ? picker.visible = false : win.visible = false
    }
    Shortcut {
        sequences: ["Backspace", "Alt+Up"]
        onActivated: win.goUp()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // --- Шапка ---------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Rectangle {
                implicitWidth: 64
                implicitHeight: 64
                radius: 20
                color: Theme.primaryContainer
                MIcon {
                    anchors.centerIn: parent
                    icon: "folder_zip"
                    size: 32
                    fill: 1
                    color: Theme.fgPrimaryContainer
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                MText {
                    Layout.fillWidth: true
                    text: win.name
                    size: Theme.type.headlineS
                    elide: Text.ElideMiddle
                }
                MText {
                    Layout.fillWidth: true
                    text: win.failed ? "Не удалось открыть архив" : !win.root ? "Открываю…" : (win.parentDir.replace(Files.home, "~") + (win.writable ? "" : " · только чтение"))
                    color: win.failed ? Theme.error : Theme.fgSurfaceVariant
                    elide: Text.ElideMiddle
                }
            }
            IconButton {
                icon: "folder_open"
                tooltip: "Показать в «Файлах»"
                onClicked: Files.open(win.parentDir)
            }
            Button {
                variant: "tonal"
                icon: "drive_file_move"
                text: "Распаковать в…"
                onClicked: picker.visible = true
            }
            Button {
                icon: "unarchive"
                text: "Распаковать"
                onClicked: {
                    Files.extract(win.archive);
                    win.visible = false;
                }
            }
        }

        // --- Содержимое ----------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius.xl
            color: Theme.surface
            clip: true
            border.width: drop.containsDrag ? 2 : 0
            border.color: Theme.primary

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // путь внутри архива
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    IconButton {
                        icon: "arrow_upward"
                        opacity: win.path !== win.root ? 1 : 0.38
                        onClicked: win.goUp()
                    }
                    MText {
                        Layout.fillWidth: true
                        text: win.name + win.path.slice(win.root.length).split("/").join("  ›  ")
                        size: Theme.type.titleS
                        weight: Theme.strongWeight
                        elide: Text.ElideLeft
                    }
                    MText {
                        text: win.rows.length + " " + (win.rows.length === 1 ? "объект" : "объектов")
                        color: Theme.fgSurfaceVariant
                        size: Theme.type.bodyS
                    }
                }
                LinearProgress {
                    Layout.fillWidth: true
                    visible: Files.busy > 0 || (!win.root && !win.failed)
                    value: -1
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: win.rows
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool sel: !!win.selected[modelData.path]
                        readonly property bool isFileItem: true
                        width: list.width
                        height: 52
                        radius: 26
                        color: sel ? Theme.primaryContainer : rma.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: ({
                                "text/uri-list": (row.sel ? win.selectedPaths : [row.modelData.path]).map(p => "file://" + encodeURI(p)).join("\r\n")
                            })

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 16
                            spacing: 12
                            AppIcon {
                                styled: false
                                size: 32
                                icon: Files.iconFor(row.modelData.name, row.modelData.path, row.modelData.isDir)
                            }
                            MText {
                                Layout.fillWidth: true
                                text: row.modelData.name
                                elide: Text.ElideMiddle
                                color: row.sel ? Theme.fgPrimaryContainer : Theme.fgSurface
                            }
                            MText {
                                Layout.preferredWidth: 100
                                text: row.modelData.isDir ? "—" : Files.humanSize(row.modelData.size)
                                color: row.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                            }
                            MText {
                                Layout.preferredWidth: 130
                                text: Files.humanDate(row.modelData.modified)
                                color: row.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                            }
                        }
                        MouseArea {
                            id: rma
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor
                            property point start
                            property bool dragged: false
                            onPressed: event => {
                                start = Qt.point(event.x, event.y);
                                dragged = false;
                                if (!row.sel || (event.modifiers & Qt.ControlModifier)) {
                                    const s = (event.modifiers & Qt.ControlModifier) ? Object.assign({}, win.selected) : {};
                                    s[row.modelData.path] = !s[row.modelData.path];
                                    win.selected = s;
                                }
                            }
                            onPositionChanged: event => {
                                if (pressed && !dragged && Math.hypot(event.x - start.x, event.y - start.y) > 12) {
                                    dragged = true;
                                    row.Drag.startDrag();
                                }
                            }
                            onDoubleClicked: {
                                if (row.modelData.isDir) {
                                    win.path = row.modelData.path;
                                    win.selected = {};
                                } else
                                    Files.openFile(row.modelData.path);
                            }
                        }
                    }
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: win.writable ? "Перетащи файлы сюда — они добавятся в архив. Отсюда — тащи куда угодно" : "Файлы отсюда можно перетащить куда угодно"
                    size: Theme.type.bodyS
                    color: Theme.fgSurfaceVariant
                }
            }

            DropArea {
                id: drop
                anchors.fill: parent
                enabled: win.writable && win.root !== ""
                keys: ["text/uri-list"]
                onDropped: d => {
                    if (d.source && d.source.isFileItem && d.source.parent === list.contentItem)
                        return;
                    const paths = d.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")));
                    if (!paths.length)
                        return;
                    Files.addToArchive(win.archive, win.root, win.path, paths);
                    d.accept(Qt.CopyAction);
                }
            }
        }
    }

    // «Распаковать в…» — быстрые места или свой путь
    Item {
        id: picker
        anchors.fill: parent
        visible: false
        z: 10
        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.32)
            MouseArea {
                anchors.fill: parent
                onClicked: picker.visible = false
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(460, parent.width - 48)
            height: pcol.implicitHeight + 48
            radius: Theme.radius.xl
            color: Theme.surfaceContainerHigh
            MouseArea {
                anchors.fill: parent
            }
            ColumnLayout {
                id: pcol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 8
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 8
                    text: "Распаковать в"
                    size: Theme.type.headlineS
                }
                Repeater {
                    model: [
                        {
                            icon: "folder",
                            name: "Рядом с архивом",
                            path: win.parentDir
                        },
                        ...Files.places.filter(p => p.path !== win.parentDir)
                    ]
                    Rectangle {
                        id: pl
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 24
                        color: Theme.surfaceContainerHighest
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            spacing: 14
                            MIcon {
                                icon: pl.modelData.icon
                                color: Theme.primary
                            }
                            MText {
                                Layout.fillWidth: true
                                text: pl.modelData.name
                            }
                        }
                        StateLayer {
                            radius: pl.radius
                            onClicked: {
                                Files.extract(win.archive, pl.modelData.path);
                                Files.open(pl.modelData.path);
                                win.visible = false;
                            }
                        }
                    }
                }
                Button {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: 8
                    variant: "text"
                    text: "Отмена"
                    onClicked: picker.visible = false
                }
            }
        }
    }
}
