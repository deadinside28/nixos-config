// Все открытые окна «Файлов» (pixel-shell files open <путь>).
import QtQuick
import Quickshell
import qs.services

Scope {
    Variants {
        model: Files.windows
        FilesWindow {
            required property var modelData
            entry: modelData
        }
    }
}
