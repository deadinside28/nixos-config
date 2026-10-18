# Патчи Wine: стандартные диалоги через портал

Взяты из [5sick/kakaotalk-debian-wrapper](https://github.com/5sick/kakaotalk-debian-wrapper)
(каталог `patches/`, коммит `91e9cf4`, выпуск 0.3.4) без изменений. Лицензия — GNU LGPL 2.1 или новее, как у Wine
(в том репозитории — `patches/COPYING.LIB`). Написаны для Wine 11.0 и чисто
накладываются на `wineWow64Packages.stable` из nixpkgs (11.0).

| Патч | Что делает |
|---|---|
| `0005-comdlg32-xdg-desktop-portal-file-chooser.patch` | При `HKCU\Software\Wine\FileDialog` `HostFileChooser=Y` диалоги `IFileDialog::Show` (открыть/сохранить без своих элементов) и `GetOpenFileNameW`/`GetSaveFileNameW` (без хуков и шаблонов) идут в `org.freedesktop.portal.FileChooser`. Фильтры, начальная папка и имя, несколько файлов, выбор папки передаются. Пути Linux возвращаются через известные папки префикса, иначе через ссылки в `C:\Linux\`. Без портала — обычный диалог Wine. ANSI-функции (`…A`) не затронуты. |
| `0006-shell32-browse-for-folder-host-chooser.patch` | `SHBrowseForFolderW` (выбор папки старым API) — через тот же портал. |

Подключение — `modules/system/wine-portal.nix`, переключатель «Системные диалоги в Wine» в «Настройки → Система → Игры» (`gaming.wineHostDialogs` в `system.json`).

Проверка — `test/e2e.sh` (описание в `docs/filechooser.md`, раздел Wine).
