// Агент polkit: окно «Введите пароль» для LACT, NetworkManager,
// nixos-rebuild через pkexec и т.п. Раньше эту роль играл DMS.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import qs.common
import qs.widgets
import Pixel.MD3E

Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow

    Overlay {
        id: overlay
        name: "polkit"
        dim: true
        open: agent.isActive && root.flow !== null
        onDismissed: root.flow?.cancelAuthenticationRequest()
        exclusiveFocus: true
        onOpenChanged: if (open) {
            pass.text = "";
            pass.forceFocus();
        }

        Card {
            anchors.centerIn: parent
            width: 440
            height: col.implicitHeight + 48
            scale: 0.92 + 0.08 * overlay.progress
            opacity: overlay.progress
            color: Theme.surfaceContainerHigh

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 16

                MIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "admin_panel_settings"
                    size: 32
                    color: Theme.secondary
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Нужно подтверждение"
                    size: Theme.type.headlineS
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.flow?.message ?? ""
                    color: Theme.fgSurfaceVariant
                    wrapMode: Text.Wrap
                }
                MText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    visible: (root.flow?.identities?.length ?? 0) > 0
                    text: "Пользователь: " + (root.flow?.selectedIdentity?.displayName ?? "")
                    size: Theme.type.bodyS
                    color: Theme.fgSurfaceVariant
                }

                TextField {
                    id: pass
                    Layout.fillWidth: true
                    password: !(root.flow?.responseVisible ?? false)
                    icon: "key"
                    placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Пароль"
                    onAccepted: root.flow?.submit(text)
                    onEscapePressed: root.flow?.cancelAuthenticationRequest()
                }
                MText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: (root.flow?.failed ?? false) ? "Неверный пароль, попробуй ещё раз" : (root.flow?.supplementaryMessage ?? "")
                    color: (root.flow?.failed || root.flow?.supplementaryIsError) ? Theme.error : Theme.fgSurfaceVariant
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    Button {
                        variant: "text"
                        text: "Отмена"
                        onClicked: root.flow?.cancelAuthenticationRequest()
                    }
                    Button {
                        text: "Подтвердить"
                        onClicked: root.flow?.submit(pass.text)
                    }
                }
            }
        }
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            pass.text = "";
        }
    }
}
