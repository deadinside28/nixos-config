{
  pkgs,
  lib,
  appearance,
  ...
}: {
  xdg.configFile = {
    # Главный конфиг Hyprland
    "hypr/hyprland.lua".source = ./hyprland.lua;

    # Бинды и правила окон (подключаются из hyprland.lua)
    "hypr/binds.lua".source = ./binds.lua;
    "hypr/windowrules.lua".source = ./windowrules.lua;

    # Портал скриншаринга Hyprland. allow_token_by_default ставит галку
    # «Разрешить токен восстановления» в окне выбора экрана: приложение,
    # которое умеет сохранять разрешение (Steam Remote Play, OBS и т.п.),
    # не будет спрашивать экран заново при каждом подключении.
    "hypr/xdph.conf".text = ''
      screencopy {
          allow_token_by_default = true
          force_shm = true
          max_fps = 60
      }
    '';
  };

  # ==========================================
  # ОВЕРРАЙДЫ FLATPAK
  # ==========================================
  # Песочница не видит хост, поэтому всё, что должно совпадать с системой,
  # приходится прокидывать руками: темы и иконки (их красит оболочка), настройки
  # GTK и Qt, шрифты и курсор. Сами файлы шрифтов flatpak в nixpkgs уже
  # пропатчен пробрасывать сам, но каталог из /run/current-system добавлен
  # на случай, если приложение ищет их по абсолютному пути.
  #
  # Qt внутри песочницы — только через портал. С gtk3 Qt нарисовал бы
  # GTK-диалог прямо в песочнице, и тот видел бы только её файлы, а не
  # твои. Портал показывает диалог хоста и сам пробрасывает выбранное.

  # Глобально — только то, что нужно для одинакового вида, и только на
  # чтение. Права на запись и на личные данные выдаются конкретным
  # приложениям (файлы ниже или Flatseal). Целиком ~/.local/share и
  # ~/.cache не открываются: там связки ключей, профили и данные других
  # программ. ~/nixos-config — тем более: запись в flake из песочницы
  # означала бы root при следующей пересборке.
  #
  # Рабочие папки (Загрузки, Документы…) и всё, где лежат игры, открыты
  # всем: эмулятор или лаунчер из Flatpak должен видеть игру на любом
  # диске, а раздавать это по приложениям неудобно. Диски — /mnt (второй
  # SSD /mnt/GAMES, hosts/*/disks.nix), /media и /run/media (подключённые
  # из «Памяти» и флешки).
  xdg.dataFile."flatpak/overrides/global".text = ''
    [Context]
    devices=dri;
    filesystems=/run/current-system/sw/share/themes:ro;/run/current-system/sw/share/icons:ro;/run/current-system/sw/share/X11/fonts:ro;~/.icons:ro;~/.themes:ro;xdg-data/icons:ro;xdg-data/themes:ro;xdg-data/fonts:ro;xdg-config/gtk-4.0:ro;xdg-config/gtk-3.0:ro;xdg-config/fontconfig:ro;xdg-config/qt5ct:ro;xdg-config/qt6ct:ro;xdg-config/Kvantum:ro;xdg-config/MangoHud:ro;/nix/store:ro;~/.var/app/com.valvesoftware.Steam/.local/share/Steam/userdata:ro;xdg-desktop;xdg-documents;xdg-download;xdg-music;xdg-pictures;xdg-public-share;xdg-templates;xdg-videos;~/AppImages;~/Games;~/winboat;/mnt;/media;/run/media;

    [Environment]
    MANGOHUD=1
    GTK_USE_PORTAL=1
    XDG_SESSION_TYPE=wayland
    XDG_SESSION_DESKTOP=Hyprland
    XDG_CURRENT_DESKTOP=Hyprland
    ELECTRON_OZONE_PLATFORM_HINT=auto
    QT_QPA_PLATFORM=wayland
    QT_QPA_PLATFORMTHEME=xdgdesktopportal
    XCURSOR_THEME=${appearance.cursorTheme}
    XCURSOR_SIZE=${toString appearance.cursorSize}
  '';

  # MangoJuice правит конфиг MangoHud; остальным (игры со слоем MangoHud)
  # он нужен только на чтение — см. global
  xdg.dataFile."flatpak/overrides/io.github.radiolamp.mangojuice".text = ''
    [Context]
    filesystems=xdg-config/MangoHud;
  '';
}
