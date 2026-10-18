// Окно «Файлов» в стиле Aluminium OS: слева разделы (Недавние, Мои файлы,
// закладки, диски, корзина), справа карточка с путём, поиском и видом.
// В сетке папки идут отдельной группой плиток, файлы — карточками с превью,
// как в Files на ChromeOS.
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services

FloatingWindow {
    id: win
    required property var entry // { id, path }

    title: "Файлы — " + win.title_
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(720, 480)
    color: Theme.surfaceContainer
    visible: true
    onVisibleChanged: if (!visible)
        Files.closeWindow(entry.id)

    // --- Где мы --------------------------------------------------------------
    // path — папка; place — "dir" | "recent" | "search" | "trash"
    property string path: entry.archive ? entry.path.slice(0, entry.path.lastIndexOf("/")) || "/" : entry.path
    property string place: path === Files.trashDir ? "trash" : "dir"
    property var back: []
    property var forward: []
    readonly property string title_: place === "recent" ? "Недавние" : place === "search" ? "Поиск" : place === "trash" ? "Корзина" : (displayName(path))

    function displayName(p) {
        if (p === Files.home)
            return "Мои файлы";
        const pl = Files.places.find(x => x.path === p);
        return pl ? pl.name : p === "/" ? "Компьютер" : p.split("/").pop();
    }
    function go(p, keepForward) {
        if (place === "dir" || place === "trash")
            back = [...back, path];
        else
            back = [...back, "::" + place];
        if (!keepForward)
            forward = [];
        searchField.text = "";
        searching = false;
        selected = ({});
        if (p.startsWith("::")) {
            place = p.slice(2);
            if (place === "recent")
                loadRecent();
            return;
        }
        path = p;
        place = p === Files.trashDir ? "trash" : "dir";
    }
    function goBack() {
        if (!back.length)
            return;
        const cur = place === "dir" || place === "trash" ? path : "::" + place;
        const to = back[back.length - 1];
        back = back.slice(0, -1);
        forward = [...forward, cur];
        const b = back;
        go(to, true);
        back = b;
    }
    function goForward() {
        if (!forward.length)
            return;
        const to = forward[forward.length - 1];
        forward = forward.slice(0, -1);
        const f = forward;
        go(to, true);
        forward = f;
    }
    function goUp() {
        if (place !== "dir" || path === "/")
            return;
        go(path.slice(0, path.lastIndexOf("/")) || "/");
    }

    // --- Вид -------------------------------------------------------------------
    property string view: Settings.data.filesView // grid | list
    property bool showHidden: Settings.data.filesHidden
    property string sortBy: Settings.data.filesSort // name | time | size | type
    property bool sortDesc: Settings.data.filesSortDesc
    property string kindFilter: "" // для «Недавних»: image | video | audio | document

    // --- Содержимое -----------------------------------------------------------
    FolderListModel {
        id: dirsModel
        folder: win.place === "dir" || win.place === "trash" ? "file://" + win.path : ""
        showFiles: false
        showDotAndDotDot: false
        showHidden: win.showHidden
        sortField: win.sortBy === "time" ? FolderListModel.Time : FolderListModel.Name
        sortReversed: win.sortBy === "time" ? !win.sortDesc : win.sortDesc
        caseSensitive: false
        onCountChanged: Qt.callLater(win.rebuild)
        onStatusChanged: Qt.callLater(win.rebuild)
    }
    FolderListModel {
        id: filesModel
        folder: dirsModel.folder
        showDirs: false
        showHidden: win.showHidden
        sortField: ({
                name: FolderListModel.Name,
                time: FolderListModel.Time,
                size: FolderListModel.Size,
                type: FolderListModel.Type
            })[win.sortBy]
        // У FolderListModel «по возрастанию» для времени и размера — новые/большие
        // сверху; приводим к привычному: стрелка вниз — сначала новые/большие.
        sortReversed: win.sortBy === "name" || win.sortBy === "type" ? win.sortDesc : !win.sortDesc
        caseSensitive: false
        onCountChanged: Qt.callLater(win.rebuild)
        onStatusChanged: Qt.callLater(win.rebuild)
    }
    property var dirs: []
    property var files: []
    function rowsOf(m) {
        const out = [];
        for (let i = 0; i < m.count; i++)
            out.push({
                name: m.get(i, "fileName"),
                path: m.get(i, "filePath"),
                isDir: m.get(i, "fileIsDir"),
                size: m.get(i, "fileSize"),
                modified: m.get(i, "fileModified")
            });
        return out;
    }
    function rebuild() {
        if (place !== "dir" && place !== "trash")
            return;
        dirs = rowsOf(dirsModel);
        files = rowsOf(filesModel);
    }
    onPlaceChanged: Qt.callLater(rebuild)
    onPathChanged: {
        Qt.callLater(rebuild);
        dfProc.running = true;
    }

    // «Недавние» — из recently-used.xbel, что пишут GTK-приложения и браузеры
    property var recent: []
    FileView {
        id: xbel
        path: (Quickshell.env("XDG_DATA_HOME") || Files.home + "/.local/share") + "/recently-used.xbel"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    function loadRecent() {
        const re = /<bookmark href="file:\/\/([^"]+)"[^>]*modified="([^"]+)"/g;
        const items = [];
        const t = xbel.text();
        let m;
        while ((m = re.exec(t)) !== null)
            items.push([decodeURIComponent(m[1]), m[2]]);
        items.sort((a, b) => b[1].localeCompare(a[1]));
        const paths = [...new Set(items.map(i => i[0]))].slice(0, 150);
        recentProc.running = false;
        recentProc.command = ["sh", "-c", 'for f; do [ -f "$f" ] && stat -c "%n\t%s\t%Y" -- "$f"; done', "sh", ...paths];
        recentProc.running = true;
    }
    Process {
        id: recentProc
        stdout: StdioCollector {
            onStreamFinished: win.recent = win.parseStat(text, false)
        }
    }
    function parseStat(text, withType) {
        return text.split("\n").filter(l => l).map(l => {
            const [p, size, mtime, type] = l.split("\t");
            return {
                name: p.split("/").pop(),
                path: p,
                isDir: withType ? type === "d" : false,
                size: parseInt(size) || 0,
                modified: new Date(parseFloat(mtime) * 1000)
            };
        });
    }

    // Поиск: по имени, вглубь от текущей папки
    property bool searching: false
    property var results: []
    property string searchRoot: Files.home
    Timer {
        id: searchTimer
        interval: 300
        onTriggered: {
            if (searchField.text.trim().length < 2) {
                win.results = [];
                return;
            }
            searchProc.running = false;
            searchProc.running = true;
        }
    }
    Process {
        id: searchProc
        command: ["sh", "-c", 'find "$1" -maxdepth 7 -not -path "*/.*" -iname "*$2*" -printf "%p\t%s\t%T@\t%y\n" 2>/dev/null | head -n 400', "sh", win.searchRoot, searchField.text.trim()]
        stdout: StdioCollector {
            onStreamFinished: win.results = win.parseStat(text, true)
        }
    }

    // Что показываем сейчас
    readonly property var shownDirs: place === "search" ? results.filter(r => r.isDir) : place === "recent" ? [] : dirs
    readonly property var shownFiles: {
        let f = place === "search" ? results.filter(r => !r.isDir) : place === "recent" ? recent : files;
        if (kindFilter)
            f = f.filter(x => Files.kindOf(x.name, false) === kindFilter);
        return f;
    }
    readonly property var allShown: [...shownDirs, ...shownFiles]

    Connections {
        target: Files
        function onChanged(dir) {
            if (win.place === "recent")
                win.loadRecent();
            if (win.place === "search")
                searchTimer.restart();
        }
    }

    // --- Выделение -------------------------------------------------------------
    property var selected: ({})
    property int anchor: -1
    readonly property var selectedPaths: Object.keys(selected).filter(k => selected[k])
    readonly property int selCount: selectedPaths.length
    function select(i, mods) {
        const item = allShown[i];
        if (!item)
            return;
        const s = (mods & Qt.ControlModifier) ? Object.assign({}, selected) : {};
        if ((mods & Qt.ShiftModifier) && anchor >= 0) {
            const [a, b] = [Math.min(anchor, i), Math.max(anchor, i)];
            for (let k = a; k <= b; k++)
                s[allShown[k].path] = true;
        } else if (mods & Qt.ControlModifier) {
            s[item.path] = !s[item.path];
            anchor = i;
        } else {
            s[item.path] = true;
            anchor = i;
        }
        selected = s;
    }
    function selectAll() {
        const s = {};
        for (const it of allShown)
            s[it.path] = true;
        selected = s;
    }
    function activate(item) {
        if (item.isDir)
            go(item.path);
        else if (place === "trash")
            return;
        else if (Files.isArchive(item.name))
            Files.openArchiveWindow(item.path);
        else if (Files.isAppImage(item.name) || Files.isScript(item.name))
            Files.launch(item.path);
        else
            Files.openFile(item.path);
    }

    // --- Архив как папка -------------------------------------------------------
    // archive — сам файл архива, archiveRoot — куда он распакован в кеше
    property string archive: ""
    property string archiveRoot: ""
    readonly property bool inArchive: archiveRoot !== "" && place === "dir" && (path === archiveRoot || path.startsWith(archiveRoot + "/"))
    function enterArchive(file) {
        Files.openArchive(file, (ok, dir) => {
            if (!ok)
                return;
            win.archive = file;
            win.archiveRoot = dir;
            win.go(dir);
        });
    }
    // Куда вставлять / создавать
    readonly property string here: place === "dir" && !inArchive ? path : ""

    // --- Клавиатура ------------------------------------------------------------
    Shortcut {
        sequence: "Alt+Left"
        onActivated: win.goBack()
    }
    Shortcut {
        sequence: "Alt+Right"
        onActivated: win.goForward()
    }
    Shortcut {
        sequences: ["Alt+Up", "Backspace"]
        enabled: !searchField.input.activeFocus && !dialog.visible
        onActivated: win.goUp()
    }
    Shortcut {
        sequence: "Ctrl+A"
        enabled: !searchField.input.activeFocus && !dialog.visible
        onActivated: win.selectAll()
    }
    Shortcut {
        sequence: "Ctrl+C"
        enabled: win.selCount > 0 && !dialog.visible
        onActivated: Files.setClipboard("copy", win.selectedPaths)
    }
    Shortcut {
        sequence: "Ctrl+X"
        enabled: win.selCount > 0 && !dialog.visible && win.place === "dir"
        onActivated: Files.setClipboard("cut", win.selectedPaths)
    }
    Shortcut {
        sequence: "Ctrl+V"
        enabled: win.here !== "" && !dialog.visible
        onActivated: Files.paste(win.here)
    }
    Shortcut {
        sequence: "Delete"
        enabled: win.selCount > 0 && !searchField.input.activeFocus && !dialog.visible
        onActivated: win.place === "trash" ? dialog.ask("delete") : Files.trash(win.selectedPaths)
    }
    Shortcut {
        sequence: "Shift+Delete"
        enabled: win.selCount > 0 && !dialog.visible
        onActivated: dialog.ask("delete")
    }
    Shortcut {
        sequence: "F2"
        enabled: win.selCount === 1 && !dialog.visible
        onActivated: dialog.ask("rename")
    }
    Shortcut {
        sequence: "Ctrl+H"
        onActivated: Settings.data.filesHidden = !Settings.data.filesHidden
    }
    Shortcut {
        sequence: "Ctrl+Shift+N"
        enabled: win.here !== ""
        onActivated: dialog.ask("mkdir")
    }
    Shortcut {
        sequences: ["Ctrl+F", "Ctrl+L"]
        onActivated: {
            win.searching = true;
            searchField.forceFocus();
        }
    }
    Shortcut {
        sequence: "Return"
        enabled: win.selCount > 0 && !searchField.input.activeFocus && !dialog.visible
        onActivated: {
            for (const p of win.selectedPaths) {
                const it = win.allShown.find(x => x.path === p);
                if (it)
                    win.activate(it);
            }
        }
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (menu.visible)
                menu.visible = false;
            else if (dialog.visible)
                dialog.visible = false;
            else if (win.searching) {
                win.searching = false;
                searchField.text = "";
                if (win.place === "search")
                    win.goBack();
            } else if (win.selCount)
                win.selected = {};
            else
                win.visible = false;
        }
    }
    Shortcut {
        sequence: "Ctrl+W"
        onActivated: win.visible = false
    }
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: Files.open(win.here || Files.home)
    }

    // ===========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // --- Боковая панель ----------------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: 248
            Layout.maximumWidth: 248
            Layout.fillHeight: true
            spacing: 4

            RowLayout {
                Layout.leftMargin: 12
                Layout.topMargin: 8
                Layout.bottomMargin: 12
                spacing: 12
                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: 12
                    color: Theme.primaryContainer
                    MIcon {
                        anchors.centerIn: parent
                        icon: "folder"
                        fill: 1
                        color: Theme.fgPrimaryContainer
                    }
                }
                MText {
                    text: "Файлы"
                    size: Theme.type.titleL
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: nav.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: nav
                    width: parent.width
                    spacing: 2

                    NavItem {
                        icon: "schedule"
                        text: "Недавние"
                        active: win.place === "recent"
                        onClicked: win.go("::recent")
                    }
                    NavHeader {
                        text: "Мои файлы"
                    }
                    Repeater {
                        model: Files.places
                        NavItem {
                            required property var modelData
                            icon: modelData.icon
                            text: modelData.name
                            active: win.place === "dir" && win.path === modelData.path
                            dropPath: modelData.path
                            onClicked: win.go(modelData.path)
                        }
                    }
                    NavHeader {
                        visible: Files.bookmarks.length > 0
                        text: "Закладки"
                    }
                    Repeater {
                        model: Files.bookmarks
                        NavItem {
                            required property var modelData
                            icon: "bookmark"
                            text: modelData.name
                            active: win.place === "dir" && win.path === modelData.path
                            dropPath: modelData.path
                            onClicked: win.go(modelData.path)
                            onRightClicked: Files.removeBookmark(modelData.path)
                            hint: "ПКМ — убрать из закладок"
                        }
                    }
                    NavHeader {
                        text: "Устройства"
                    }
                    NavItem {
                        icon: "computer"
                        text: "Компьютер"
                        active: win.place === "dir" && win.path === "/"
                        onClicked: win.go("/")
                    }
                    Repeater {
                        model: Files.drives
                        NavItem {
                            required property var modelData
                            icon: modelData.icon
                            text: modelData.name
                            hint: modelData.size
                            active: win.place === "dir" && win.path === modelData.path
                            dropPath: modelData.path
                            onClicked: win.go(modelData.path)
                        }
                    }
                    // Сеть: подключённые папки, сохранённые и «Подключиться»
                    NavHeader {
                        text: "Сеть"
                    }
                    Repeater {
                        model: Files.mounts
                        NavItem {
                            required property var modelData
                            icon: modelData.icon
                            text: modelData.name
                            hint: "ПКМ — отключить"
                            active: win.place === "dir" && (win.path === modelData.path || win.path.startsWith(modelData.path + "/"))
                            dropPath: modelData.path
                            onClicked: win.go(modelData.path)
                            onRightClicked: {
                                if (win.path.startsWith(modelData.path))
                                    win.go(Files.home);
                                Files.disconnect(modelData.path);
                            }
                        }
                    }
                    Repeater {
                        // сохранённые, но сейчас не подключённые
                        model: Settings.data.netPlaces.filter(n => !Files.mounts.some(m => m.name && n.uri.includes(m.name.split(" на ")[0])))
                        NavItem {
                            required property var modelData
                            icon: "link"
                            text: modelData.uri.replace(/^[a-z]+:\/\//, "")
                            hint: "ПКМ — забыть"
                            onClicked: dialog.askConnect(modelData.uri, modelData.user ?? "")
                            onRightClicked: Files.forgetPlace(modelData.uri)
                        }
                    }
                    NavItem {
                        icon: "add_link"
                        text: "Подключиться к серверу"
                        onClicked: dialog.askConnect("", "")
                    }
                    Item {
                        implicitHeight: 8
                    }
                    NavItem {
                        icon: "delete"
                        text: "Корзина"
                        active: win.place === "trash"
                        onClicked: win.go(Files.trashDir)
                    }
                }
            }

            // Место на диске текущей папки
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: diskCol.implicitHeight + 24
                radius: Theme.radius.l
                color: Theme.surfaceContainerHigh
                visible: win.disk.total > 0
                ColumnLayout {
                    id: diskCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 14
                    spacing: 8
                    MText {
                        Layout.fillWidth: true
                        text: "Свободно " + Files.humanSize(win.disk.free) + " из " + Files.humanSize(win.disk.total)
                        size: Theme.type.bodyS
                        color: Theme.fgSurfaceVariant
                    }
                    LinearProgress {
                        Layout.fillWidth: true
                        thickness: 6
                        value: 1 - win.disk.free / Math.max(1, win.disk.total)
                    }
                }
            }
        }

        // --- Карточка содержимого ---------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius.xl
            color: Theme.surface
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Шапка: путь и инструменты — или панель выделения
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 52

                    RowLayout {
                        anchors.fill: parent
                        visible: win.selCount === 0
                        spacing: 4

                        IconButton {
                            icon: "arrow_back"
                            tooltip: "Назад"
                            opacity: win.back.length ? 1 : 0.38
                            onClicked: win.goBack()
                        }
                        IconButton {
                            icon: "arrow_forward"
                            tooltip: "Вперёд"
                            opacity: win.forward.length ? 1 : 0.38
                            onClicked: win.goForward()
                        }

                        // Хлебные крошки
                        Flickable {
                            id: crumbsFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: !win.searching
                            contentWidth: crumbs.implicitWidth
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            onContentWidthChanged: contentX = Math.max(0, contentWidth - width)
                            Row {
                                id: crumbs
                                height: parent.height
                                spacing: 0
                                readonly property var parts: {
                                    if (win.place !== "dir")
                                        return [
                                            {
                                                label: win.title_,
                                                path: ""
                                            }
                                        ];
                                    const p = win.path;
                                    const home = Files.home;
                                    const out = [];
                                    let base, rest;
                                    if (win.inArchive) {
                                        out.push({
                                            label: win.archive.split("/").pop(),
                                            path: win.archiveRoot
                                        });
                                        base = win.archiveRoot;
                                        rest = p.slice(base.length);
                                    } else if (p === home || p.startsWith(home + "/")) {
                                        out.push({
                                            label: "Мои файлы",
                                            path: home
                                        });
                                        base = home;
                                        rest = p.slice(home.length);
                                    } else {
                                        out.push({
                                            label: "Компьютер",
                                            path: "/"
                                        });
                                        base = "";
                                        rest = p === "/" ? "" : p;
                                    }
                                    for (const seg of rest.split("/").filter(s => s)) {
                                        base += "/" + seg;
                                        out.push({
                                            label: win.displayName(base) === seg ? seg : win.displayName(base),
                                            path: base
                                        });
                                    }
                                    return out;
                                }
                                Repeater {
                                    model: crumbs.parts
                                    Row {
                                        id: crumb
                                        required property var modelData
                                        required property int index
                                        readonly property bool last: index === crumbs.parts.length - 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        MIcon {
                                            visible: crumb.index > 0
                                            anchors.verticalCenter: parent.verticalCenter
                                            icon: "chevron_right"
                                            size: 20
                                            color: Theme.fgSurfaceVariant
                                        }
                                        Rectangle {
                                            implicitWidth: crumbText.implicitWidth + 20
                                            implicitHeight: 36
                                            radius: 18
                                            color: "transparent"
                                            MText {
                                                id: crumbText
                                                anchors.centerIn: parent
                                                text: crumb.modelData.label
                                                size: crumb.last ? Theme.type.titleM : Theme.type.bodyL
                                                weight: crumb.last ? Theme.strongWeight : Theme.fontWeight
                                                color: crumb.last ? Theme.fgSurface : Theme.fgSurfaceVariant
                                            }
                                            StateLayer {
                                                visible: !crumb.last && crumb.modelData.path !== ""
                                                onClicked: win.go(crumb.modelData.path)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: win.searching
                            Layout.preferredWidth: win.searching ? -1 : 0
                            visible: win.searching
                            implicitHeight: 44
                            icon: "search"
                            placeholder: "Поиск в «" + (win.place === "dir" ? win.displayName(win.searchRoot) : "Мои файлы") + "»"
                            onTextChanged: {
                                if (text.trim().length >= 2 && win.place !== "search") {
                                    win.searchRoot = win.place === "dir" ? win.path : Files.home;
                                    const b = win.back;
                                    win.back = [...b, win.place === "dir" || win.place === "trash" ? win.path : "::" + win.place];
                                    win.place = "search";
                                    win.selected = {};
                                }
                                searchTimer.restart();
                            }
                        }
                        IconButton {
                            icon: win.searching ? "close" : "search"
                            tooltip: "Поиск"
                            onClicked: {
                                if (win.searching) {
                                    win.searching = false;
                                    searchField.text = "";
                                    if (win.place === "search")
                                        win.goBack();
                                } else {
                                    win.searchRoot = win.place === "dir" ? win.path : Files.home;
                                    win.searching = true;
                                    searchField.forceFocus();
                                }
                            }
                        }
                        IconButton {
                            icon: win.view === "grid" ? "view_list" : "grid_view"
                            tooltip: win.view === "grid" ? "Списком" : "Сеткой"
                            onClicked: Settings.data.filesView = win.view === "grid" ? "list" : "grid"
                        }
                        IconButton {
                            id: sortBtn
                            icon: "sort"
                            tooltip: "Сортировка"
                            onClicked: menu.openSort(sortBtn)
                        }
                        IconButton {
                            id: moreBtn
                            icon: "more_vert"
                            onClicked: menu.openMore(moreBtn)
                        }
                    }

                    // Панель выделения
                    Rectangle {
                        anchors.fill: parent
                        visible: win.selCount > 0
                        radius: height / 2
                        color: Theme.secondaryContainer
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            spacing: 2
                            IconButton {
                                icon: "close"
                                iconColor: Theme.fgSecondaryContainer
                                onClicked: win.selected = {}
                            }
                            MText {
                                Layout.fillWidth: true
                                text: "Выбрано: " + win.selCount
                                size: Theme.type.titleM
                                color: Theme.fgSecondaryContainer
                            }
                            SelAction {
                                visible: win.place !== "trash"
                                icon: "content_copy"
                                tooltip: "Копировать (Ctrl+C)"
                                onClicked: Files.setClipboard("copy", win.selectedPaths)
                            }
                            SelAction {
                                visible: win.place === "dir"
                                icon: "content_cut"
                                tooltip: "Вырезать (Ctrl+X)"
                                onClicked: Files.setClipboard("cut", win.selectedPaths)
                            }
                            SelAction {
                                visible: win.selCount === 1 && win.place !== "trash"
                                icon: "edit"
                                tooltip: "Переименовать (F2)"
                                onClicked: dialog.ask("rename")
                            }
                            SelAction {
                                visible: win.place === "trash"
                                icon: "restore_from_trash"
                                tooltip: "Восстановить"
                                onClicked: {
                                    Files.restore(win.selectedPaths);
                                    win.selected = {};
                                }
                            }
                            SelAction {
                                icon: win.place === "trash" ? "delete_forever" : "delete"
                                tooltip: win.place === "trash" ? "Удалить навсегда" : "В корзину (Delete)"
                                onClicked: {
                                    if (win.place === "trash")
                                        dialog.ask("delete");
                                    else {
                                        Files.trash(win.selectedPaths);
                                        win.selected = {};
                                    }
                                }
                            }
                            SelAction {
                                id: selMore
                                icon: "more_vert"
                                onClicked: menu.openFor(null, selMore)
                            }
                        }
                    }
                }

                // Фильтры «Недавних» — чипы, как на ChromeOS
                Row {
                    visible: win.place === "recent"
                    spacing: 8
                    Repeater {
                        model: [
                            {
                                value: "",
                                label: "Все"
                            },
                            {
                                value: "image",
                                label: "Изображения"
                            },
                            {
                                value: "video",
                                label: "Видео"
                            },
                            {
                                value: "audio",
                                label: "Аудио"
                            },
                            {
                                value: "document",
                                label: "Документы"
                            }
                        ]
                        FilterChip {
                            required property var modelData
                            text: modelData.label
                            on: win.kindFilter === modelData.value
                            onClicked: win.kindFilter = modelData.value
                        }
                    }
                }
                // Архив: содержимое и «Распаковать»
                Rectangle {
                    Layout.fillWidth: true
                    visible: win.inArchive
                    implicitHeight: 56
                    radius: 28
                    color: Theme.secondaryContainer
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 8
                        spacing: 12
                        MIcon {
                            icon: "folder_zip"
                            color: Theme.fgSecondaryContainer
                        }
                        MText {
                            Layout.fillWidth: true
                            text: "Содержимое архива. Перетащи файлы куда нужно или распакуй целиком"
                            color: Theme.fgSecondaryContainer
                        }
                        Button {
                            variant: "text"
                            text: "Папка архива"
                            onClicked: win.go(win.archive.slice(0, win.archive.lastIndexOf("/")) || "/")
                        }
                        Button {
                            icon: "unarchive"
                            text: "Распаковать сюда"
                            onClicked: {
                                Files.extract(win.archive);
                                win.go(win.archive.slice(0, win.archive.lastIndexOf("/")) || "/");
                            }
                        }
                    }
                }

                // Корзина: очистить
                RowLayout {
                    visible: win.place === "trash" && win.allShown.length > 0
                    Layout.fillWidth: true
                    MText {
                        Layout.fillWidth: true
                        text: "Файлы в корзине можно восстановить, пока она не очищена"
                        color: Theme.fgSurfaceVariant
                    }
                    Button {
                        variant: "tonal"
                        icon: "delete_sweep"
                        text: "Очистить корзину"
                        onClicked: dialog.ask("empty")
                    }
                }

                LinearProgress {
                    Layout.fillWidth: true
                    visible: Files.busy > 0 || searchProc.running || recentProc.running || dirsModel.status === FolderListModel.Loading
                    thickness: 4
                    value: -1
                }

                // --- Сетка / список ---------------------------------------------
                Item {
                    id: contentArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Клик по пустому месту — снять выделение; ПКМ — меню папки
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            win.selected = {};
                            if (event.button === Qt.RightButton)
                                menu.openAt(null, contentArea, event.x, event.y);
                        }
                    }

                    // Сетка: группа папок и группа файлов. Это ListView из рядов
                    // (подпись, ряд папок, ряд файлов): создаются только видимые
                    // ряды — и для папок тоже, а не все сразу.
                    ListView {
                        id: grid
                        anchors.fill: parent
                        visible: win.view === "grid"
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        readonly property int dirCols: Math.max(1, Math.floor(width / 220))
                        readonly property int fileCols: Math.max(1, Math.floor(width / 176))
                        readonly property real dirWidth: (width - (dirCols - 1) * 8) / dirCols
                        readonly property real fileCell: Math.floor(width / fileCols)
                        // { label } | { dirs: true|false, start, items }
                        readonly property var rows: {
                            if (win.view !== "grid")
                                return [];
                            const out = [];
                            const d = win.shownDirs, f = win.shownFiles;
                            if (d.length) {
                                out.push({
                                    label: "Папки"
                                });
                                for (let i = 0; i < d.length; i += dirCols)
                                    out.push({
                                        dirs: true,
                                        start: i,
                                        items: d.slice(i, i + dirCols)
                                    });
                            }
                            if (f.length) {
                                out.push({
                                    label: "Файлы"
                                });
                                for (let i = 0; i < f.length; i += fileCols)
                                    out.push({
                                        dirs: false,
                                        start: d.length + i,
                                        items: f.slice(i, i + fileCols)
                                    });
                            }
                            return out;
                        }
                        model: rows
                        readonly property int cellHeight: 196
                        delegate: Item {
                            id: gridRow
                            required property var modelData
                            readonly property bool isLabel: modelData.label !== undefined
                            width: grid.width
                            height: isLabel ? rowLabel.implicitHeight + 12 : modelData.dirs ? 64 : grid.cellHeight
                            SectionLabel {
                                id: rowLabel
                                x: 8
                                y: 4
                                visible: gridRow.isLabel
                                text: gridRow.modelData.label ?? ""
                            }
                            Row {
                                spacing: 8
                                visible: !gridRow.isLabel && gridRow.modelData.dirs
                                Repeater {
                                    model: !gridRow.isLabel && gridRow.modelData.dirs ? gridRow.modelData.items : []
                                    FolderTile {
                                        required property var modelData
                                        required property int index
                                        width: grid.dirWidth
                                        height: 56
                                        item: modelData
                                        idx: gridRow.modelData.start + index
                                    }
                                }
                            }
                            Row {
                                visible: !gridRow.isLabel && !gridRow.modelData.dirs
                                Repeater {
                                    model: !gridRow.isLabel && !gridRow.modelData.dirs ? gridRow.modelData.items : []
                                    Item {
                                        id: fileSlot
                                        required property var modelData
                                        required property int index
                                        width: grid.fileCell
                                        height: grid.cellHeight
                                        FileCard {
                                            width: fileSlot.width - 8
                                            height: fileSlot.height - 8
                                            item: fileSlot.modelData
                                            idx: gridRow.modelData.start + fileSlot.index
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Список
                    ListView {
                        id: list
                        anchors.fill: parent
                        visible: win.view === "list"
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.view === "list" ? win.allShown : []
                        spacing: 2
                        header: RowLayout {
                            width: list.width
                            height: 36
                            spacing: 12
                            Item {
                                implicitWidth: 40
                            }
                            ColHead {
                                Layout.fillWidth: true
                                text: "Имя"
                                key: "name"
                            }
                            ColHead {
                                Layout.preferredWidth: 110
                                text: "Размер"
                                key: "size"
                            }
                            ColHead {
                                Layout.preferredWidth: 120
                                text: "Тип"
                                key: "type"
                            }
                            ColHead {
                                Layout.preferredWidth: 150
                                text: "Изменён"
                                key: "time"
                            }
                        }
                        delegate: ListRow {
                            required property var modelData
                            required property int index
                            width: list.width
                            item: modelData
                            idx: index
                        }
                    }

                    // Пусто
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: win.allShown.length === 0 && dirsModel.status !== FolderListModel.Loading && !searchProc.running && !recentProc.running
                        spacing: 12
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 120
                            implicitHeight: 120
                            radius: 60
                            color: Theme.surfaceContainerHigh
                            MIcon {
                                anchors.centerIn: parent
                                icon: win.place === "trash" ? "delete" : win.place === "search" ? "search_off" : win.place === "recent" ? "schedule" : "folder_open"
                                size: 56
                                color: Theme.fgSurfaceVariant
                            }
                        }
                        MText {
                            Layout.alignment: Qt.AlignHCenter
                            text: win.place === "trash" ? "Корзина пуста" : win.place === "search" ? (searchField.text.trim().length < 2 ? "Введите хотя бы два символа" : "Ничего не нашлось") : win.place === "recent" ? "Пока нет недавних файлов" : "Папка пуста"
                            size: Theme.type.titleM
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    // Перетаскивание из других приложений — копировать сюда
                    DropArea {
                        anchors.fill: parent
                        enabled: win.here !== ""
                        keys: ["text/uri-list"]
                        onDropped: drop => {
                            // своё же из этого окна — не копировать (из архиватора — можно)
                            if (drop.source && drop.source.isFileItem && !drop.source.fromArchive)
                                return;
                            const paths = drop.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")));
                            if (paths.length) {
                                Files.transfer(paths, win.here, false);
                                drop.accept(Qt.CopyAction);
                            }
                        }
                    }
                }

                MText {
                    Layout.fillWidth: true
                    visible: Files.lastError !== ""
                    text: Files.lastError
                    color: Theme.error
                    size: Theme.type.bodyS
                }
            }
        }
    }

    // Свободное место — df по текущей папке
    property var disk: ({
            free: 0,
            total: 0
        })
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=avail,size", win.place === "dir" ? win.path : Files.home]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")[1];
                if (!l)
                    return;
                const [a, s] = l.trim().split(/\s+/).map(Number);
                win.disk = {
                    free: a,
                    total: s
                };
            }
        }
    }
    Component.onCompleted: {
        dfProc.running = true;
        Files.refreshDrives();
        if (entry.archive)
            enterArchive(entry.archive);
    }

    // ===========================================================================
    // Элементы

    component NavHeader: MText {
        Layout.leftMargin: 16
        Layout.topMargin: 14
        Layout.bottomMargin: 4
        size: Theme.type.labelL
        weight: Theme.strongWeight
        color: Theme.fgSurfaceVariant
    }
    component NavItem: Rectangle {
        id: ni
        property string icon
        property string text
        property string hint: ""
        property bool active: false
        property string dropPath: ""
        signal clicked
        signal rightClicked
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 24
        color: active ? Theme.secondaryContainer : dropHere.containsDrag ? Theme.alpha(Theme.primary, 0.12) : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14
            MIcon {
                icon: ni.icon
                fill: ni.active ? 1 : 0
                color: ni.active ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
            }
            MText {
                Layout.fillWidth: true
                text: ni.text
                weight: ni.active ? Theme.strongWeight : Theme.fontWeight
                color: ni.active ? Theme.fgSecondaryContainer : Theme.fgSurface
            }
        }
        StateLayer {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: event => event.button === Qt.RightButton ? ni.rightClicked() : ni.clicked()
        }
        // перетащить файлы на раздел — переместить туда
        DropArea {
            id: dropHere
            anchors.fill: parent
            enabled: ni.dropPath !== ""
            keys: ["text/uri-list"]
            onDropped: drop => win.dropInto(ni.dropPath, drop)
        }
    }

    function dropInto(dir, drop) {
        const paths = drop.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(p => p !== dir);
        if (!paths.length)
            return;
        // внутри «Файлов» — переместить (из архива — скопировать), извне — скопировать
        const internal = drop.source && drop.source.isFileItem && !drop.source.fromArchive && !win.inArchive;
        Files.transfer(paths, dir, internal);
        drop.accept(internal ? Qt.MoveAction : Qt.CopyAction);
        win.selected = {};
    }

    component SectionLabel: MText {
        Layout.leftMargin: 8
        Layout.topMargin: 4
        size: Theme.type.titleS
        weight: Theme.strongWeight
        color: Theme.fgSurfaceVariant
    }
    component SelAction: IconButton {
        iconColor: Theme.fgSecondaryContainer
    }
    component FilterChip: Rectangle {
        id: fc
        property string text
        property bool on
        signal clicked
        implicitHeight: 32
        implicitWidth: fcRow.implicitWidth + 24
        radius: Theme.radius.s
        color: on ? Theme.secondaryContainer : "transparent"
        border.width: on ? 0 : 1
        border.color: Theme.outlineVariant
        Row {
            id: fcRow
            anchors.centerIn: parent
            spacing: 6
            MIcon {
                visible: fc.on
                icon: "check"
                size: 18
                color: Theme.fgSecondaryContainer
            }
            MText {
                text: fc.text
                size: Theme.type.labelL
                color: fc.on ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
            }
        }
        StateLayer {
            radius: fc.radius
            onClicked: fc.clicked()
        }
    }
    component ColHead: Item {
        id: ch
        property string text
        property string key
        implicitHeight: 36
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            MText {
                text: ch.text
                size: Theme.type.labelL
                weight: win.sortBy === ch.key ? Theme.strongWeight : Theme.fontWeight
                color: win.sortBy === ch.key ? Theme.primary : Theme.fgSurfaceVariant
            }
            MIcon {
                visible: win.sortBy === ch.key
                icon: win.sortDesc ? "arrow_downward" : "arrow_upward"
                size: 16
                color: Theme.primary
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (win.sortBy === ch.key)
                    Settings.data.filesSortDesc = !Settings.data.filesSortDesc;
                else
                    Settings.data.filesSort = ch.key;
            }
        }
    }

    // Общее у плитки, карточки и строки: выделение, открытие, меню, перетаскивание
    component FileItem: Rectangle {
        id: fi
        property var item
        property int idx
        readonly property bool isFileItem: true
        readonly property bool sel: !!win.selected[item?.path]
        readonly property bool hovered: fma.containsMouse
        readonly property bool cut: Files.clipboard.mode === "cut" && Files.clipboard.paths.includes(item?.path)
        opacity: cut ? 0.5 : 1

        // Перетаскивание наружу — стандартный для Qt Quick способ: MouseArea
        // тянет невидимого «посредника» (drag.target), и пока он едет,
        // Drag.active у него включает системное перетаскивание (Drag.Automatic).
        Item {
            id: dragProxy
            readonly property bool isFileItem: true
            width: 1
            height: 1
            Drag.active: fma.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
            Drag.proposedAction: Qt.CopyAction
            Drag.mimeData: ({
                    "text/uri-list": (fi.sel ? win.selectedPaths : [fi.item?.path ?? ""]).map(p => "file://" + encodeURI(p)).join("\r\n")
                })
        }

        MouseArea {
            id: fma
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // иначе GridView/ListView забирает движение мыши себе как прокрутку,
            // и перетаскивание файла даже не начинается
            preventStealing: true
            drag.target: dragProxy
            drag.threshold: 10
            property bool dragged: false
            onPressed: event => {
                dragged = false;
                dragProxy.x = event.x;
                dragProxy.y = event.y;
                // картинка под курсором при перетаскивании
                fi.grabToImage(r => dragProxy.Drag.imageSource = r.url, Qt.size(Math.min(fi.width, 220), Math.min(fi.height, 220)));
                if (event.button === Qt.RightButton) {
                    if (!fi.sel)
                        win.select(fi.idx, 0);
                    menu.openAt(fi.item, fi, event.x, event.y);
                } else if (!fi.sel || (event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)))
                    win.select(fi.idx, event.modifiers);
            }
            onReleased: event => {
                // клик по уже выделенному без перетаскивания — оставить только его
                if (!dragged && event.button === Qt.LeftButton && fi.sel && !(event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && win.selCount > 1)
                    win.select(fi.idx, 0);
            }
            onPositionChanged: if (drag.active)
                dragged = true
            onDoubleClicked: event => {
                if (event.button === Qt.LeftButton)
                    win.activate(fi.item);
            }
        }
    }

    component FolderTile: FileItem {
        id: ft
        implicitHeight: 56
        radius: 16
        color: sel ? Theme.primaryContainer : dropFolder.containsDrag ? Theme.alpha(Theme.primary, 0.16) : hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12
            MIcon {
                // у стандартных папок свой значок и русское имя, как в боковой панели
                icon: {
                    const pl = Files.places.find(p => p.path === ft.item.path && p.path !== Files.home);
                    return pl ? pl.icon : "folder";
                }
                fill: 1
                color: ft.sel ? Theme.fgPrimaryContainer : Theme.primary
            }
            MText {
                Layout.fillWidth: true
                text: Files.places.some(p => p.path === ft.item.path) ? win.displayName(ft.item.path) : ft.item.name
                color: ft.sel ? Theme.fgPrimaryContainer : Theme.fgSurface
            }
        }
        DropArea {
            id: dropFolder
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: drop => win.dropInto(ft.item.path, drop)
        }
    }

    component FileCard: FileItem {
        id: fcd
        readonly property string kind: Files.kindOf(item.name, false)
        radius: 16
        color: sel ? Theme.primaryContainer : hovered ? Theme.surfaceContainerHigh : "transparent"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            // Превью: картинка, кадр видео или значок типа
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Theme.surfaceContainerHighest
                clip: true
                Thumb {
                    anchors.fill: parent
                    item: fcd.item
                    kind: fcd.kind
                    iconSize: 56
                }
            }
            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: fcd.item.name
                size: Theme.type.bodyM
                color: fcd.sel ? Theme.fgPrimaryContainer : Theme.fgSurface
                elide: Text.ElideMiddle
            }
            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.topMargin: -6
                text: Files.humanSize(fcd.item.size) + " · " + Files.humanDate(fcd.item.modified)
                size: Theme.type.bodyS
                color: fcd.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
        }
    }

    component ListRow: FileItem {
        id: lr
        implicitHeight: 52
        radius: 26
        color: sel ? Theme.primaryContainer : hovered ? Theme.surfaceContainerHigh : "transparent"
        readonly property string kind: Files.kindOf(item.name, item.isDir)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 12
            spacing: 12
            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 10
                color: "transparent"
                clip: true
                Thumb {
                    anchors.fill: parent
                    item: lr.item
                    kind: lr.kind
                    iconSize: 32
                }
            }
            MText {
                Layout.fillWidth: true
                text: lr.item.name
                elide: Text.ElideMiddle
                color: lr.sel ? Theme.fgPrimaryContainer : Theme.fgSurface
            }
            MText {
                Layout.preferredWidth: 110
                text: lr.item.isDir ? "—" : Files.humanSize(lr.item.size)
                color: lr.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
            MText {
                Layout.preferredWidth: 120
                text: Files.kindLabel(lr.kind)
                color: lr.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
            MText {
                Layout.preferredWidth: 150
                text: Files.humanDate(lr.item.modified)
                color: lr.sel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
        }
        DropArea {
            anchors.fill: parent
            enabled: lr.item.isDir
            keys: ["text/uri-list"]
            onDropped: drop => win.dropInto(lr.item.path, drop)
        }
    }

    // Превью файла: изображение, кадр видео (кешируется) или значок темы
    component Thumb: Item {
        id: th
        property var item
        property string kind
        property real iconSize: 48
        readonly property bool media: kind === "image" || kind === "video"
        // Видео: кадр из кеша; нет его — встаём в очередь Thumbs
        readonly property string key: kind === "video" ? Thumbs.keyFor(item.path, item.modified) : ""
        property int rev: 0
        Connections {
            target: th.kind === "video" ? Thumbs : null
            function onReady(k) {
                if (k === th.key)
                    th.rev++;
            }
        }
        Component.onDestruction: if (key)
            Thumbs.cancel(key)
        Image {
            id: thImg
            anchors.fill: parent
            visible: th.media && status === Image.Ready
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(320, 320)
            source: th.kind === "image" ? "file://" + encodeURI(th.item.path) : th.key ? Thumbs.urlFor(th.key) + (th.rev ? "?r=" + th.rev : "") : ""
            onStatusChanged: if (status === Image.Error && th.key)
                Thumbs.make(th.item.path, th.key)
        }
        AppIcon {
            anchors.centerIn: parent
            visible: !thImg.visible
            styled: false
            size: th.iconSize
            icon: Files.iconFor(th.item.name, th.item.path, th.item.isDir)
        }
        Rectangle {
            visible: th.kind === "video" && thImg.visible
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            width: 24
            height: 24
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.55)
            MIcon {
                anchors.centerIn: parent
                icon: "play_arrow"
                fill: 1
                size: 18
                color: "white"
            }
        }
    }

    // ===========================================================================
    // Меню (контекстное, сортировка, «ещё») — карточка M3 внутри окна

    Item {
        id: menu
        anchors.fill: parent
        visible: false
        z: 50
        property var target: null // элемент или null (папка)
        property var entries: []
        property real mx: 0
        property real my: 0
        property var apps: []
        property bool appsLoaded: false
        property bool allApps: false

        function show(src, x, y, list) {
            const p = src.mapToItem(menu, x, y);
            mx = p.x;
            my = p.y;
            entries = list;
            visible = true;
        }
        // Для файла сначала узнаём, исполняемый ли он и есть ли в меню приложений
        function openAt(item, src, x, y) {
            const sel = win.selectedPaths;
            const one = sel.length === 1 ? win.allShown.find(i => i.path === sel[0]) : null;
            if (item && one && !one.isDir && win.place !== "trash")
                Files.inspect(one.path, (ex, inMenu) => build(item, src, x, y, {
                        exec: ex,
                        inMenu
                    }));
            else
                build(item, src, x, y, null);
        }
        function build(item, src, x, y, info) {
            target = item;
            const sel = win.selectedPaths;
            const one = sel.length === 1 ? win.allShown.find(i => i.path === sel[0]) : null;
            // программа или скрипт: AppImage, .sh и т.п., файл без расширения или уже исполняемый
            const runnable = one && info && (info.exec || Files.isAppImage(one.name) || Files.isScript(one.name) || !one.name.includes("."));
            let l = [];
            if (item) {
                if (win.place === "trash") {
                    l = [
                        {
                            icon: "restore_from_trash",
                            text: "Восстановить",
                            act: () => {
                                Files.restore(sel);
                                win.selected = {};
                            }
                        },
                        {
                            icon: "delete_forever",
                            text: "Удалить навсегда",
                            act: () => dialog.ask("delete")
                        }
                    ];
                } else {
                    l.push({
                        icon: "open_in_new",
                        text: "Открыть",
                        act: () => sel.forEach(p => win.activate(win.allShown.find(i => i.path === p)))
                    });
                    if (runnable)
                        l.push({
                            icon: "play_arrow",
                            text: "Запустить",
                            act: () => Files.launch(one.path)
                        });
                    if (one && !one.isDir)
                        l.push({
                            icon: "apps",
                            text: "Открыть с помощью…",
                            act: () => dialog.ask("openwith")
                        });
                    if (one && Files.isArchive(one.name))
                        l.push({
                            icon: "folder_open",
                            text: "Открыть как папку",
                            act: () => win.enterArchive(one.path)
                        });
                    if (one && one.isDir) {
                        l.push({
                            icon: "tab",
                            text: "Открыть в новом окне",
                            act: () => Files.open(one.path)
                        });
                        l.push({
                            icon: "terminal",
                            text: "Открыть в терминале",
                            act: () => Files.openTerminal(one.path)
                        });
                    }
                    if (one && win.place === "search")
                        l.push({
                            icon: "folder_open",
                            text: "Показать в папке",
                            act: () => win.go(one.path.slice(0, one.path.lastIndexOf("/")) || "/")
                        });
                    l.push({
                        sep: true
                    });
                    l.push({
                        icon: "content_copy",
                        text: "Копировать",
                        key: "Ctrl+C",
                        act: () => Files.setClipboard("copy", sel)
                    });
                    if (win.place === "dir")
                        l.push({
                            icon: "content_cut",
                            text: "Вырезать",
                            key: "Ctrl+X",
                            act: () => Files.setClipboard("cut", sel)
                        });
                    if (one)
                        l.push({
                            icon: "edit",
                            text: "Переименовать",
                            key: "F2",
                            act: () => dialog.ask("rename")
                        });
                    if (one && one.isDir)
                        l.push({
                            icon: "bookmark_add",
                            text: "Добавить в закладки",
                            act: () => Files.addBookmark(one.path)
                        });
                    if (runnable) {
                        l.push({
                            icon: info.inMenu ? "playlist_remove" : "add_to_home_screen",
                            text: info.inMenu ? "Убрать из меню приложений" : "Добавить в меню приложений",
                            act: () => info.inMenu ? Files.removeFromMenu(one.path) : Files.addToMenu(one.path)
                        });
                        l.push({
                            icon: info.exec ? "block" : "verified",
                            text: info.exec ? "Запретить выполнение" : "Разрешить выполнение",
                            act: () => Files.setExecutable(one.path, !info.exec)
                        });
                    }
                    if (one && Files.isArchive(one.name))
                        l.push({
                            icon: "unarchive",
                            text: "Распаковать сюда",
                            act: () => Files.extract(one.path, win.inArchive ? "" : win.path)
                        });
                    else if (win.place === "dir" && !win.inArchive)
                        l.push({
                            icon: "folder_zip",
                            text: "Сжать в архив",
                            act: () => Files.compress(sel, win.path)
                        });
                    if (one && one.path.match(/\.(png|jpe?g|webp)$/i))
                        l.push({
                            icon: "wallpaper",
                            text: "Сделать обоями",
                            act: () => Wallpapers.apply(one.path)
                        });
                    l.push({
                        sep: true
                    });
                    l.push({
                        icon: "delete",
                        text: "В корзину",
                        key: "Delete",
                        act: () => {
                            Files.trash(sel);
                            win.selected = {};
                        }
                    });
                    l.push({
                        icon: "info",
                        text: "Свойства",
                        act: () => dialog.ask("info")
                    });
                }
            } else {
                l = folderEntries();
            }
            show(src, x, y, l);
        }
        function folderEntries() {
            const l = [];
            if (win.here) {
                l.push({
                    icon: "create_new_folder",
                    text: "Новая папка",
                    key: "Ctrl+Shift+N",
                    act: () => dialog.ask("mkdir")
                });
                // из буфера: файлы или картинка (скриншот сохранится файлом)
                l.push({
                    icon: "content_paste",
                    text: Files.clipboard.paths.length ? "Вставить (" + Files.clipboard.paths.length + ")" : "Вставить",
                    key: "Ctrl+V",
                    act: () => Files.paste(win.here)
                });
                l.push({
                    icon: "terminal",
                    text: "Открыть в терминале",
                    act: () => Files.openTerminal(win.here)
                });
                l.push({
                    icon: "bookmark_add",
                    text: "Добавить в закладки",
                    act: () => Files.addBookmark(win.here)
                });
            }
            l.push({
                icon: "select_all",
                text: "Выбрать всё",
                key: "Ctrl+A",
                act: () => win.selectAll()
            });
            return l;
        }
        function openFor(item, src) {
            openAt(win.allShown.find(i => i.path === win.selectedPaths[0]) ?? null, src, 0, src.height);
        }
        function openSort(src) {
            target = null;
            const opt = (key, label) => ({
                        icon: win.sortBy === key ? "check" : "",
                        text: label,
                        act: () => Settings.data.filesSort = key
                    });
            show(src, 0, src.height, [opt("name", "По имени"), opt("time", "По дате изменения"), opt("size", "По размеру"), opt("type", "По типу"),
                {
                    sep: true
                },
                {
                    icon: win.sortDesc ? "arrow_downward" : "arrow_upward",
                    text: win.sortDesc ? "По убыванию" : "По возрастанию",
                    act: () => Settings.data.filesSortDesc = !Settings.data.filesSortDesc
                }
            ]);
        }
        function openMore(src) {
            target = null;
            const l = folderEntries();
            l.push({
                sep: true
            });
            l.push({
                icon: win.showHidden ? "visibility_off" : "visibility",
                text: win.showHidden ? "Скрыть скрытые файлы" : "Показать скрытые файлы",
                key: "Ctrl+H",
                act: () => Settings.data.filesHidden = !Settings.data.filesHidden
            });
            l.push({
                icon: "open_in_new",
                text: "Новое окно",
                key: "Ctrl+N",
                act: () => Files.open(win.here || Files.home)
            });
            show(src, src.width, src.height, l);
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: menu.visible = false
        }
        Rectangle {
            id: menuCard
            x: Math.min(menu.mx, menu.width - width - 8)
            y: menu.my + height > menu.height - 8 ? Math.max(8, menu.my - height) : menu.my
            width: 320
            height: menuCol.implicitHeight + 16
            radius: Theme.radius.l
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.6)
            Column {
                id: menuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                Repeater {
                    model: menu.visible ? menu.entries : []
                    Item {
                        id: me
                        required property var modelData
                        width: menuCol.width
                        height: modelData.sep ? 9 : 44
                        Rectangle {
                            visible: me.modelData.sep === true
                            anchors.centerIn: parent
                            width: parent.width - 16
                            height: 1
                            color: Theme.outlineVariant
                        }
                        Rectangle {
                            visible: !me.modelData.sep
                            anchors.fill: parent
                            radius: Theme.radius.s
                            color: "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12
                                MIcon {
                                    Layout.preferredWidth: 22
                                    icon: me.modelData.icon ?? ""
                                    size: 20
                                    color: Theme.fgSurfaceVariant
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: me.modelData.text ?? ""
                                }
                                MText {
                                    visible: !!me.modelData.key
                                    text: me.modelData.key ?? ""
                                    size: Theme.type.bodyS
                                    color: Theme.fgSurfaceVariant
                                }
                            }
                            StateLayer {
                                visible: !me.modelData.sep
                                onClicked: {
                                    menu.visible = false;
                                    me.modelData.act();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ===========================================================================
    // Диалоги: новая папка, переименование, удаление, свойства, «открыть с помощью»

    Item {
        id: dialog
        anchors.fill: parent
        visible: false
        z: 60
        property string kind: ""
        property var one: null
        property var apps: []
        property string defApp: ""
        property string info: ""

        property string connErr: ""
        function askConnect(uri, user) {
            kind = "connect";
            connErr = "";
            visible = true;
            addrField.text = uri;
            userField.text = user;
            passField.text = "";
            (uri ? passField : addrField).forceFocus();
        }
        function connect() {
            let uri = addrField.text.trim();
            if (!uri)
                return;
            // без схемы — считаем, что это Windows/Samba: \\host\share или host/share
            if (!/^[a-z]+:\/\//.test(uri))
                uri = "smb://" + uri.replace(/\\/g, "/").replace(/^\/+/, "");
            connErr = "";
            Files.connect(uri, userField.text.trim(), passField.text, saveConn.checked, (ok, path, err) => {
                if (ok) {
                    dialog.visible = false;
                    win.go(path);
                } else
                    dialog.connErr = err || "Не удалось подключиться";
            });
        }
        function ask(k) {
            kind = k;
            one = win.allShown.find(i => i.path === win.selectedPaths[0]) ?? null;
            visible = true;
            if (k === "mkdir") {
                nameField.text = "Новая папка";
                nameField.forceFocus();
                nameField.input.selectAll();
            } else if (k === "rename" && one) {
                nameField.text = one.name;
                nameField.forceFocus();
                const dot = one.isDir ? -1 : one.name.lastIndexOf(".");
                nameField.input.select(0, dot > 0 ? dot : one.name.length);
            } else if (k === "openwith" && one) {
                apps = [];
                appsLoaded = false;
                Files.appsFor(one.path, (list, def) => {
                    // для типа никто не зарегистрирован — предложить все приложения
                    dialog.allApps = list.length === 0;
                    dialog.apps = list.length ? list : Apps.all;
                    dialog.defApp = def;
                    dialog.appsLoaded = true;
                });
            } else if (k === "info" && one) {
                info = "";
                infoProc.running = true;
            }
        }
        function accept() {
            if (kind === "connect") {
                connect();
                return;
            }
            const name = nameField.text.trim().replace(/\//g, "");
            if (kind === "mkdir" && name)
                Files.mkdir(win.here, name);
            else if (kind === "rename" && one && name && name !== one.name)
                Files.rename(one.path, name);
            else if (kind === "delete") {
                Files.deleteForever(win.selectedPaths);
                win.selected = {};
            } else if (kind === "empty")
                Files.emptyTrash();
            visible = false;
        }

        Process {
            id: infoProc
            command: ["sh", "-c", 'du -sb -- "$1" 2>/dev/null | cut -f1; stat -c "%A|%U|%y" -- "$1"; xdg-mime query filetype "$1" 2>/dev/null', "sh", dialog.one?.path ?? "/"]
            stdout: StdioCollector {
                onStreamFinished: dialog.info = text
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.32)
            MouseArea {
                anchors.fill: parent
                onClicked: dialog.visible = false
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(460, parent.width - 48)
            height: dlgCol.implicitHeight + 48
            radius: Theme.radius.xl
            color: Theme.surfaceContainerHigh
            MouseArea {
                anchors.fill: parent
            }
            ColumnLayout {
                id: dlgCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 16

                MIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: ({
                            connect: "add_link",
                            mkdir: "create_new_folder",
                            rename: "edit",
                            delete: "delete_forever",
                            empty: "delete_sweep",
                            info: "info",
                            openwith: "apps"
                        })[dialog.kind] ?? "info"
                    color: Theme.secondary
                }
                MText {
                    Layout.alignment: Qt.AlignHCenter
                    text: ({
                            connect: "Подключиться к серверу",
                            mkdir: "Новая папка",
                            rename: "Переименовать",
                            delete: "Удалить навсегда?",
                            empty: "Очистить корзину?",
                            info: dialog.one?.name ?? "Свойства",
                            openwith: "Открыть с помощью"
                        })[dialog.kind] ?? ""
                    size: Theme.type.headlineS
                    horizontalAlignment: Text.AlignHCenter
                    Layout.maximumWidth: dlgCol.width
                    elide: Text.ElideMiddle
                }
                MText {
                    Layout.fillWidth: true
                    visible: dialog.kind === "delete" || dialog.kind === "empty"
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.fgSurfaceVariant
                    text: dialog.kind === "empty" ? "Все файлы в корзине будут удалены без возможности восстановления." : "Выбрано: " + win.selCount + ". Файлы удалятся сразу, без корзины."
                }
                // Подключение к сетевой папке
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: dialog.kind === "connect"
                    spacing: 10
                    TextField {
                        id: addrField
                        Layout.fillWidth: true
                        implicitHeight: 52
                        icon: "dns"
                        placeholder: "smb://192.168.1.10/share или sftp://user@host"
                        onAccepted: dialog.connect()
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        TextField {
                            id: userField
                            Layout.fillWidth: true
                            implicitHeight: 52
                            icon: "person"
                            placeholder: "Пользователь"
                            onAccepted: dialog.connect()
                        }
                        TextField {
                            id: passField
                            Layout.fillWidth: true
                            implicitHeight: 52
                            icon: "key"
                            password: true
                            placeholder: "Пароль"
                            onAccepted: dialog.connect()
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        MText {
                            Layout.fillWidth: true
                            text: "Запомнить в боковой панели (без пароля)"
                            color: Theme.fgSurfaceVariant
                        }
                        MSwitch {
                            id: saveConn
                            checked: true
                            onToggled: v => checked = v
                        }
                    }
                    MText {
                        Layout.fillWidth: true
                        text: "Пустые логин и пароль — гостевой вход. Подходят smb://, sftp://, ftp://, davs://"
                        size: Theme.type.bodyS
                        color: Theme.fgSurfaceVariant
                        wrapMode: Text.WordWrap
                    }
                    MText {
                        Layout.fillWidth: true
                        visible: dialog.connErr !== ""
                        text: dialog.connErr
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }
                }

                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    visible: dialog.kind === "mkdir" || dialog.kind === "rename"
                    implicitHeight: 52
                    onAccepted: dialog.accept()
                }

                // Свойства
                GridLayout {
                    Layout.fillWidth: true
                    visible: dialog.kind === "info" && dialog.one !== null
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 6
                    readonly property var lines: dialog.info.split("\n")
                    readonly property var st: (lines[1] ?? "").split("|")
                    Repeater {
                        model: dialog.one ? [["Тип", Files.kindLabel(Files.kindOf(dialog.one.name, dialog.one.isDir)) + (parent.lines[2] ? " (" + parent.lines[2] + ")" : "")], ["Размер", parent.lines[0] ? Files.humanSize(parseInt(parent.lines[0])) : "…"], ["Где", dialog.one.path.slice(0, dialog.one.path.lastIndexOf("/")) || "/"], ["Изменён", Files.humanDate(dialog.one.modified)], ["Права", (parent.st[0] ?? "") + "  " + (parent.st[1] ?? "")]] : []
                        delegate: RowLayout {
                            required property var modelData
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            MText {
                                Layout.preferredWidth: 90
                                text: modelData[0]
                                color: Theme.fgSurfaceVariant
                            }
                            MText {
                                Layout.fillWidth: true
                                text: modelData[1]
                                wrapMode: Text.WrapAnywhere
                                elide: Text.ElideNone
                            }
                        }
                    }
                }

                // Открыть с помощью
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: dialog.kind === "openwith"
                    spacing: 2
                    MText {
                        visible: !dialog.appsLoaded || dialog.allApps
                        Layout.alignment: Qt.AlignHCenter
                        text: dialog.appsLoaded ? "Подходящих не нашлось — все приложения:" : "Ищу подходящие приложения…"
                        color: Theme.fgSurfaceVariant
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(380, appsCol.implicitHeight)
                        contentHeight: appsCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: appsCol
                            width: parent.width
                            spacing: 2
                    Repeater {
                        model: dialog.apps
                        Rectangle {
                            id: oa
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: 26
                            color: oa.modelData.id === dialog.defApp ? Theme.secondaryContainer : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 12
                                AppIcon {
                                    size: 32
                                    icon: oa.modelData.icon
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: oa.modelData.name
                                }
                                MText {
                                    visible: oa.modelData.id === dialog.defApp
                                    text: "по умолчанию"
                                    size: Theme.type.bodyS
                                    color: Theme.fgSecondaryContainer
                                }
                                IconButton {
                                    visible: oa.modelData.id !== dialog.defApp
                                    icon: "star"
                                    tooltip: "Открывать так всегда"
                                    onClicked: {
                                        Files.setDefaultApp(dialog.one.path, oa.modelData.id);
                                        dialog.defApp = oa.modelData.id;
                                    }
                                }
                            }
                            StateLayer {
                                z: -1
                                onClicked: {
                                    Files.openWith(oa.modelData.id, dialog.one.path);
                                    dialog.visible = false;
                                }
                            }
                        }
                    }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Item {
                        Layout.fillWidth: true
                    }
                    Button {
                        variant: "text"
                        text: dialog.kind === "info" || dialog.kind === "openwith" ? "Закрыть" : "Отмена"
                        onClicked: dialog.visible = false
                    }
                    Button {
                        visible: dialog.kind !== "info" && dialog.kind !== "openwith"
                        text: ({
                                connect: Files.busy > 0 ? "Подключаю…" : "Подключиться",
                                mkdir: "Создать",
                                rename: "Переименовать",
                                delete: "Удалить",
                                empty: "Очистить"
                            })[dialog.kind] ?? "OK"
                        onClicked: dialog.accept()
                    }
                }
            }
        }
    }
}
