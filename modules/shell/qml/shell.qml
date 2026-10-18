//@ pragma UseQApplication
//@ pragma AppId pixel-shell
//@ pragma Env QS_NO_RELOAD_POPUP=1

// Pixel Shell — своя оболочка в духе режима рабочего стола Pixel и
// Aluminium OS. Здесь только сборка модулей; всё содержательное лежит
// в modules/ (видимые части), services/ (данные) и common/ (тема, настройки).

import QtQuick
import Quickshell
import qs.common
import qs.services
import qs.widgets
import qs.modules.taskbar
import qs.modules.wallpaper
import qs.modules.launcher
import qs.modules.quicksettings
import qs.modules.notifications
import qs.modules.osd
import qs.modules.lock
import qs.modules.power
import qs.modules.clipboard
import qs.modules.overview
import qs.modules.polkit
import qs.modules.settings
import qs.modules.dnd
import qs.modules.frame
import qs.modules.files
import qs.modules.share
import qs.modules.record
import qs.modules.lens
import qs.modules.store
import qs.modules.notes
import qs.modules.calendar
import qs.modules.filechooser

ShellRoot {
    id: root

    // Сервисы-синглтоны создаются при первом обращении. Эти должны
    // работать с самого старта, даже если на экране их никто не трогает.
    readonly property var services: [Theming, HyprConf, Notifs, NightLight, WallpaperEngine, Fonts, Keyboard]

    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens.filter(s => Bar.shownOn(s.name))
        Taskbar {}
    }

    Variants {
        model: Quickshell.screens.filter(s => Bar.frameOn(s.name))
        ScreenFrame {}
    }

    // Клик на другом мониторе закрывает открытую панель
    Variants {
        model: Ui.panel !== "" ? Quickshell.screens.filter(s => s.name !== Ui.activeScreen) : []
        ClickCatcher {}
    }

    Launcher {}
    QuickSettings {}
    NotificationPopups {}
    Osd {}
    Lock {}
    Idle {}
    PowerMenu {}
    RecordPanel {}
    LensOverlay {}
    ClipboardPanel {}
    Overview {}
    PolkitDialog {}
    SettingsWindow {}
    UpdateWindow {}
    FilesWindows {}
    StoreWindow {}
    NotesWindow {}
    CalendarWindows {}
    FileChooserWindows {}
    ShareWindows {}
    DndSpring {}

    Ipc {}
}
