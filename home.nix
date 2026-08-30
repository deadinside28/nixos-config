{ config, pkgs, ... }:

{
  # Подключаем наш модуль DMS
  imports = [
    ./modules/dms/default.nix
  ];

  home.username = "deadinside";
  home.homeDirectory = "/home/deadinside";
  home.stateVersion = "26.11";

  # Разрешаем Home Manager управлять собой
  programs.home-manager.enable = true;

  # --- Терминал Kitty ---
  programs.kitty = {
    enable = true;
    font = {
      name = "Noto Sans Mono CJK SC";
      size = 14;
    };
    settings = {
      confirm_os_window_close = 0;
    };
    extraConfig = ''
      include ~/.config/kitty/dank-theme.conf
      include ~/.config/kitty/dank-tabs.conf
      allow_remote_control yes
      listen_on unix:/tmp/kitty
    '';
  };
  
  # --- Fastfetch конфиг ---
  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
        "type": "auto",
        "padding": { "right": 3 }
      },
      "display": {
        "separator": " -> ",
        "color": { "separator": "white" }
      },
      "modules": [
        { "type": "os", "key": "OS ", "keyColor": "white" },
        { "type": "kernel", "key": " ├  ", "keyColor": "white" },
        { "type": "packages", "key": " ├ 󰏖 ", "keyColor": "white" },
        { "type": "shell", "key": " └  ", "keyColor": "white" },
        "break",
        { "type": "wm", "key": "WM ", "keyColor": "white" },
        { "type": "theme", "key": " ├ 󰉼 ", "keyColor": "white" },
        { "type": "icons", "key": " ├ 󰀻 ", "keyColor": "white" },
        { "type": "terminal", "key": " ├  ", "keyColor": "white" },
        { "type": "terminalfont", "key": " └  ", "keyColor": "white" },
        "break",
        { "type": "host", "key": "PC ", "keyColor": "white" },
        { "type": "cpu", "key": " ├  ", "keyColor": "white" },
        { "type": "gpu", "key": " ├ 󰢮 ", "keyColor": "white" },
        { "type": "memory", "key": " ├  ", "keyColor": "white" },
        { "type": "swap", "key": " ├ 󰓡 ", "keyColor": "white" },
        { "type": "disk", "key": " ├  ", "folders": "/", "keyColor": "white" },
        { "type": "disk", "key": " ├  ", "folders": "/mnt/GAMES", "keyColor": "white" },
        { "type": "display", "key": " └ 󰍹 ", "keyColor": "white" }
      ]
    }
  '';

  # --- Настройка Fish ---
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
      fastfetch
    '';
  };

  # --- 5. Системные службы (Systemd User Session) ---
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland Session Target";
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Wants = [ "dms.service" ]; 
    };
  };

  # ==============================================================
  # ДЕКЛАРАТИВНЫЙ АВТО-ИМПОРТ ЯРЛЫКОВ ИЗ APPIMAGE-RUN
  # ==============================================================
  
  # 1. Сервис, который находит и линкует .desktop и иконки
  systemd.user.services.sync-appimage-desktops = {
    Unit = {
      Description = "Sync .desktop and icons from appimage-run cache";
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "sync-appimage-desktops" ''
        CACHE_DIR="$HOME/.cache/appimage-run"
        APPS_DIR="$HOME/.local/share/applications"
        ICONS_DIR="$HOME/.local/share/icons"

        if [ -d "$CACHE_DIR" ]; then
          mkdir -p "$APPS_DIR" "$ICONS_DIR"
          
          # Симлинкаем .desktop файлы
          ${pkgs.findutils}/bin/find "$CACHE_DIR" -mindepth 2 -maxdepth 2 -name "*.desktop" -exec ln -sf {} "$APPS_DIR/" \;
          
          # Симлинкаем иконки
          ${pkgs.findutils}/bin/find "$CACHE_DIR" -mindepth 2 -maxdepth 2 \( -name "*.png" -o -name "*.svg" \) -exec ln -sf {} "$ICONS_DIR/" \;
        fi
      '';
    };
  };

  # 2. Путь-триггер (следит за изменениями в ~/.cache/appimage-run)
  systemd.user.paths.sync-appimage-desktops = {
    Unit = {
      Description = "Watch ~/.cache/appimage-run for new AppImages";
    };
    Path = {
      PathModified = "%h/.cache/appimage-run";
      Unit = "sync-appimage-desktops.service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}