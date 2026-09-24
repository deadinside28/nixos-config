# Hyprland, оболочка DMS, дисплейный менеджер, порталы, шрифты.
{
  pkgs,
  username,
  appearance,
  ...
}: {
  programs.hyprland.enable = true;
  programs.dconf.enable = true;

  # Эти переменные раздаёт pam_env при входе в сессию, то есть они достаются
  # вообще всему: грайтеру, systemd --user, Hyprland и всем его детям.
  # Раньше часть из них жила в hyprland.lua и до не-Hyprland процессов
  # не доходила.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron-приложения на Wayland
    # Путь к кодекам, чтобы Nautilus и другие программы их видели
    GST_PLUGIN_SYSTEM_PATH_1_0 = "/run/current-system/sw/lib/gstreamer-1.0";

    # Qt-приложения (включая сам DMS на Quickshell) ходят за шрифтом,
    # иконками, палитрой и файловыми диалогами в GTK. Плагин qgtk3 в
    # nixpkgs собирается всегда, ставить qt6ct не нужно.
    QT_QPA_PLATFORMTHEME = "gtk3";

    XCURSOR_THEME = appearance.cursorTheme;
    XCURSOR_SIZE = toString appearance.cursorSize;

    # GTK4 вне песочницы по умолчанию рисует свой диалог выбора файлов,
    # а не идёт в портал. Этот флаг заставляет его идти в портал — и там
    # его встречает тот же GTK-диалог, что и у всех остальных.
    GDK_DEBUG = "portals";
  };

  programs.dms-shell = {
    enable = true;
    systemd = {
      enable = true;
      restartIfChanged = true;
    };
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

          env = XCURSOR_THEME,${appearance.cursorTheme}
          env = XCURSOR_SIZE,${toString appearance.cursorSize}
          env = HYPRCURSOR_THEME,${appearance.cursorTheme}
          env = HYPRCURSOR_SIZE,${toString appearance.cursorSize}
          exec-once = hyprctl setcursor ${appearance.cursorTheme} ${toString appearance.cursorSize}
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

  # ЕДИНЫЙ ДИАЛОГ ВЫБОРА ФАЙЛОВ.
  # Цель — чтобы любое приложение, как бы оно ни было установлено, показывало
  # одно и то же окно: GTK-диалог хоста, крашеный DMS. Туда ведут три дороги:
  #   - нативные GTK3 и Qt (через qgtk3) рисуют его сами, у себя в процессе;
  #   - всё остальное (Flatpak, cpak, AppImage, GTK4, Chrome/Electron)
  #     приходит в портал FileChooser, и портал отдаёт его бэкенду gtk.
  # Поэтому FileChooser здесь прибит к gtk явно.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = {
      # Для XDG_CURRENT_DESKTOP=Hyprland портал читает hyprland-portals.conf,
      # и пакет xdg-desktop-portal-hyprland приносит свой такой файл. Он
      # перебивает common, поэтому маршруты нужно писать именно сюда:
      # файл из /etc/xdg побеждает файл из пакета.
      hyprland = {
        default = ["hyprland" "gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
      };
      # Запасной вариант для сессий с другим XDG_CURRENT_DESKTOP.
      common = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.FileChooser" = ["gtk"];
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
      };
    };
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
  };

  fonts = {
    # Базовый набор NixOS (DejaVu, Liberation, Noto CJK, цветные эмодзи).
    # По умолчанию ВЫКЛЮЧЕН, а fontconfig при этом всё равно прописывает
    # DejaVu как предпочитаемый sans/serif/mono. Пока набора нет, generic-семейства
    # разрешаются во что попало — обычно в первый попавшийся шрифт с широким
    # покрытием, то есть в Noto Sans CJK. Отсюда «странные» буквы везде.
    enableDefaultPackages = true;

    packages = with pkgs; [
      inter # UI-шрифт, есть кириллица
      fira-code
      jetbrains-mono
      noto-fonts # обычный Noto: латиница/кириллица без CJK-метрик
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      nerd-fonts.symbols-only
      nerd-fonts.jetbrains-mono
    ];

    # Без этого блока generic-семейства (sans-serif / monospace / serif)
    # резолвятся непредсказуемо. Порядок важен: первый доступный побеждает.
    fontconfig.defaultFonts = {
      sansSerif = [appearance.uiFont "Noto Sans" "Noto Color Emoji"];
      serif = ["Noto Serif" "Noto Color Emoji"];
      monospace = [appearance.monoFont "Noto Sans Mono" "Symbols Nerd Font" "Noto Color Emoji"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
