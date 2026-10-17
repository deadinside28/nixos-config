import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common
import qs.widgets
import qs.services

SettingsPage {
    id: page
    title: "Приложения"

    readonly property var kinds: [
        {
            key: "browser",
            icon: "language",
            title: "Браузер",
            cats: ["WebBrowser"],
            mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"]
        },
        {
            key: "files",
            icon: "folder",
            title: "Файловый менеджер",
            cats: ["FileManager"],
            mimes: ["inode/directory"]
        },
        {
            key: "mail",
            icon: "mail",
            title: "Почта",
            cats: ["Email"],
            mimes: ["x-scheme-handler/mailto"]
        },
        {
            key: "image",
            icon: "image",
            title: "Изображения",
            cats: ["Viewer", "Graphics", "2DGraphics", "RasterGraphics"],
            mimes: ["image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/avif", "image/svg+xml"]
        },
        {
            key: "video",
            icon: "movie",
            title: "Видео",
            cats: ["Video", "Player"],
            mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"]
        },
        {
            key: "audio",
            icon: "music_note",
            title: "Музыка",
            cats: ["Audio", "Music", "Player"],
            mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4"]
        },
        {
            key: "text",
            icon: "description",
            title: "Текстовый редактор",
            cats: ["TextEditor", "IDE"],
            mimes: ["text/plain", "text/markdown", "application/x-shellscript"]
        },
        {
            key: "pdf",
            icon: "picture_as_pdf",
            title: "PDF",
            cats: ["Viewer", "Office"],
            mimes: ["application/pdf"]
        }
    ]

    // { browser: "google-chrome.desktop", ... }
    property var defaults: ({})
    property var autostart: []

    function refresh() {
        query.running = true;
        auto.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: query
        command: ["sh", "-c", page.kinds.map(k => `echo "${k.key}=$(xdg-mime query default ${k.mimes[0]})"`).join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        o[l.slice(0, i)] = l.slice(i + 1).replace(/\.desktop$/, "");
                }
                page.defaults = o;
            }
        }
    }

    function setDefault(kind, id) {
        Quickshell.execDetached(["xdg-mime", "default", id + ".desktop", ...kind.mimes]);
        const o = Object.assign({}, defaults);
        o[kind.key] = id;
        defaults = o;
    }

    // Автозапуск: ~/.config/autostart/*.desktop
    readonly property string autoDir: Settings.configDir + "/autostart"
    Process {
        id: auto
        command: ["sh", "-c", `for f in "${page.autoDir}"/*.desktop; do [ -f "$f" ] || continue; n=$(grep -m1 '^Name=' "$f" | cut -d= -f2-); i=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-); h=$(grep -m1 -i '^Hidden=true' "$f"); printf '%s\\t%s\\t%s\\t%s\\n' "$f" "$n" "$i" "$h"; done`]
        stdout: StdioCollector {
            onStreamFinished: page.autostart = text.split("\n").filter(l => l).map(l => {
                const [file, name, icon, hidden] = l.split("\t");
                return {
                    file,
                    name: name || file.split("/").pop(),
                    icon,
                    enabled: !hidden
                };
            })
        }
    }
    function addAutostart(app) {
        const body = `[Desktop Entry]\nType=Application\nName=${app.name}\nIcon=${app.icon}\nExec=${app.execString}\nX-Added-By=pixel-shell\n`;
        Quickshell.execDetached(["sh", "-c", `mkdir -p "$1" && printf '%s' "$2" > "$1/$3.desktop"`, "sh", autoDir, body, app.id]);
        refreshLater.restart();
    }
    function setAutostartEnabled(item, on) {
        Quickshell.execDetached(["sh", "-c", `sed -i '/^Hidden=/Id' "$1"; ${on ? "" : "echo Hidden=true >> \"$1\""}`, "sh", item.file]);
        refreshLater.restart();
    }
    function removeAutostart(item) {
        Quickshell.execDetached(["rm", "-f", item.file]);
        refreshLater.restart();
    }
    Timer {
        id: refreshLater
        interval: 300
        onTriggered: auto.running = true
    }

    Group {
        title: "Приложения по умолчанию"
        Repeater {
            model: page.kinds
            ChoiceItem {
                id: choice
                required property var modelData
                icon: modelData.icon
                title: modelData.title
                options: {
                    const cats = modelData.cats;
                    let apps = Apps.all.filter(a => (a.categories ?? []).some(c => cats.includes(c)));
                    if (apps.length === 0)
                        apps = Apps.all;
                    const cur = page.defaults[modelData.key];
                    if (cur && !apps.some(a => a.id === cur)) {
                        const e = Apps.byId(cur);
                        if (e)
                            apps = [e, ...apps];
                    }
                    return apps.map(a => ({
                                value: a.id,
                                label: a.name
                            }));
                }
                current: page.defaults[modelData.key] ?? ""
                onSelected: v => page.setDefault(modelData, v)
            }
        }
    }

    Group {
        title: "Автозапуск"
        Repeater {
            model: page.autostart
            SwitchItem {
                id: as
                required property var modelData
                appIcon: modelData.icon || "application-x-executable"
                title: modelData.name
                subtitle: modelData.file.replace(Settings.home, "~")
                checked: modelData.enabled
                onToggled: v => page.setAutostartEnabled(modelData, v)
                IconButton {
                    icon: "delete"
                    onClicked: page.removeAutostart(as.modelData)
                }
            }
        }
        ListItem {
            visible: page.autostart.length === 0
            icon: "rocket_launch"
            title: "Ничего не запускается при входе"
            clickable: false
        }
        Rectangle {
            id: adder
            readonly property bool groupItem: true
            property bool first: false
            property bool last: true
            property bool open: false
            Layout.fillWidth: true
            implicitHeight: open ? 72 + addCol.implicitHeight + 16 : 72
            color: Theme.dark ? Theme.surfaceContainerHigh : Theme.surfaceContainerLowest
            topLeftRadius: first ? 24 : 4
            topRightRadius: first ? 24 : 4
            bottomLeftRadius: last ? 24 : 4
            bottomRightRadius: last ? 24 : 4
            clip: true
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: Theme.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                width: parent.width
                height: 72
                StateLayer {
                    topLeftRadius: adder.topLeftRadius
                    topRightRadius: adder.topRightRadius
                    onClicked: {
                        adder.open = !adder.open;
                        if (adder.open)
                            appSearch.forceFocus();
                    }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 16
                    MIcon {
                        icon: "add"
                        color: Theme.primary
                    }
                    MText {
                        Layout.fillWidth: true
                        text: "Добавить приложение в автозапуск"
                        color: Theme.primary
                        size: Theme.type.bodyL
                    }
                }
            }
            ColumnLayout {
                id: addCol
                y: 72
                x: 16
                width: parent.width - 32
                spacing: 4
                TextField {
                    id: appSearch
                    Layout.fillWidth: true
                    implicitHeight: 48
                    icon: "search"
                    placeholder: "Найти приложение"
                }
                Repeater {
                    model: adder.open ? Apps.search(appSearch.text).slice(0, 6) : []
                    Rectangle {
                        id: cand
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Theme.radius.l
                        color: "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12
                            AppIcon {
                                size: 28
                                icon: cand.modelData.icon
                            }
                            MText {
                                Layout.fillWidth: true
                                text: cand.modelData.name
                            }
                        }
                        StateLayer {
                            onClicked: {
                                page.addAutostart(cand.modelData);
                                adder.open = false;
                                appSearch.text = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
