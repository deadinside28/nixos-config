// Окно Quick Share — пока есть файлы на отправку (QuickShare.share()).
import QtQuick
import Quickshell
import qs.services

Scope {
    LazyLoader {
        active: QuickShare.shareOpen
        ShareWindow {}
    }
}
