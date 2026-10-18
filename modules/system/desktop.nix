# Hyprland, дисплейный менеджер, порталы, шрифты. Сама оболочка — modules/shell.
{
  pkgs,
  lib,
  username,
  host,
  appearance,
  config,
  ...
}: let
  startHyprland = "${config.programs.hyprland.package}/bin/start-hyprland";

  # Чей диалог выбора файлов: gtk — хостовый GTK, pixel — свой диалог
  # оболочки (pixel-portal), «Настройки → Система». pixel без оболочки сам
  # передаёт запрос GTK, так что диалог не пропадает.
  chooser =
    if config.pixel.system.desktop.fileChooser == "pixel"
    then ["pixel" "gtk"]
    else ["gtk"];
  pixel-portal = pkgs.callPackage ../shell/portal/package.nix {inherit username;};
in {
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

    # Qt-приложения (включая саму оболочку на Quickshell) ходят за шрифтом,
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

  # Вход: greetd. При загрузке сразу автологин в Hyprland (initial_session),
  # а после выхода из сессии — текстовый экран входа tuigreet. Блокировку
  # экрана, уведомления и всё остальное даёт своя оболочка (modules/shell).
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      initial_session = {
        command = startHyprland;
        user = username;
      };
      default_session = {
        command = "${lib.getExe pkgs.tuigreet} --time --remember --asterisks --greeting 'NixOS' --cmd ${startHyprland}";
        user = "greeter";
      };
    };
  };

  # Оболочке нужны: шрифт значков Material Symbols, ночной режим,
  # яркость, редактор соединений и микшер для «Настроек».
  # Яркость внешних мониторов по DDC/CI (ddcutil): доступ к /dev/i2c-*
  # для группы i2c, пользователь в ней (users.nix).
  hardware.i2c.enable = true;

  environment.systemPackages = with pkgs; [
    ddcutil
    gtk3 # gtk-launch — запуск приложений из своих биндов
    hyprsunset
    brightnessctl
    pavucontrol
    xdg-utils
  ];

  # ЕДИНЫЙ ДИАЛОГ ВЫБОРА ФАЙЛОВ.
  # Цель — чтобы любое приложение, как бы оно ни было установлено, показывало
  # одно и то же окно: GTK-диалог хоста в цветах обоев. Туда ведут три дороги:
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
        "org.freedesktop.impl.portal.FileChooser" = chooser;
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
      };
      # Запасной вариант для сессий с другим XDG_CURRENT_DESKTOP.
      common = {
        default = ["gtk"];
        "org.freedesktop.impl.portal.FileChooser" = chooser;
        "org.freedesktop.impl.portal.ScreenCast" = ["hyprland"];
        "org.freedesktop.impl.portal.Screenshot" = ["hyprland"];
      };
    };
    extraPortals = with pkgs;
      [
        xdg-desktop-portal-gtk
        xdg-desktop-portal-hyprland
      ]
      ++ lib.optional (config.pixel.system.desktop.fileChooser == "pixel") pixel-portal;
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
      material-symbols # значки оболочки (Material Symbols Rounded)
    ];

    # Без этого блока generic-семейства (sans-serif / monospace / serif)
    # резолвятся непредсказуемо. Порядок важен: первый доступный побеждает.
    fontconfig.defaultFonts = {
      sansSerif = [appearance.uiFont "Inter" "Noto Sans" "Noto Color Emoji"];
      serif = ["Noto Serif" "Noto Color Emoji"];
      monospace = [appearance.monoFont "Noto Sans Mono" "Symbols Nerd Font" "Noto Color Emoji"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
