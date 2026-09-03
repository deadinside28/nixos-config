{ config, pkgs, ... }:

{
  # --- Системные службы (Systemd User Session) ---
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland Session Target";
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # Подключаем стандартный автозапуск приложений вместе с DMS
      Wants = [ 
        "dms.service" 
        "xdg-desktop-autostart.target" 
      ]; 
    };
  };

  # ==============================================================
  # АВТОМАТИЧЕСКИЙ ИМПОРТ АВТОЗАПУСКА ИЗ ПЕСОЧНИЦ FLATPAK
  # ==============================================================

  systemd.user.services.sync-flatpak-autostart = {
    Unit = {
      Description = "Sync autostart desktop files from Flatpak sandbox to host";
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "sync-flatpak-autostart" ''
        VAR_APP="$HOME/.var/app"
        HOST_AUTOSTART="$HOME/.config/autostart"
        mkdir -p "$HOST_AUTOSTART"

        if [ -d "$VAR_APP" ]; then
          ${pkgs.findutils}/bin/find "$VAR_APP" -mindepth 4 -maxdepth 4 -path "*/config/autostart/*.desktop" 2>/dev/null | while read -r desktop_file; do
            
            # Надежное извлечение ID через grep (ищет то, что стоит сразу после .var/app/)
            app_id=$(echo "$desktop_file" | ${pkgs.gnugrep}/bin/grep -oP '(?<=.var/app/)[^/]+')
            target="$HOST_AUTOSTART/flatpak-$app_id.desktop"

            cp "$desktop_file" "$target"
            chmod +w "$target"
            
            # Строгая замена только в строке Exec (игнорирует TryExec и прочее)
            ${pkgs.gnused}/bin/sed -i -e "s|^Exec=.*|Exec=/bin/sh -c 'sleep 1; exec /run/current-system/sw/bin/flatpak run $app_id'|" "$target"
          done

          # Проверка на удаление старых ярлыков
          for host_file in "$HOST_AUTOSTART"/flatpak-*.desktop; do
            [ -e "$host_file" ] || continue
            app_id=$(basename "$host_file" | ${pkgs.gnused}/bin/sed -E 's|^flatpak-(.*)\.desktop$|\1|')
            if [ ! -d "$VAR_APP/$app_id/config/autostart" ]; then
              rm -f "$host_file"
            fi
          done
        fi
      '';
    };
  };

  systemd.user.paths.sync-flatpak-autostart = {
    Unit = {
      Description = "Watch ~/.var/app for Flatpak autostart changes";
    };
    Path = {
      PathModified = "%h/.var/app";
      Unit = "sync-flatpak-autostart.service";
    };
    Install = {
      WantedBy = [ "hyprland-session.target" ];
    };
  };

  systemd.user.services.youtube-music = {
    Unit = {
      Description = "YouTube Music Desktop App";
      PartOf = [ "graphical-session.target" ];
      After = [ 
        "graphical-session.target"
        "discord-flatpak-rpc.service"
      ];
    };
    Service = {
      Type = "simple";
      # Умная проверка: ждем появление реального сокета Discord до 5 секунд
      ExecStartPre = pkgs.writeShellScript "wait-for-discord-socket" ''
        for i in $(seq 1 30); do
          if [ -S "$XDG_RUNTIME_DIR/app/com.discordapp.Discord/discord-ipc-0" ]; then
            sleep 2
            exit 0
          fi
          sleep 2
        done
        exit 0
      '';
      ExecStart = "${pkgs.lib.getExe pkgs.ytmdesktop}";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install = {
      WantedBy = [ "hyprland-session.target" ];
    };
  };
}