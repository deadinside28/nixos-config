{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
  ];

  # ==========================================
  # 1. ЗАГРУЗКА И ЯДРО
  # ==========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Ранняя загрузка драйвера видеокарты (чтобы не было серого экрана)
  boot.initrd.kernelModules = ["amdgpu"];

  # Отключаем текстовые логи при загрузке
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # Экран загрузки с логотипом материнки (как в Fedora)
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };

  # Параметры "тихой" загрузки
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "quiet"
    "splash"
    "boot.shell_on_fail"
    "loglevel=3"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "usbcore.autosuspend=-1"
  ];

  # Включаем планировщик sched-ext (по умолчанию будет запущен scx_rustland)
  services.scx.enable = true;
  # services.scx.scheduler = "scx_rusty"; # Раскомментируй, если захочешь сменить планировщик вручную

  # Чтение потребляемой мощности и управление Curve Optimizer
  boot.extraModulePackages = with config.boot.kernelPackages; [ryzen-smu];
  boot.kernelModules = ["ryzen_smu" "k10temp"];
  boot.blacklistedKernelModules = [];

  # Системный сервис для андервольта
  systemd.services.ryzen-undervolt = {
    description = "AMD Ryzen 7 5700X3D Undervolt";
    wantedBy = ["multi-user.target" "post-resume.target"];
    after = ["suspend.target"];
    serviceConfig = {
      Type = "oneshot";
      # Теперь скрипт подтягивается декларативно из папки scripts
      ExecStart = "${pkgs.python3}/bin/python ${./scripts/ruv.py} -c 8 -o -25";
      RemainAfterExit = true;
    };
  };

  # ==========================================
  # 2. СЕТЬ И ЛОКАЛИЗАЦИЯ
  # ==========================================
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    firewall = {
      allowedTCPPorts = [59999]; # Sunshine
      allowedUDPPorts = [59999]; # Sunshine
    };
  };

  time.timeZone = "Europe/Moscow";

  i18n.defaultLocale = "ru_RU.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # ==========================================
  # 3. БАЗОВЫЕ СЕРВИСЫ
  # ==========================================

  services.gvfs.enable = true; # Включаем поддержку Корзины, сетевых дисков и MTP для Nautilus

  services.xserver = {
    enable = true;

    xkb = {
      layout = "us,ru";
      variant = "";
      options = "grp:alt_shift_toggle";
    };
  };

  # ==========================================
  # ИНТЕГРАЦИИ, СЕКРЕТЫ И DISCORD RPC
  # ==========================================

  # 1. Включаем хранилище ключей
  services.gnome.gnome-keyring.enable = true;

  # 2. "Мост" для передачи статуса из нативной системы в Flatpak-Discord
  systemd.user.services.discord-flatpak-rpc = {
    description = "Bridge Discord Flatpak RPC to host";
    wantedBy = ["default.target"];
    script = ''
      # Симлинк, который перенаправляет канал связи из песочницы в основную систему
      ln -sf $XDG_RUNTIME_DIR/app/com.discordapp.Discord/discord-ipc-0 $XDG_RUNTIME_DIR/discord-ipc-0
    '';
  };

  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
    packages = [
      "com.discordapp.Discord"
      "io.github.kolunmi.Bazaar"
      "com.github.tchx84.Flatseal"
    ];
  };

  services.printing.enable = true;

  # Звук (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Обнаружение в локальной сети (Sunshine / MoonDeck)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  # ==========================================
  # 4. ИГРЫ И АППАРАТНЫЕ УТИЛИТЫ
  # ==========================================
  hardware.steam-hardware.enable = true; # Поддержка Steam Controller
  programs.gamemode.enable = true; # Оптимизация системы под игры
  programs.gpu-screen-recorder.enable = true;

  # Нативный Steam через Nix
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true; # Интеграция Gamescope
  };

  # Gamescope (Chaotic-Nyx подтянет свежую версию с патчами)
  programs.gamescope.enable = true;
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # Симуляция нажатий геймпада
    openFirewall = true; # Порты для Moonlight
  };

  # Управление кулерами/частотами AMD (LACT)
  systemd.packages = with pkgs; [lact];
  systemd.services.lactd.wantedBy = ["multi-user.target"];

  # ==========================================
  # 5. ДЕСКТОП И WAYLAND (Hyprland + DMS)
  # ==========================================

  programs.hyprland.enable = true;
  programs.dconf.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Electron-приложения на Wayland
    # Указываем путь к кодекам, чтобы Nautilus и другие программы их видели
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

  # ==========================================
  # ДИСПЛЕЙНЫЙ МЕНЕДЖЕР (DANK GREETER)
  # ==========================================
  services.displayManager = {
    dms-greeter = {
      enable = true;
      compositor = {
        name = "hyprland";

        # Передаем настройки напрямую в Hyprland-сессию экрана входа
        customConfig = ''

          misc {
            disable_hyprland_logo = true
            force_default_wallpaper = 0
          }

          # Отключаем второй монитор (Acer)
          monitor = HDMI-A-2, disable

          # Убеждаемся, что основной монитор (LG Ultrawide) работает корректно
          monitor = HDMI-A-1, 2560x1080@100.000, 0x0, 1

          # Применяем системный курсор Adwaita для экрана входа
          env = XCURSOR_THEME,Adwaita
          env = XCURSOR_SIZE,20
          env = HYPRCURSOR_THEME,Adwaita
          env = HYPRCURSOR_SIZE,20
          exec-once = hyprctl setcursor Adwaita 20
        '';
      };

      configHome = "/home/deadinside";
    };

    autoLogin = {
      enable = true;
      user = "deadinside";
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

    # Новые имена пакетов Nerd Fonts в unstable-ветке:
    nerd-fonts.symbols-only
    nerd-fonts.jetbrains-mono
  ];

  # ==========================================
  # 6. СИСТЕМНЫЕ ПАКЕТЫ
  # ==========================================
  nixpkgs.config.allowUnfree = true;

  # Разрешаем старый Electron для WinBoat
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
  ];

  environment.systemPackages = with pkgs; [
    # ==========================================
    # 1. БАЗОВЫЕ УТИЛИТЫ И РАЗРАБОТКА
    # ==========================================
    git # Контроль версий (мастхэв для кодинга на C# и других проектов)
    vscode # Редактор кода Visual Studio Code
    gnome-text-editor # Простой и легкий нативный текстовый редактор
    gnome-calculator # <-- Добавлен калькулятор
    gnome-calendar # <-- Добавлен календарь
    appimage-run
    psmisc # Консольные утилиты (например, killall для завершения зависших процессов)
    fastfetch # Вывод красивой информации о системе в терминале
    dsearch # Мгновенный поиск файлов для DMS
    seahorse # Приложение для работы с ключами
    onlyoffice-desktopeditors # Офис
    nixd # Cовременный языковой сервер для Nix
    alejandra # Автоформатер кода
    distrobox
    xhost # Критически важно для проброса графики XWayland в контейнер

    # ==========================================
    # 2. ФАЙЛОВЫЙ МЕНЕДЖЕР И ПРЕВЬЮ ФАЙЛОВ
    # ==========================================
    nautilus # Основной файловый менеджер
    ffmpegthumbnailer # Генерация превьюшек для видеофайлов
    webp-pixbuf-loader # Поддержка изображений WebP в системе
    poppler_gi # Рендер PDF (для превью документов)
    gnome-epub-thumbnailer # Превьюшки для электронных книг (полезно для библиотеки детективов)

    # ==========================================
    # 3. WAYLAND И ИНСТРУМЕНТЫ HYPRLAND
    # ==========================================
    grim # Утилита для создания скриншотов
    slurp # Выбор области экрана (работает в паре с grim)
    wl-clipboard # Управление буфером обмена в Wayland
    hyprpicker # Пипетка для захвата цвета с экрана
    libnotify # Библиотека для работы всплывающих уведомлений
    linux-wallpaperengine # Движок для установки живых обоев из Steam Workshop

    # ==========================================
    # 4. ТЕМЫ И ВНЕШНИЙ ВИД (GTK)
    # ==========================================
    nwg-look # GUI-утилита для настройки тем GTK, курсоров и иконок
    adwaita-icon-theme # Стандартный набор иконок GNOME
    papirus-icon-theme # Популярный красивый набор иконок
    adw-gtk3 # Тема для стилизации старых GTK3-приложений под современный дизайн
    glib # Системные схемы и библиотеки (нужны для правильной работы тем)
    gsettings-desktop-schemas # Схемы настроек (чтобы настройки внешнего вида не слетали)

    # ==========================================
    # 5. ЖЕЛЕЗО, ИГРЫ И ЛАУНЧЕРЫ
    # ==========================================
    lact # Панель управления видеокартами AMD (мониторинг и частоты твоей RX 7800 XT)
    lutris # Менеджер игр (для GOG, Epic Games и сторонних установок)
    heroic # Альтернативный лаунчер для Epic Games и GOG
    protonplus # Удобная утилита для скачивания кастомных версий Proton (GE-Proton)
    protontricks # Аналог Winetricks для Steam (установка шрифтов/библиотек в префиксы игр)
    mangohud # Оверлей мониторинга ресурсов в играх (FPS, температуры)
    goverlay # Графический интерфейс для настройки MangoHud

    # ==========================================
    # 6. ИНТЕРНЕТ, МЕДИА И ТОРРЕНТЫ
    # ==========================================
    google-chrome # Веб-браузер
    telegram-desktop # Мессенджер
    ytmdesktop # YouTube Music Desktop App для прослушивания музыки
    qbittorrent # Торрент-клиент
    loupe # Нативный просмотрщик изображений
    mpv # Легкий и всеядный видеоплеер
    ffmpeg # Мощный набор библиотек для работы с видео/аудио (конвертация, запись)

    # ==========================================
    # 7. КОДЕКИ GSTREAMER (Аппаратное ускорение)
    # ==========================================
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav

    # ==========================================
    # 8. АРХИВАТОРЫ
    # ==========================================
    file-roller # GUI-архиватор, отлично интегрируется с Nautilus
    unzip # Распаковка .zip
    p7zip # Распаковка .7z
    unar # Распаковка .rar и других проприетарных форматов

    # ==========================================
    # 9. ВИРТУАЛИЗАЦИЯ
    # ==========================================
    winboat
  ];

  # ==========================================
  # 7. NIX-LD (Прямой запуск AppImage и сторонних бинарников)
  # ==========================================
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Базовые системные библиотеки
      stdenv.cc.cc.lib
      glibc
      zlib
      openssl
      fuse
      fuse3
      icu
      libuuid
      libxml2
      libsecret
      harfbuzz
      freetype
      fontconfig

      # Графика и UI тулкиты (включая виновника торжества - libadwaita)
      mesa
      libGL
      libGLU
      libepoxy
      libdrm
      vulkan-loader
      gtk3
      gtk4
      libadwaita
      pango
      cairo
      atk
      gdk-pixbuf
      glib

      # X11 и Wayland (полный комплект)
      wayland
      libX11
      libXext
      libXrender
      libXfixes
      libXcomposite
      libXdamage
      libXcursor
      libXi
      libXrandr
      libXScrnSaver
      libXtst
      libxcb
      libxkbcommon

      # Звук и медиа
      alsa-lib
      libpulseaudio
      pipewire
      cups
      ffmpeg

      # Специфичное для Electron и браузерных движков
      nss
      nspr
      expat
      dbus
      at-spi2-core

      # Аудио, ввод и легаси-крипто-стек для эмуляторов/игр (ShadPS4, RPCS3 и т.п.)
      openal
      libjack2
      sndio
      SDL2
      libevdev
      e2fsprogs
      libuuid
      libedit
      libpng

      # Математика и компрессия (gmp тянется через крипто-стек)
      gmp
      nettle
      libtasn1
      p11-kit
      bzip2
      xz
      zstd
      brotli
      libffi

      # Прочие фреймворки
      udev
      libnotify
    ];
  };

  # ==========================================
  # ВИРТУАЛИЗАЦИЯ И DOCKER (WinBoat)
  # ==========================================
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = true;

  # ==========================================
  # 8. ПОЛЬЗОВАТЕЛЬ И HOME MANAGER
  # ==========================================
  programs.fish.enable = true; # Системное включение оболочки

  users.users."deadinside" = {
    isNormalUser = true;
    description = "deadinside";
    extraGroups = ["networkmanager" "wheel" "docker"];
    shell = pkgs.fish;
    packages = [];
  };

  system.stateVersion = "26.11";
  systemd.settings = {
    Manager = {
      DefaultTimeoutStopSec = "5s";
    };
  };

  systemd.user.settings = {
    Manager = {
      DefaultTimeoutStopSec = "5s";
    };
  };
}
