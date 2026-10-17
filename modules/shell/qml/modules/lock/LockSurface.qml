// Сам экран блокировки: размытые обои, большие часы как на Pixel,
// поле пароля внизу.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.common
import qs.widgets
import qs.services

Rectangle {
    id: root
    required property var lock
    color: Theme.surfaceDim

    Image {
        id: wall
        anchors.fill: parent
        source: Wallpapers.image ? "file://" + Wallpapers.image : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: Theme.dark ? -0.25 : -0.1
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.14
        spacing: 0

        MText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(Time.now, "HH")
            size: 168
            weight: Theme.strongWeight
            color: Theme.primaryFixedDim
        }
        MText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -60
            text: Qt.formatTime(Time.now, "mm")
            size: 168
            weight: Theme.strongWeight
            color: Theme.primaryFixed
        }
        MText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            text: Time.dateLong.charAt(0).toUpperCase() + Time.dateLong.slice(1)
            size: Theme.type.titleL
            color: "white"
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.12
        spacing: 12
        width: 360

        MIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "lock"
            fill: 1
            color: "white"
        }

        TextField {
            id: field
            Layout.fillWidth: true
            password: true
            icon: "key"
            placeholder: "Пароль"
            fieldColor: Theme.alpha(Theme.surfaceContainerHigh, 0.85)
            enabled: !root.lock.busy
            text: root.lock.password
            onTextChanged: root.lock.password = text
            onAccepted: root.lock.unlock()
            Component.onCompleted: forceFocus()

            // Тряска при ошибке
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: -12
                    duration: 50
                }
                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: 12
                    duration: 50
                }
                NumberAnimation {
                    target: field
                    property: "anchors.horizontalCenterOffset"
                    to: 0
                    duration: 50
                }
            }
        }

        MText {
            Layout.alignment: Qt.AlignHCenter
            text: root.lock.busy ? "Проверка…" : root.lock.error
            color: root.lock.error ? Theme.error : "white"
            visible: text !== ""
        }
    }

    Connections {
        target: root.lock
        function onErrorChanged() {
            if (root.lock.error !== "")
                shake.start();
        }
        function onPasswordChanged() {
            if (field.text !== root.lock.password)
                field.text = root.lock.password;
        }
    }

    // Клавиши громкости и т.п. сюда не доходят — и не надо.
    Keys.onEscapePressed: root.lock.password = ""
}
