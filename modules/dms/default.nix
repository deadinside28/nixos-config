{ config, pkgs, ... }:

{
  xdg.configFile = {
    # Главный конфиг Hyprland
    "hypr/hyprland.lua".source = ./hyprland.lua;

    # Пользовательские модули DMS
    "hypr/dms/binds-user.lua".source = ./binds-user.lua;
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
}