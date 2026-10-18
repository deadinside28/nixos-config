# Состояние по роадмапу

Что сделано в коде по документу «Pixel DE: требования и план развития» (18.10.2026). «Сделано» значит: написано, проверено тестами и линтерами, где это возможно без живой системы. **На железе пока ничего не проверялось** — чек-лист в `docs/releases.md`.

| Пункт | Что сделано | Где | Осталось |
|---|---|---|---|
| P0 `extract()`, `transfer()`, вставка | ошибки не теряются, распакованное сохраняется | `modules/shell/fileops.sh`, тест | — |
| P0 пересборка из GUI | отдельная служба `pixel-rebuild.service`, переподключение после перезапуска | `SystemConfig.qml` | проверить `switch` |
| P0 блокировка перед сном | ожидание `secure`, delay-ингибитор logind, `lock-session` | `Power.qml`, `Lock.qml` | проверить крышку и кнопку |
| P1 Flatpak-права | убраны `~/nixos-config`, `xdg-data`, `xdg-cache` | `modules/hyprland/default.nix` | раздать рабочие папки по приложениям |
| P1 AppImage | снова прямой запуск через nix-ld, библиотеки как у appimage-run | `modules/system/appimage.nix`, `nix-ld.nix` | — |
| P1 превью | очередь, лимит, ключ по mtime | `Thumbs.qml` | — |
| P1 `FilesWindow` | виртуализация сетки папок | `FilesWindow.qml` | дальнейшее разбиение файла |
| P1 таймаут systemd | 10 с, docker 30 с | `users.nix` | — |
| Андервольт после сна | без `RemainAfterExit`, цели сна | `boot.nix` | — |
| `stateVersion` | не трогался, как требует роадмап | — | сверить с историей установки |
| 5.4 схема `system.json` | опции `pixel.system`, `schemaVersion` | `gui-settings.nix` | — |
| 5.4 настройки | резервная копия, восстановление, `schemaVersion` | `Settings.qml` | — |
| 5.4 путь к конфигу | `configDir` во `flake.nix` | — | — |
| 6 меню приложений | правки поверх `.desktop`, папки, свои команды, источник | `Apps.qml`, `MenuPage.qml` | ручная сортировка перетаскиванием |
| 7 режимы окон | 5 режимов, свой режим стола, перекладка открытых окон | `WindowModes.qml` | точное дерево тайлинга (сейчас — раскладка и порядок) |
| 8–9 реестр и «Память» | размеры Nix/Flatpak, очистка по правилам | `storage.sh`, `Storage.qml` | расширять правила путей |
| 10 магазин | каталог по `flake.lock`, Flatpak, желаемое/фактическое | `store.sh`, `Store.qml` | скриншоты AppStream, отмена задач |
| 11 диалог файлов | backend портала, запасной путь в GTK | `modules/shell/portal`, `docs/filechooser.md` | привязка к родителю; Wine — отдельная сборка |
| 12 заметки, календарь | Markdown-заметки; календарь с повторами, `.ics`, службой напоминаний | `Notes.qml`, `Calendar.qml`, `reminders.sh` | синхронизация (по решению) |
| 12.3 замена GNOME | — | — | матрицы паритета перед удалением gnome-calendar, text-editor и т. д. |
| 13 Quick Share | исследование, rquickshare переключателем | `docs/quickshare.md` | своя служба на `rqs_lib`; аккаунт заблокирован |
| 14 метрики | `pixel-metrics` (PSS/USS, VRAM, CPU) | `metrics.sh` | снять исходный замер |
| 15 выпуски | процесс, схемы, сценарии | `docs/releases.md` | — |
| 5.2 общая MD3E-библиотека | — | — | отделить `widgets/` от Quickshell для самостоятельных приложений |
