// Простой: блокировка, выключение экрана и сон по таймерам из настроек.
// «Без сна» в быстрых настройках держит ингибитор, и таймеры молчат.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

Scope {
    id: root

    IdleMonitor {
        enabled: Settings.data.lockTimeout > 0 && !Ui.caffeine
        timeout: Settings.data.lockTimeout
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            Ui.locked = true
    }

    IdleMonitor {
        enabled: Settings.data.screenOffTimeout > 0 && !Ui.caffeine
        timeout: Settings.data.screenOffTimeout
        respectInhibitors: true
        onIsIdleChanged: Hypr.dpms(!isIdle)
    }

    IdleMonitor {
        enabled: Settings.data.suspendTimeout > 0 && !Ui.caffeine
        timeout: Settings.data.suspendTimeout
        respectInhibitors: true
        onIsIdleChanged: if (isIdle)
            Power.suspend()
    }

    // «Без сна»: ингибитор на окне панели задач первого экрана.
    IdleInhibitor {
        enabled: Ui.caffeine
        window: PanelWindow {
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            anchors.top: true
            anchors.left: true
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "pixel-shell:inhibitor"
        }
    }
}
