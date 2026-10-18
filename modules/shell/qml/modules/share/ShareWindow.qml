// «Отправить через Quick Share»: файлы из «Файлов» или по
// `pixel-shell quickshare send <путь>`. Пока окно открыто, служба ищет
// устройства (телефоны на экране приёма Quick Share), клик — отправка.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.widgets
import qs.services
import Pixel.MD3E

FloatingWindow {
    id: win
    title: "Quick Share"
    implicitWidth: 460
    implicitHeight: 560
    minimumSize: Qt.size(380, 420)
    color: Theme.surfaceContainer
    visible: true
    onVisibleChanged: if (!visible)
        close()

    function close() {
        // отправленное и отменённое больше не показываем
        for (const t of QuickShare.outgoing)
            if (win.done(t))
                QuickShare.forget(t.id);
        QuickShare.closeShare();
    }
    function done(t) {
        return ["Finished", "Rejected", "Cancelled", "Disconnected"].includes(t.state);
    }
    function stateText(t) {
        switch (t.state) {
        case "Finished":
            return "Отправлено";
        case "Rejected":
            return "Отклонено";
        case "Cancelled":
            return "Отменено";
        case "Disconnected":
            return "Связь прервалась";
        case "SendingFiles":
            return t.total > 0 ? Math.round(100 * t.done / t.total) + "%" : "Отправка…";
        default:
            return t.pin ? "Ждём ответа · код " + t.pin : "Подключение…";
        }
    }
    function deviceIcon(type) {
        return ({
                phone: "smartphone",
                tablet: "tablet_android",
                laptop: "laptop"
            })[type] ?? "devices";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            MIcon {
                icon: "share"
                size: 28
                color: Theme.primary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                MText {
                    text: "Отправить через Quick Share"
                    size: Theme.type.titleL
                }
                MText {
                    Layout.fillWidth: true
                    text: QuickShare.shareFiles.length === 1 ? QuickShare.shareFiles[0].replace(/^.*\//, "") : QuickShare.shareFiles.length + " файл(ов)"
                    color: Theme.fgSurfaceVariant
                    elide: Text.ElideMiddle
                }
            }
        }

        // Служба не включена или не запущена
        MText {
            visible: !QuickShare.available
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.error
            text: QuickShare.enabled ? "Служба Quick Share не отвечает (systemctl --user status pixel-quickshare)." : "Quick Share выключен: «Настройки → Система → Службы → Quick Share с Android», затем «Применить»."
        }

        Group {
            title: "Отправки"
            visible: QuickShare.outgoing.length > 0
            Repeater {
                model: QuickShare.outgoing
                ListItem {
                    required property var modelData
                    icon: win.done(modelData) ? (modelData.state === "Finished" ? "check_circle" : "error") : "upload"
                    title: modelData.device
                    subtitle: win.stateText(modelData)
                    clickable: false
                    IconButton {
                        visible: !win.done(modelData)
                        icon: "close"
                        tooltip: "Отменить"
                        onClicked: QuickShare.cancel(modelData.id)
                    }
                }
            }
        }

        Group {
            Layout.fillHeight: true
            title: "Устройства рядом"
            visible: QuickShare.available
            Repeater {
                model: QuickShare.devices
                ListItem {
                    required property var modelData
                    icon: win.deviceIcon(modelData.type)
                    title: modelData.name
                    subtitle: modelData.ble ? "По Bluetooth" : "В этой сети"
                    chevron: true
                    onClicked: QuickShare.sendTo(modelData.id, QuickShare.shareFiles)
                }
            }
            RowLayout {
                visible: QuickShare.devices.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: 20
                spacing: 12
                CircularProgress {
                    implicitWidth: 28
                    implicitHeight: 28
                }
                MText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.fgSurfaceVariant
                    text: "Поиск… На телефоне откройте Quick Share → «Получить» или включите видимость для всех."
                }
            }
            Item {
                Layout.fillHeight: true
            }
        }

        MText {
            visible: QuickShare.lastError !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.error
            text: QuickShare.lastError
        }

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: "Готово"
                variant: "tonal"
                onClicked: win.close()
            }
        }
    }
}
