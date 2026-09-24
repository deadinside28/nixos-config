{appearance, ...}: {
  xdg.configFile = {
    # Главный конфиг Hyprland
    "hypr/hyprland.lua".source = ./hyprland.lua;

    # Пользовательские модули DMS
    "hypr/dms/binds.lua".source = ./binds.lua;
    "hypr/dms/windowrules.lua".source = ./windowrules.lua;

    # Портал скриншаринга Hyprland. allow_token_by_default ставит галку
    # «Разрешить токен восстановления» в окне выбора экрана: приложение,
    # которое умеет сохранять разрешение (Steam Remote Play, OBS и т.п.),
    # не будет спрашивать экран заново при каждом подключении.
    "hypr/xdph.conf".text = ''
      screencopy {
          allow_token_by_default = true
      }
    '';
  };

  # ==========================================
  # ОВЕРРАЙДЫ FLATPAK
  # ==========================================
  # Песочница не видит хост, поэтому всё, что должно совпадать с системой,
  # приходится прокидывать руками: темы и иконки (их красит DMS), настройки
  # GTK и Qt, шрифты и курсор. Сами файлы шрифтов flatpak в nixpkgs уже
  # пропатчен пробрасывать сам, но каталог из /run/current-system добавлен
  # на случай, если приложение ищет их по абсолютному пути.
  #
  # Qt внутри песочницы — только через портал. С gtk3 Qt нарисовал бы
  # GTK-диалог прямо в песочнице, и тот видел бы только её файлы, а не
  # твои. Портал показывает диалог хоста и сам пробрасывает выбранное.

  xdg.dataFile."flatpak/overrides/global".text = ''
    [Context]
    devices=dri;
    filesystems=/run/current-system/sw/share/themes;/run/current-system/sw/share/icons;/run/current-system/sw/share/X11/fonts:ro;~/.icons:ro;~/.themes:ro;xdg-config/gtk-4.0:ro;xdg-config/gtk-3.0:ro;xdg-config/fontconfig:ro;xdg-config/qt5ct:ro;xdg-config/qt6ct:ro;xdg-config/Kvantum:ro;xdg-config/MangoHud;xdg-cache:ro;xdg-data:ro;/nix/store:ro;~/.var/app/com.valvesoftware.Steam/.local/share/Steam/userdata:ro;xdg-desktop;xdg-documents;xdg-download;xdg-music;xdg-pictures;xdg-public-share;xdg-templates;xdg-videos;~/AppImages;~/filter1_optimized;~/Games;~/nixos-config;~/winboat;~/work;

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
}
