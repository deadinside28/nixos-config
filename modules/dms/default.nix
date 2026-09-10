{...}: {
  xdg.configFile = {
    # Главный конфиг Hyprland
    "hypr/hyprland.lua".source = ./hyprland.lua;

    # Пользовательские модули DMS
    "hypr/dms/binds.lua".source = ./binds.lua;
    "hypr/dms/windowrules.lua".source = ./windowrules.lua;
  };

  # ==========================================
  # ОВЕРРАЙДЫ FLATPAK
  # ==========================================

  # Глобальные настройки Flatpak
  xdg.dataFile."flatpak/overrides/global".text = ''
    [Context]
    devices=dri;
    filesystems=/run/current-system/sw/share/themes;/run/current-system/sw/share/icons;~/.icons:ro;~/.themes:ro;xdg-config/gtk-4.0:ro;xdg-config/gtk-3.0:ro;xdg-config/Kvantum:ro;xdg-config/MangoHud;xdg-cache:ro;xdg-data:ro;/nix/store:ro;~/.var/app/com.valvesoftware.Steam/.local/share/Steam/userdata:ro;

    [Environment]
    GTK_USE_PORTAL=1
    XDG_SESSION_TYPE=wayland
    XDG_SESSION_DESKTOP=Hyprland
    XDG_CURRENT_DESKTOP=Hyprland
    ELECTRON_OZONE_PLATFORM_HINT=auto
    QT_QPA_PLATFORM=wayland
  '';

  # Gear Lever — исключение из глобального xdg-data:ro.
  #
  # Его работа в том и состоит, чтобы писать ярлыки и иконки AppImage
  # в ~/.local/share, а глобальный оверрайд выше монтирует весь xdg-data
  # только для чтения. У Flatpak побеждает более конкретный путь, поэтому
  # точечно открываем на запись две нужные папки, а не весь xdg-data.
  #
  # `home` нужен, чтобы он видел образы в ~/Games и подобных местах.
  # Папку установки в его настройках держи вне ~/.local/share
  # (например ~/Applications) — иначе понадобится открыть и её.
  xdg.dataFile."flatpak/overrides/it.mijorus.gearlever".text = ''
    [Context]
    filesystems=home;xdg-data/applications;xdg-data/icons;
  '';
}
