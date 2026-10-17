# Pixel Shell — своя оболочка на Quickshell вместо DMS: панель задач,
# лаунчер, быстрые настройки, уведомления, экран блокировки, агент polkit
# и приложение «Настройки», из которого настраивается вся система.
#
# QML лежит в ./qml и раскладывается в ~/.config/quickshell/pixel.
# Изменяемое состояние живёт вне Nix:
#   ~/.local/state/pixel-shell/settings.json — настройки оболочки;
#   ~/.local/state/pixel-shell/colors.json   — палитра из обоев (matugen);
#   ~/.config/hypr/shell/*.lua               — окна, ввод, мониторы, цвета рамок;
#   <flake>/system.json                      — настройки NixOS из раздела «Система».
{
  config,
  pkgs,
  lib,
  appearance,
  hostname,
  ...
}: let
  flake = "${config.home.homeDirectory}/nixos-config";
  stateDir = "${config.xdg.stateHome}/pixel-shell";
  configHome = config.xdg.configHome;

  quickshell = pkgs.quickshell;

  # matugen: полный набор шаблонов и только цвета оболочки (если
  # «Красить приложения» выключено).
  shellTemplate = ''
    [templates.shell]
    input_path = "${./matugen/shell-colors.json}"
    output_path = "${stateDir}/colors.json"
  '';
  matugenShell = pkgs.writeText "matugen-shell.toml" ''
    [config]
    ${shellTemplate}
  '';
  matugenFull = pkgs.writeText "matugen-full.toml" ''
    [config]
    ${shellTemplate}
    [templates.gtk3]
    input_path = "${./matugen/gtk.css}"
    output_path = "${configHome}/gtk-3.0/gtk.css"

    [templates.gtk4]
    input_path = "${./matugen/gtk.css}"
    output_path = "${configHome}/gtk-4.0/gtk.css"

    [templates.kitty]
    input_path = "${./matugen/kitty.conf}"
    output_path = "${configHome}/kitty/pixel-theme.conf"

    [templates.hyprland]
    input_path = "${./matugen/hyprland.lua}"
    output_path = "${configHome}/hypr/shell/colors.lua"
  '';

  # Данные из Nix, которые нужны QML. Остальной QML — статичные файлы.
  nixQml = ''
    pragma Singleton
    import Quickshell

    // Сгенерировано из modules/shell/default.nix.
    Singleton {
        readonly property string uiFont: "${appearance.uiFont}"
        readonly property string uiFontStyle: "${appearance.uiFontStyle}"
        readonly property int uiFontSize: ${toString appearance.uiFontSize}
        readonly property string monoFont: "${appearance.monoFont}"
        readonly property string monoFontStyle: "${appearance.monoFontStyle}"
        readonly property int monoFontSize: ${toString appearance.monoFontSize}
        readonly property string terminal: "kitty"
        readonly property string matugen: "${lib.getExe pkgs.matugen}"
        readonly property string matugenConfig: "${matugenFull}"
        readonly property string matugenShellConfig: "${matugenShell}"
        readonly property string flake: "${flake}"
        readonly property string hostname: "${hostname}"
        readonly property string quickshellVersion: "${quickshell.version}"
    }
  '';

  # Шейдеры QML компилируются заранее (qsb): тематические значки.
  shaders = pkgs.runCommand "pixel-shell-shaders" {nativeBuildInputs = [pkgs.qt6.qtshadertools];} ''
    mkdir -p $out
    for f in ${./shaders}/*.frag; do
      qsb --qt6 -o "$out/$(basename "$f").qsb" "$f"
    done
  '';

  # pixel-shell <цель> <функция> [аргументы] — IPC для биндов.
  pixel-shell = pkgs.writeShellScriptBin "pixel-shell" ''
    if [ $# -eq 0 ] || [ "$1" = show ]; then
      exec ${lib.getExe quickshell} -c pixel ipc show
    fi
    exec ${lib.getExe quickshell} -c pixel ipc call "$@"
  '';

  # Скриншоты: area | full | window. Картинка — в буфер и в уведомление.
  pixel-screenshot = pkgs.writeShellApplication {
    name = "pixel-screenshot";
    runtimeInputs = with pkgs; [grim slurp wl-clipboard libnotify hyprpicker jq hyprland coreutils];
    text = ''
      f="''${XDG_RUNTIME_DIR:-/tmp}/screenshot.png"
      case "''${1:-area}" in
        area)
          hyprpicker -r -z & pid=$!
          sleep 0.1
          geom=$(slurp -b 00000099 -c ffffff -w 2 -s 00000000) || { kill "$pid"; exit 0; }
          grim -g "$geom" "$f"; kill "$pid"; what="Скриншот области" ;;
        full)
          grim "$f"; what="Скриншот экрана" ;;
        window)
          geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
          grim -g "$geom" "$f"; what="Скриншот окна" ;;
        *) echo "pixel-screenshot area|full|window" >&2; exit 1 ;;
      esac
      wl-copy < "$f"
      mkdir -p "$HOME/Pictures/Screenshots"
      saved="$HOME/Pictures/Screenshots/$(date +%F_%H-%M-%S).png"
      cp "$f" "$saved"
      notify-send -a "Скриншот" -i "$saved" "$what" "Скопирован в буфер обмена и сохранён в Pictures/Screenshots"
    '';
  };

  # Запись экрана: повторный вызов останавливает. pixel-record <монитор> [mic]
  # Параметры (кадры, кодек, качество, папка) — из «Настройки → Экран»,
  # оболочка пишет их в record.env.
  pixel-record = pkgs.writeShellApplication {
    name = "pixel-record";
    runtimeInputs = with pkgs; [procps psmisc ffmpeg libnotify coreutils];
    excludeShellChecks = ["SC1091"];
    text = ''
      REC_FPS=60 REC_CODEC=av1 REC_QUALITY=very_high REC_CONTAINER=mp4 REC_CURSOR=yes REC_DIR="$HOME/Videos"
      env="''${XDG_STATE_HOME:-$HOME/.local/state}/pixel-shell/record.env"
      # shellcheck source=/dev/null
      [ -r "$env" ] && . "$env"
      last="''${XDG_RUNTIME_DIR:-/tmp}/pixel-record.last"

      if pidof gpu-screen-recorder >/dev/null; then
        killall -SIGINT gpu-screen-recorder
        while pidof gpu-screen-recorder >/dev/null; do sleep 0.1; done
        file=$(cat "$last" 2>/dev/null || true)
        thumb="''${XDG_RUNTIME_DIR:-/tmp}/gsr_thumb.jpg"
        ffmpeg -y -i "$file" -vframes 1 "$thumb" -loglevel error || true
        notify-send -a "Запись экрана" -i "$thumb" "Запись завершена" "Файл сохранён: $file"
        exit 0
      fi
      monitor=''${1:?монитор}
      audio="default_output"; label="Без микрофона"
      if [ "''${2:-}" = mic ]; then audio="default_output|default_input"; label="С микрофоном"; fi
      mkdir -p "$REC_DIR"
      file="$REC_DIR/video_$(date +%F_%H-%M-%S).$REC_CONTAINER"
      echo "$file" > "$last"
      gpu-screen-recorder -w "$monitor" -f "$REC_FPS" -a "$audio" -k "$REC_CODEC" -q "$REC_QUALITY" \
        -cursor "$REC_CURSOR" -c "$REC_CONTAINER" -o "$file" &
      notify-send -a "Запись экрана" -i camera-video "Запись начата" "$label · ''${REC_CODEC^^}, $REC_FPS кадров/с"
    '';
  };

  # Пересборка из «Настройки → Система». Сборка идёт от пользователя
  # (flake лежит в домашней папке, root на чужой git-репозиторий ругается),
  # а переключение — через pkexec, пароль спрашивает агент polkit оболочки.
  # Строки «::stage …» — подписи этапов для интерфейса, «@nix {…}» —
  # события Nix (--log-format internal-json), из них считается прогресс.
  pixel-rebuild = pkgs.writeShellApplication {
    name = "pixel-rebuild";
    # Команды для pkexec намеренно в одинарных кавычках: $1 раскрывает
    # уже bash под root, а не этот скрипт.
    excludeShellChecks = ["SC2016"];
    runtimeInputs = with pkgs; [coreutils git];
    text = ''
      mode=''${1:-switch}
      flake="${flake}"
      host="${hostname}"
      sudo_sh() { /run/wrappers/bin/pkexec ${pkgs.bash}/bin/bash -c "$1" pixel-rebuild "''${@:2}"; }

      case "$mode" in
        rollback)
          echo "::stage Жду подтверждения…"
          sudo_sh '/run/current-system/sw/bin/nixos-rebuild switch --rollback'
          echo "::stage Откат выполнен"
          exit 0 ;;
        gc)
          days=$(${lib.getExe pkgs.jq} -r '.nix.gcDays // 14' "$flake/system.json" 2>/dev/null || echo 14)
          echo "::stage Чищу пользовательские поколения…"
          nix-collect-garbage --delete-older-than "''${days}d"
          echo "::stage Жду подтверждения для системных поколений…"
          sudo_sh "/run/current-system/sw/bin/nix-collect-garbage --delete-older-than ''${days}d && /run/current-system/bin/switch-to-configuration boot"
          echo "::stage Очистка завершена"
          exit 0 ;;
        switch|boot|build) ;;
        *) echo "pixel-rebuild switch|boot|build|rollback|gc [--update]" >&2; exit 1 ;;
      esac

      cd "$flake"
      if [ "''${2:-}" = --update ]; then
        echo "::stage Обновляю flake.lock…"
        nix flake update --flake "$flake" --log-format internal-json
      fi

      # Флейк видит только файлы, известные git, — новый system.json
      # без этого был бы невидим для сборки.
      git add --intent-to-add system.json 2>/dev/null || true

      # internal-json: оболочка разбирает события Nix и рисует прогресс
      echo "::stage Собираю систему…"
      out=$(nix build --no-link --print-out-paths --log-format internal-json "$flake#nixosConfigurations.$host.config.system.build.toplevel")
      echo "Собрано: $out"

      if [ "$mode" = build ]; then
        echo "::stage Сборка прошла без ошибок"
        exit 0
      fi

      echo "::stage Жду подтверждения…"
      sudo_sh '/run/current-system/sw/bin/nix-env -p /nix/var/nix/profiles/system --set "$1" && "$1/bin/switch-to-configuration" "$2"' "$out" "$mode"
      echo "::stage Готово"
    '';
  };
in {
  home.packages = [
    quickshell
    pixel-shell
    pixel-screenshot
    pixel-record
    pixel-rebuild
  ];

  # QML по файлам (recursive), чтобы рядом можно было положить
  # сгенерированный common/Nix.qml.
  xdg.configFile."quickshell/pixel" = {
    source = ./qml;
    recursive = true;
  };
  xdg.configFile."quickshell/pixel/common/Nix.qml".text = nixQml;
  xdg.configFile."quickshell/pixel/shaders".source = shaders;

  systemd.user.services.pixel-shell = {
    Unit = {
      Description = "Pixel Shell (Quickshell)";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
      X-Restart-Triggers = ["${./qml}" "${matugenFull}" "${shaders}"];
    };
    Service = {
      ExecStart = "${lib.getExe quickshell} -c pixel";
      Restart = "on-failure";
      RestartSec = 1;
      # QS_ICON_THEME — тема значков из «Настройки → Обои и стиль»
      EnvironmentFile = "-${stateDir}/env";
      # Приложения запускаются в своих scope (systemd-run), так что
      # перезапуск оболочки их не трогает.
      Environment = [
        "QT_QPA_PLATFORM=wayland"
        "PATH=${lib.makeBinPath (with pkgs; [
          coreutils
          findutils
          gnugrep
          gnused
          gawk
          procps
          util-linux
          pciutils
          systemd
          glib
          libnotify
          wl-clipboard
          cliphist
          brightnessctl
          hyprsunset
          mpvpaper # видеообои Wallpaper Engine
          ffmpeg # кадры из видеообоев для превью и палитры
          ddcutil # яркость внешних мониторов
          xdg-utils
          flatpak
          matugen
          jq
          git
        ])}:/run/wrappers/bin:${config.home.homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${config.home.username}/bin:/var/lib/flatpak/exports/bin:/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = ["hyprland-session.target"];
  };

  # История буфера обмена для Super+V
  services.cliphist = {
    enable = true;
    allowImages = true;
    systemdTargets = ["hyprland-session.target"];
  };

  # «Настройки» в лаунчере и меню приложений
  xdg.desktopEntries.pixel-shell-settings = {
    name = "Настройки";
    genericName = "Настройки системы";
    comment = "Сеть, экран, звук, обои, приложения и параметры NixOS";
    icon = "preferences-system";
    exec = "pixel-shell settings toggle";
    categories = ["Settings" "System"];
    settings.StartupWMClass = "pixel-shell";
  };

  # Каталоги, куда оболочка пишет сама.
  home.activation.pixelShellDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "${stateDir}" "${configHome}/hypr/shell" "${config.home.homeDirectory}/Pictures/Wallpapers"
  '';
}
