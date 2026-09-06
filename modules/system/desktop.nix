# Hyprland, оболочка DMS, дисплейный менеджер, порталы, шрифты.
{
  pkgs,
  username,
  ...
}: {
  programs.hyprland.enable = true;
  programs.dconf.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron-приложения на Wayland
    # Путь к кодекам, чтобы Nautilus и другие программы их видели
    GST_PLUGIN_SYSTEM_PATH_1_0 = "/run/current-system/sw/lib/gstreamer-1.0";
  };

  programs.dms-shell = {
    enable = true;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };
    enableSystemMonitoring = true;
    enableVPN = true;
    enableDynamicTheming = true;
    enableAudioWavelength = true;
    enableCalendarEvents = true;
  };

  services.displayManager = {
    dms-greeter = {
      enable = true;
      compositor = {
        name = "hyprland";
        customConfig = ''
          misc {
            disable_hyprland_logo = true
            force_default_wallpaper = 0
          }

          # Отключаем второй монитор (Acer)
          monitor = HDMI-A-2, disable

          # Основной монитор (LG Ultrawide)
          monitor = HDMI-A-1, 2560x1080@100.000, 0x0, 1

          env = XCURSOR_THEME,Adwaita
          env = XCURSOR_SIZE,20
          env = HYPRCURSOR_THEME,Adwaita
          env = HYPRCURSOR_SIZE,20
          exec-once = hyprctl setcursor Adwaita 20
        '';
      };
      configHome = "/home/${username}";
    };

    autoLogin = {
      enable = true;
      user = username;
    };
    defaultSession = "hyprland";
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common = {
      default = ["gtk"];
      "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
      "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  fonts.packages = with pkgs; [
    inter
    fira-code
    jetbrains-mono
    noto-fonts-cjk-sans
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
  ];
}
