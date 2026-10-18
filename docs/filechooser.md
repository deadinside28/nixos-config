# Единый диалог выбора файлов (R09, R10)

## Как устроено

```
приложение ──(портал FileChooser)──► xdg-desktop-portal ──► pixel-portal (D-Bus)
                                                               │  pixel-shell filechooser request <json>
                                                               ▼
                                                     Pixel Shell: окно в стиле «Файлов»
                                                               │  ответ → $XDG_RUNTIME_DIR/pixel-portal/<id>.json
                                                               ▼
                                         pixel-portal ──► URI ──► xdg-desktop-portal (document portal для Flatpak)
```

- Backend: `modules/shell/portal/pixel-portal.py` (`org.freedesktop.impl.portal.FileChooser`: `OpenFile`, `SaveFile`, `SaveFiles`).
- Окно: `modules/shell/qml/modules/filechooser/FileChooserWindow.qml`, запросы — `services/FileChooser.qml`.
- Включение: «Настройки → Система → Рабочий стол → Свой диалог выбора файлов», то есть `desktop.fileChooser = "pixel"` в `system.json`, затем «Применить». По умолчанию стоит `gtk`.
- **Запасной путь:** если оболочка не ответила на запрос (не запущена или перезапускается), `pixel-portal` передаёт запрос целиком бэкенду GTK. Диалог открывается всегда.
- **Qt-приложения** (Telegram, qBittorrent…) с темой `gtk3` рисуют GTK-диалог в своём процессе, и портал не участвует. Поэтому, когда включён свой диалог, у Qt тема `xdgdesktopportal`: она отправляет диалоги в портал, а оформление берёт у базовой темы рабочего стола. Для `XDG_CURRENT_DESKTOP=Hyprland` такой темы в Qt нет, и базовой была бы голая `generic`. Плагин `modules/shell/qt-portal-theme` — это тема «hyprland», которая возвращает `gtk3`, так что оформление остаётся GTK. Действует после «Применить» и повторного входа в сессию.
- После `switch` `pixel-rebuild` перезапускает `xdg-desktop-portal`, если настройка порталов изменилась: это служба systemd --user, и сама она новую настройку не подхватывает.
- GTK3-приложения, которые создают `GtkFileChooserDialog` напрямую, а не `GtkFileChooserNative`, рисуют диалог сами — портал их не касается.
- Права Flatpak-приложениям на выбранные файлы выдаёт сам xdg-desktop-portal (document portal). Широкие права на папки для этого не нужны.
- Проверки в `nix flake check`: `portal` — портал на настоящей шине с заглушками оболочки и GTK; `portal-qt` — сквозная: QML `FileDialog` с темой `xdgdesktopportal` и плагином → настоящий xdg-desktop-portal → pixel-portal → выбранный файл возвращается в приложение.

### Что поддержано

| Возможность портала | Состояние |
|---|---|
| Открыть один / несколько файлов | да |
| Выбрать папку (`directory`) | да |
| Сохранить, предложенное имя, подтверждение замены | да |
| Сохранить несколько в папку (`SaveFiles`) | да |
| Фильтры: glob | да |
| Фильтры: MIME | по таблице известных типов (`FileChooser.mimeGlobs`); неизвестный MIME не фильтрует |
| `current_folder`, `current_file`, `current_name` | да |
| `choices` (флажки и списки) | да |
| `accept_label` | да |
| Привязка к родительскому окну (`parent_window`, модальность) | **нет** — окно открывается отдельным плавающим окном |
| Сетевые места GVfs | папки, смонтированные GVfs, доступны по локальному пути `/run/user/…/gvfs` |

## Матрица проверки приложений

Заполняется на живой системе после включения `pixel`. Для каждой строки отметить: открытие, сохранение, выбор папки, фильтры, отмену.

| Приложение | Тулкит / упаковка | Открыть | Сохранить | Папка | Фильтры | Отмена | Заметки |
|---|---|---|---|---|---|---|---|
| Google Chrome | Chromium (портал через GTK4 / `GTK_USE_PORTAL`) | | | | | | |
| Telegram | Qt6, nixpkgs | | | | | | |
| Zed | свой, nixpkgs | | | | | | |
| OnlyOffice | Qt, nixpkgs | | | | | | |
| Loupe / Papers | GTK4 | | | | | | |
| gnome-text-editor | GTK4 | | | | | | |
| qBittorrent | Qt6 | | | | | | |
| Bazaar | Flatpak | | | | | | |
| AppImage (любой Qt/GTK) | шим `appimage-run` | | | | | | |
| cpak-приложение | cpak | | | | | | |
| Wine: notepad, regedit | Wine | | | | | | см. ниже |

То, что приложение стоит из Flatpak, AppImage или cpak, ещё не значит, что оно ходит в портал. Приложения со своим встроенным файловым браузером портал не заменит. Такие случаи отмечаются в «Заметках».

## Wine (R10)

Состояние на 18 октября 2026:

- Штатный Wine стандартные диалоги (`GetOpenFileName*`, `GetSaveFileName*`, `IFileOpenDialog`, `IFileSaveDialog`) рисует сам. Портал он не использует.
- [MR10060 «Use XDG Desktop Portal for native file dialogs»](https://list.winehq.org/hyperkitty/list/wine-gitlab@list.winehq.org/thread/JN42A3C7H6JEMMDKH7W56BE5DTHYQKJ6/) — серия из 4 патчей в comdlg32 (февраль 2026, Wine bug 51134). Она помечена как черновик, автор сообщал о закрытии. Политика выбора — `auto` или «принудительно портал», с откатом на диалог Wine. В штатные выпуски не вошла.
- Есть downstream-сборки с похожими патчами (например, обёртки KakaoTalk), это не upstream.

План:
1. Выбрать проверяемый runner: системный `wine` из nixpkgs или Proton из Steam, их не смешивать.
2. Собрать **отдельный** пакет Wine с актуальной версией патчей MR10060 (`wine.overrideAttrs { patches = …; }`). Подключать его только для выбранных префиксов, а не подменять все Wine и Proton автоматически.
3. Проверить по списку: `GetOpenFileName*`, `GetSaveFileName*`, `IFileOpenDialog`, `IFileSaveDialog`, выбор папки, несколько файлов, Unicode, перезапись, отмена, преобразование путей `Z:\…` ↔ Linux.
4. Для запросов, которые портал не выражает (шаблоны, хуки диалога), оставить штатный диалог Wine. Это делает политика `auto` из MR.

Пока п. 2 не сделан, Wine показывает свой диалог — это известное ограничение.
