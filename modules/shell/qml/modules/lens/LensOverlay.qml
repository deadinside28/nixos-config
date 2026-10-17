// Интерфейс «Обвести и найти» как на Pixel: экран замирает, по краям
// пробегает свечение, обводишь (или просто тычешь) что угодно — снизу
// карточка: найти в Google, текст, перевод. В режиме перевода абзацы
// переведённого текста лежат прямо поверх оригинала.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.widgets
import qs.services

Scope {
    // Снимок с интерфейсом: «найти» и «перевести»
    LazyLoader {
        active: Lens.active && Lens.mode !== "live"

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === Lens.screen) ?? Quickshell.screens[0]
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pixel-shell:lens"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // пиксели снимка на точку окна
            readonly property real k: Lens.shotSize.width > 0 ? Lens.shotSize.width / width : 1
            readonly property rect sel: Qt.rect(Lens.area.x / k, Lens.area.y / k, Lens.area.width / k, Lens.area.height / k)
            readonly property bool hasSel: Lens.area.width > 0
            property bool showOriginal: false

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Lens.stop()

                Image {
                    id: shot
                    anchors.fill: parent
                    source: Lens.shot ? "file://" + Lens.shot : ""
                    cache: false
                    smooth: true
                    onStatusChanged: if (status === Image.Ready)
                        Lens.shotSize = Qt.size(implicitWidth, implicitHeight)
                }

                // лёгкое затемнение; с выделением — сильнее вокруг него
                Rectangle {
                    anchors.fill: parent
                    visible: !win.hasSel
                    color: Qt.rgba(0, 0, 0, 0.18)
                }
                Item {
                    anchors.fill: parent
                    visible: win.hasSel
                    readonly property color c: Qt.rgba(0, 0, 0, 0.45)
                    Rectangle {
                        width: parent.width
                        height: win.sel.y
                        color: parent.c
                    }
                    Rectangle {
                        y: win.sel.y + win.sel.height
                        width: parent.width
                        height: parent.height - y
                        color: parent.c
                    }
                    Rectangle {
                        y: win.sel.y
                        width: win.sel.x
                        height: win.sel.height
                        color: parent.c
                    }
                    Rectangle {
                        x: win.sel.x + win.sel.width
                        y: win.sel.y
                        width: parent.width - x
                        height: win.sel.height
                        color: parent.c
                    }
                    // уголки, как у Circle to Search
                    Repeater {
                        model: 4
                        Item {
                            required property int index
                            readonly property bool atRight: index % 2 === 1
                            readonly property bool atBottom: index > 1
                            x: (atRight ? win.sel.x + win.sel.width - 28 : win.sel.x) + (atRight ? 4 : -4)
                            y: (atBottom ? win.sel.y + win.sel.height - 28 : win.sel.y) + (atBottom ? 4 : -4)
                            width: 28
                            height: 28
                            Rectangle {
                                x: parent.atRight ? parent.width - 4 : 0
                                width: 4
                                height: parent.height
                                radius: 2
                                color: "white"
                            }
                            Rectangle {
                                y: parent.atBottom ? parent.height - 4 : 0
                                width: parent.width
                                height: 4
                                radius: 2
                                color: "white"
                            }
                        }
                    }
                }

                // Свечение по краям при открытии
                Item {
                    id: glow
                    anchors.fill: parent
                    opacity: 0
                    Component.onCompleted: glowAnim.start()
                    SequentialAnimation {
                        id: glowAnim
                        NumberAnimation {
                            target: glow
                            property: "opacity"
                            to: 1
                            duration: 250
                        }
                        NumberAnimation {
                            target: glow
                            property: "opacity"
                            to: 0
                            duration: 900
                            easing.type: Easing.InQuad
                        }
                    }
                    Repeater {
                        model: ["top", "bottom", "left", "right"]
                        Rectangle {
                            required property string modelData
                            readonly property bool horiz: modelData === "top" || modelData === "bottom"
                            x: modelData === "right" ? parent.width - width : 0
                            y: modelData === "bottom" ? parent.height - height : 0
                            width: horiz ? parent.width : 90
                            height: horiz ? 90 : parent.height
                            gradient: Gradient {
                                orientation: parent.horiz ? Gradient.Vertical : Gradient.Horizontal
                                GradientStop {
                                    position: 0
                                    color: modelData === "top" || modelData === "left" ? Theme.alpha(Theme.primary, 0.55) : "transparent"
                                }
                                GradientStop {
                                    position: 1
                                    color: modelData === "top" || modelData === "left" ? "transparent" : Theme.alpha(Theme.tertiary, 0.55)
                                }
                            }
                        }
                    }
                }

                // Переведённые абзацы поверх оригинала
                Repeater {
                    model: win.showOriginal ? [] : Lens.boxes
                    Rectangle {
                        id: tb
                        required property var modelData
                        x: modelData.x / win.k - 3
                        y: modelData.y / win.k - 2
                        width: modelData.w / win.k + 6
                        height: modelData.h / win.k + 4
                        radius: 4
                        color: modelData.bg
                        Text {
                            anchors.fill: parent
                            anchors.margins: 2
                            text: tb.modelData.text
                            color: tb.modelData.fg
                            wrapMode: Text.WordWrap
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 7
                            font.pixelSize: Math.max(8, tb.modelData.lh / win.k * 0.92)
                            font.family: Theme.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Рисование: обвести или ткнуть
                Canvas {
                    id: ink
                    anchors.fill: parent
                    property var pts: []
                    visible: Lens.mode === "search"
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (pts.length < 2)
                            return;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        // мягкий ореол и белая линия поверх
                        for (const [w, c] of [[18, Qt.rgba(1, 1, 1, 0.25)], [6, "white"]]) {
                            ctx.lineWidth = w;
                            ctx.strokeStyle = c;
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, pts[0].y);
                            for (const p of pts.slice(1))
                                ctx.lineTo(p.x, p.y);
                            ctx.stroke();
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: Lens.mode === "search"
                    cursorShape: Qt.CrossCursor
                    onPressed: event => {
                        ink.pts = [Qt.point(event.x, event.y)];
                        ink.requestPaint();
                    }
                    onPositionChanged: event => {
                        if (!pressed)
                            return;
                        ink.pts.push(Qt.point(event.x, event.y));
                        ink.requestPaint();
                    }
                    onReleased: event => {
                        const xs = ink.pts.map(p => p.x), ys = ink.pts.map(p => p.y);
                        let x1 = Math.min(...xs), x2 = Math.max(...xs), y1 = Math.min(...ys), y2 = Math.max(...ys);
                        // просто ткнули — квадрат вокруг точки
                        if (x2 - x1 < 24 && y2 - y1 < 24) {
                            x1 = event.x - 120;
                            x2 = event.x + 120;
                            y1 = event.y - 90;
                            y2 = event.y + 90;
                        }
                        x1 = Math.max(0, x1);
                        y1 = Math.max(0, y1);
                        x2 = Math.min(win.width, x2);
                        y2 = Math.min(win.height, y2);
                        ink.pts = [];
                        ink.requestPaint();
                        Lens.select(Qt.rect(x1 * win.k, y1 * win.k, (x2 - x1) * win.k, (y2 - y1) * win.k));
                    }
                }

                // --- Нижняя карточка --------------------------------------------
                Rectangle {
                    id: sheet
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 28
                    width: Math.min(720, parent.width - 48)
                    height: sheetCol.implicitHeight + 32
                    radius: 32
                    color: "transparent"
                    // выезжает снизу
                    transform: Translate {
                        id: slide
                        y: 200
                        Component.onCompleted: slideAnim.start()
                    }
                    NumberAnimation {
                        id: slideAnim
                        target: slide
                        property: "y"
                        to: 0
                        duration: Theme.anim.normal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.anim.emphasizedDecel
                    }
                    MouseArea {
                        anchors.fill: parent
                    }

                    // Матовое стекло: снимок под карточкой лежит в этом же слое,
                    // Hyprland его не размоет — размываем сами
                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: sheetMask
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: ShaderEffectSource {
                                sourceItem: shot
                                sourceRect: Qt.rect(sheet.x, sheet.y + slide.y, sheet.width, sheet.height)
                            }
                            blurEnabled: true
                            blur: 1
                            blurMax: 64
                            saturation: 0.2
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.alpha(Theme.surfaceContainer, 0.72)
                        }
                    }
                    Rectangle {
                        id: sheetMask
                        anchors.fill: parent
                        radius: sheet.radius
                        visible: false
                        layer.enabled: true
                    }

                    ColumnLayout {
                        id: sheetCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 12

                        // Строка как у Google: значок, подсказка, кнопки режимов
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle {
                                implicitWidth: 44
                                implicitHeight: 44
                                radius: 22
                                color: Theme.primaryContainer
                                MIcon {
                                    anchors.centerIn: parent
                                    icon: Lens.mode === "translate" ? "translate" : "search"
                                    color: Theme.fgPrimaryContainer
                                }
                            }
                            MText {
                                Layout.fillWidth: true
                                text: Lens.status || (Lens.mode === "translate" ? "Перевод на " + (Lens.languages.find(l => l.value === Lens.target)?.label.toLowerCase() ?? Lens.target) : win.hasSel ? "Что сделать с выделенным?" : "Обведите или коснитесь, чтобы найти")
                                size: Theme.type.bodyL
                                color: Theme.fgSurfaceVariant
                            }
                            IconButton {
                                icon: "translate"
                                variant: Lens.mode === "translate" ? "tonal" : "standard"
                                tooltip: "Перевести экран"
                                onClicked: {
                                    if (Lens.mode === "translate") {
                                        Lens.mode = "search";
                                        Lens.boxes = [];
                                    } else {
                                        Lens.mode = "translate";
                                        Lens.crop = "";
                                        Lens.area = Qt.rect(0, 0, 0, 0);
                                        Lens.translateShot();
                                    }
                                }
                            }
                            IconButton {
                                icon: "close"
                                onClicked: Lens.stop()
                            }
                        }

                        LinearProgress {
                            Layout.fillWidth: true
                            visible: Lens.busy
                            value: -1
                        }

                        // Действия с выделенным
                        Flow {
                            Layout.fillWidth: true
                            visible: Lens.mode === "search" && win.hasSel
                            spacing: 8
                            Action {
                                icon: "image_search"
                                text: "Найти в Google"
                                primary: true
                                onClicked: Lens.searchCrop()
                            }
                            Action {
                                icon: "text_fields"
                                text: "Текст"
                                onClicked: Lens.recognize()
                            }
                            Action {
                                icon: "translate"
                                text: "Перевести"
                                onClicked: Lens.translateShot()
                            }
                            Action {
                                icon: "content_copy"
                                text: "Копировать"
                                onClicked: {
                                    Lens.copyImage();
                                    Lens.stop();
                                }
                            }
                            Action {
                                icon: "download"
                                text: "Сохранить"
                                onClicked: {
                                    Lens.saveImage();
                                    Lens.stop();
                                }
                            }
                        }

                        // Распознанный текст
                        Rectangle {
                            Layout.fillWidth: true
                            visible: Lens.text !== ""
                            implicitHeight: Math.min(220, textCol.implicitHeight + 24)
                            radius: Theme.radius.l
                            color: Theme.surfaceContainerHigh
                            clip: true
                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 12
                                contentHeight: textCol.implicitHeight
                                boundsBehavior: Flickable.StopAtBounds
                                ColumnLayout {
                                    id: textCol
                                    width: parent.width
                                    spacing: 8
                                    TextEdit {
                                        Layout.fillWidth: true
                                        text: Lens.text
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: Text.WordWrap
                                        color: Theme.fgSurface
                                        selectionColor: Theme.alpha(Theme.primary, 0.4)
                                        font.family: Theme.font
                                        font.pixelSize: Theme.type.bodyM
                                    }
                                    TextEdit {
                                        Layout.fillWidth: true
                                        visible: Lens.textTranslated !== ""
                                        text: Lens.textTranslated
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: Text.WordWrap
                                        color: Theme.primary
                                        selectionColor: Theme.alpha(Theme.primary, 0.4)
                                        font.family: Theme.font
                                        font.pixelSize: Theme.type.bodyM
                                    }
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            visible: Lens.text !== ""
                            spacing: 8
                            Action {
                                icon: "content_copy"
                                text: "Копировать текст"
                                primary: true
                                onClicked: {
                                    Lens.copyText(Lens.textTranslated || Lens.text);
                                    Lens.stop();
                                }
                            }
                            Action {
                                icon: "search"
                                text: "Искать"
                                onClicked: Lens.webSearch(Lens.text)
                            }
                            Action {
                                visible: Lens.textTranslated === ""
                                icon: "translate"
                                text: "Перевести текст"
                                onClicked: Lens.translateText()
                            }
                        }

                        // Перевод: язык, оригинал, живой режим
                        RowLayout {
                            Layout.fillWidth: true
                            visible: Lens.mode === "translate" || Lens.boxes.length > 0
                            spacing: 8
                            ChoiceItem {
                                Layout.fillWidth: true
                                icon: "language"
                                title: "Язык перевода"
                                options: Lens.languages
                                current: Lens.target
                                onSelected: v => {
                                    Settings.data.translateTo = v;
                                    Lens.translateShot();
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            visible: Lens.mode === "translate" || Lens.boxes.length > 0
                            spacing: 8
                            Action {
                                icon: win.showOriginal ? "visibility_off" : "visibility"
                                text: win.showOriginal ? "Показать перевод" : "Показать оригинал"
                                onClicked: win.showOriginal = !win.showOriginal
                            }
                            Action {
                                icon: "content_copy"
                                text: "Копировать перевод"
                                onClicked: {
                                    Lens.copyText(Lens.boxes.map(b => b.text).join("\n\n"));
                                    Lens.stop();
                                }
                            }
                            Action {
                                icon: "live_tv"
                                text: "В реальном времени"
                                primary: true
                                onClicked: {
                                    Lens.mode = "live";
                                    Lens.crop = "";
                                    Lens.area = Qt.rect(0, 0, 0, 0);
                                    Lens.boxes = [];
                                    Lens.capture();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Живой перевод: прозрачный слой поверх экрана, мышь проходит насквозь
    LazyLoader {
        active: Lens.active && Lens.mode === "live"

        PanelWindow {
            id: live
            screen: Quickshell.screens.find(s => s.name === Lens.screen) ?? Quickshell.screens[0]
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pixel-shell:lens-live"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            // ловим мышь только на «таблетке» управления
            mask: Region {
                item: pill
            }
            readonly property real k: Lens.shotSize.width > 0 ? Lens.shotSize.width / width : 1

            Item {
                anchors.fill: parent
                // на время снимка прячемся, чтобы не распознавать свой же перевод
                opacity: Lens.capturing ? 0 : 1

                Image {
                    // размер снимка (для пересчёта координат)
                    visible: false
                    source: Lens.shot ? "file://" + Lens.shot : ""
                    cache: false
                    onStatusChanged: if (status === Image.Ready)
                        Lens.shotSize = Qt.size(implicitWidth, implicitHeight)
                }
                Repeater {
                    model: Lens.boxes
                    Rectangle {
                        id: lb
                        required property var modelData
                        x: modelData.x / live.k - 3
                        y: modelData.y / live.k - 2
                        width: modelData.w / live.k + 6
                        height: modelData.h / live.k + 4
                        radius: 4
                        color: modelData.bg
                        Text {
                            anchors.fill: parent
                            anchors.margins: 2
                            text: lb.modelData.text
                            color: lb.modelData.fg
                            wrapMode: Text.WordWrap
                            fontSizeMode: Text.Fit
                            minimumPixelSize: 7
                            font.pixelSize: Math.max(8, lb.modelData.lh / live.k * 0.92)
                            font.family: Theme.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    id: pill
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    width: pillRow.implicitWidth + 24
                    height: 52
                    radius: 26
                    color: Theme.panel
                    RowLayout {
                        id: pillRow
                        anchors.centerIn: parent
                        spacing: 8
                        MIcon {
                            icon: "translate"
                            color: Theme.primary
                        }
                        MText {
                            text: "Перевод в реальном времени · " + (Lens.languages.find(l => l.value === Lens.target)?.label ?? Lens.target)
                        }
                        CircularProgress {
                            implicitWidth: 18
                            implicitHeight: 18
                            thickness: 3
                            visible: Lens.busy
                            value: -1
                        }
                        IconButton {
                            icon: "stop"
                            variant: "tonal"
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: Lens.stop()
                        }
                    }
                }
            }
        }
    }

    component Action: Rectangle {
        id: act
        property string icon
        property string text
        property bool primary: false
        signal clicked
        implicitHeight: 40
        implicitWidth: actRow.implicitWidth + 32
        radius: 20
        color: primary ? Theme.primary : Theme.secondaryContainer
        Row {
            id: actRow
            anchors.centerIn: parent
            spacing: 8
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: act.icon
                size: 20
                color: act.primary ? Theme.fgPrimary : Theme.fgSecondaryContainer
            }
            MText {
                anchors.verticalCenter: parent.verticalCenter
                text: act.text
                weight: Theme.strongWeight
                color: act.primary ? Theme.fgPrimary : Theme.fgSecondaryContainer
            }
        }
        StateLayer {
            radius: act.radius
            color: act.primary ? Theme.fgPrimary : Theme.fgSecondaryContainer
            onClicked: act.clicked()
        }
    }
}
