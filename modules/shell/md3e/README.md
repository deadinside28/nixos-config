# Pixel.MD3E

Тема Material 3 Expressive и виджеты Pixel Shell на чистом Qt Quick (раздел 5.2 роадмапа). Библиотеку использует оболочка, но Quickshell ей не нужен: её можно подключить в самостоятельное QML-приложение.

## Состав

- `Theme` (синглтон) — цветовые роли M3, типографика, скругления, движение. Входы: `dark`, `scheme` (colors.json от matugen), `font`, `monoFont`, `fontWeightName`, `fontSize`, `animationScale`, `panelOpacity`, `frame`. Недостающие роли схемы берутся из базовой палитры.
- `ThemeFile` — для самостоятельных приложений: читает `colors.json` и `settings.json` оболочки (`~/.local/state/pixel-shell`) и задаёт входы `Theme`, следит за изменениями. Нужен `QML_XHR_ALLOW_FILE_READ=1`.
- Виджеты: `Button`, `IconButton`, `SegmentedButtons`, `TextField`, `Card`, `Group`, `ListItem` (слот `leading`), `SwitchItem`, `ChoiceItem`, `SliderItem`, `MSlider`, `PillSlider`, `MSwitch`, `MText`, `MIcon` (Material Symbols Rounded), `StateLayer`, `LinearProgress`, `CircularProgress`.

В оболочке остались виджеты, которым нужен Quickshell: `AppIcon` (тема иконок), `AppListItem`, `AppVolumeRow`, `Overlay`, `ClickCatcher`. Входы темы в оболочке задаёт `qml/common/ThemeBridge.qml`.

## Подключение

Пакет — `package.nix` (`pkgs.callPackage ./modules/shell/md3e/package.nix {}`), путь QML — `<пакет>/lib/qt-6/qml`. В сессии `QML_IMPORT_PATH` уже указывает на него (Home Manager).

```qml
import QtQuick
import Pixel.MD3E

Window {
    visible: true
    color: Theme.surfaceContainer
    ThemeFile {}
    Button { text: "Готово"; icon: "check" }
}
```

Витрина: `QML_XHR_ALLOW_FILE_READ=1 qml <пакет>/share/pixel-md3e/gallery.qml`.

## Проверки

- `nix flake check` → `md3e`: витрина запускается обычным `qml` без Quickshell (offscreen), тема читается из файлов, любое предупреждение QML — провал.
- `shell-load`: оболочка с библиотекой открывает все окна и страницы.
