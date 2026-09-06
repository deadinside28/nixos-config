# Системные пакеты и политика nixpkgs.
{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true;

  # ВНИМАНИЕ: разрешение действует на всю систему, а не только на WinBoat —
  # уязвимый Electron получит любое приложение, которое его запросит.
  # Добавлено ради winboat; периодически проверяй, нужно ли ещё.
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
  ];

  environment.systemPackages = with pkgs; [
    # --- Базовые утилиты и разработка ---
    git
    vscode
    gnome-text-editor
    gnome-calculator
    gnome-calendar
    psmisc # killall и компания
    fastfetch
    dsearch # мгновенный поиск файлов для DMS
    seahorse # работа с ключами
    onlyoffice-desktopeditors
    nixd # языковой сервер для Nix
    alejandra # автоформатер
    distrobox
    xhost # проброс графики XWayland в контейнер

    # appimage-run намеренно НЕ здесь: враппер приезжает
    # из modules/appimage-system.nix, иначе в PATH будет два разных.

    # --- Файловый менеджер и превью ---
    nautilus
    ffmpegthumbnailer
    webp-pixbuf-loader
    poppler_gi
    gnome-epub-thumbnailer

    # --- Wayland и инструменты Hyprland ---
    grim
    slurp
    wl-clipboard
    hyprpicker
    libnotify
    linux-wallpaperengine # живые обои из Steam Workshop

    # --- Темы и внешний вид ---
    nwg-look
    adwaita-icon-theme
    papirus-icon-theme
    adw-gtk3
    glib
    gsettings-desktop-schemas

    # --- Железо, игры и лаунчеры ---
    lact # панель управления AMD (RX 7800 XT)
    lutris
    heroic
    protonplus
    protontricks
    mangohud
    goverlay

    # --- Интернет и медиа ---
    google-chrome
    telegram-desktop
    ytmdesktop
    qbittorrent
    loupe
    mpv
    ffmpeg

    # --- Кодеки GStreamer ---
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    # --- Архиваторы ---
    file-roller
    unzip
    p7zip
    unar

    # --- Виртуализация ---
    winboat
  ];
}
