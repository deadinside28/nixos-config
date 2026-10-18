// По окну на каждый запрос диалога выбора файлов от портала.
import QtQuick
import Quickshell
import qs.services

Scope {
    Variants {
        model: FileChooser.requests
        FileChooserWindow {
            required property var modelData
            req: modelData
        }
    }
}
