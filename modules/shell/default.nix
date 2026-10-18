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
  configDir,
  ...
}: let
  flake = configDir;
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
        readonly property string fileops: "${lib.getExe pixel-fileops}"
        readonly property string storage: "${lib.getExe pixel-storage}"
        readonly property string store: "${lib.getExe pixel-store}"
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
    # «Файлы» без пути (из лаунчера или по биндy) — домашняя папка
    if [ "$1" = files ] && [ "''${2:-}" = open ] && [ -z "''${3:-}" ]; then
      set -- files open "$HOME"
    fi
    exec ${lib.getExe quickshell} -c pixel ipc call "$@"
  '';

  # Файловые операции «Файлов» и архиватора (вставка, перенос, распаковка,
  # сжатие). Отдельным скриптом, чтобы проверять сбои: fileops-test.sh.
  pixel-fileops = pkgs.writeShellApplication {
    name = "pixel-fileops";
    runtimeInputs = with pkgs; [coreutils findutils gnused gnugrep libarchive wl-clipboard];
    text = builtins.readFile ./fileops.sh;
  };

  # Раздел «Память»: размеры и очистка данных приложений. nix и flatpak —
  # системные (из PATH), чтобы версия совпадала с демоном и установкой.
  pixel-storage = pkgs.writeShellApplication {
    name = "pixel-storage";
    runtimeInputs = with pkgs; [coreutils findutils gawk gnugrep gnused procps];
    text = builtins.readFile ./storage.sh;
  };

  # Каталог «Магазина»: индекс пакетов Nix из ревизий flake.lock и поиск
  # Flatpak. nix и flatpak — системные (из PATH).
  pixel-store = pkgs.writeShellApplication {
    name = "pixel-store";
    runtimeInputs = with pkgs; [coreutils gawk gnugrep jq];
    text = builtins.readFile ./store.sh;
  };

  # Исходные метрики ресурсов: PSS/USS по группам процессов, память, VRAM, CPU
  pixel-metrics = pkgs.writeShellApplication {
    name = "pixel-metrics";
    runtimeInputs = with pkgs; [coreutils gawk jq];
    text = builtins.readFile ./metrics.sh;
  };

  # Ярлык «Календаря»: без файла — открыть, с .ics — импортировать
  pixel-calendar = pkgs.writeShellScriptBin "pixel-calendar" ''
    if [ $# -gt 0 ]; then exec pixel-shell calendar importFile "$1"; fi
    exec pixel-shell calendar open
  '';

  # Напоминания календаря — своей службой, независимо от оболочки
  pixel-reminders = pkgs.writeShellApplication {
    name = "pixel-reminders";
    runtimeInputs = with pkgs; [coreutils gnugrep jq libnotify];
    text = builtins.readFile ./reminders.sh;
  };

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

  # Запись экрана: повторный вызов останавливает.
  #   pixel-record [screen[:МОНИТОР]|area|window] [system|mic|none]
  # Без аргументов — что выбрано последним в оболочке (record.env).
  # Параметры (кадры, кодек, качество, папка) — из «Настройки → Экран».
  pixel-record = pkgs.writeShellApplication {
    name = "pixel-record";
    runtimeInputs = with pkgs; [procps psmisc ffmpeg libnotify coreutils slurp jq hyprland];
    excludeShellChecks = ["SC1091"];
    text = ''
      REC_FPS=60 REC_CODEC=av1 REC_QUALITY=very_high REC_CONTAINER=mp4 REC_CURSOR=yes REC_DIR="$HOME/Videos"
      REC_AREA=screen REC_AUDIO=system
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

      area=''${1:-$REC_AREA}
      audio=''${2:-$REC_AUDIO}
      case "$area" in
        screen|screen:*|area|window) ;;
        *) area="screen:$area" ;; # старый вызов: pixel-record <монитор> [mic]
      esac

      what="Весь экран"
      case "$area" in
        area)
          geom=$(slurp -b 00000099 -c ffffff -w 2 -f "%wx%h+%x+%y") || exit 0
          target=(-w region -region "$geom"); what="Область" ;;
        window)
          geom=$(hyprctl activewindow -j | jq -r '"\(.size[0])x\(.size[1])+\(.at[0])+\(.at[1])"')
          target=(-w region -region "$geom"); what="Окно" ;;
        *)
          mon=''${area#screen}; mon=''${mon#:}
          [ -n "$mon" ] || mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
          target=(-w "$mon") ;;
      esac

      args=()
      case "$audio" in
        mic) args=(-a "default_output|default_input"); label="со звуком и микрофоном" ;;
        none) label="без звука" ;;
        *) args=(-a default_output); label="со звуком" ;;
      esac

      mkdir -p "$REC_DIR"
      file="$REC_DIR/video_$(date +%F_%H-%M-%S).$REC_CONTAINER"
      echo "$file" > "$last"
      gpu-screen-recorder "''${target[@]}" -f "$REC_FPS" "''${args[@]}" -k "$REC_CODEC" -q "$REC_QUALITY" \
        -cursor "$REC_CURSOR" -c "$REC_CONTAINER" -o "$file" &
      notify-send -a "Запись экрана" -i camera-video "Запись начата" "$what, $label · ''${REC_CODEC^^}, $REC_FPS кадров/с"
    '';
  };

  # Распознавание текста: быстрые модели tesseract (tessdata_fast) — в разы
  # быстрее обычных при почти той же точности на тексте с экрана.
  tesseract = pkgs.tesseract.override {enableLanguages = [];};
  tessdata = pkgs.linkFarm "tessdata-fast" (
    [
      {
        name = "configs";
        path = "${tesseract}/share/tessdata/configs";
      }
    ]
    ++ lib.mapAttrsToList (lang: sha256: {
      name = "${lang}.traineddata";
      path = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/4.1.0/${lang}.traineddata";
        inherit sha256;
      };
    }) {
      eng = "1ckhf515c98ka8dcqfy80scz2hmm5j8w6gv8g5474jbp5ayj4hvx";
      rus = "09gj9pmys39bkqb3m2adw6wja9j7aj5wyqq0n319w7ffdh1mwvp1";
      ukr = "16xm7l5lzffc4aw3l02c0klcgjhg4h04njqjbx2g8cpdppi577nm";
      deu = "0bdjrpi305fbw3mr7jwn2ykvj7m82rl6qqx942fqcb37nsxiklhr";
      fra = "1jj56hgaqqvals8qg8hi17w9lfbx8zfjikny48qw304c5rb3gl6f";
      spa = "0r5llq7a967qscy3gi4xmjkknzydy88i2jylpq0qz8bl4z808bkg";
      ita = "09w8ims15m564wqgfbp47rfdnkm657045q0ssp2dl62ig0g9xy5q";
      pol = "1ckrxzhmciviqw30z4jzw6n8bgqwpsvj4l9l6a6qjgg3q3dnqiy4";
      jpn = "0k8vp61qv7id8ya573zj96a8svwjskr01idkykyzb19fdliyjp8z";
      chi_sim = "0c7pw50k2svbszl89rbjj5k88ngh93lb97gk4a2ns78yvgqbdz55";
      kor = "1cmkc08gv0d031jbdy1xf4zc8i1824dknlmkjwxqc1xzkcfy31bb";
    }
  );

  # «Обвести и найти» и перевод экрана, как на Pixel. Строки текста ищет
  # нейросеть PaddleOCR (RapidOCR, ONNX), каждую строку распознаёт tesseract,
  # переводит Google — см. lens/lens_ocr.py.
  lensPython = pkgs.python3.withPackages (ps: [ps.rapidocr-onnxruntime]);
  pixel-lens-ocr = pkgs.writeShellApplication {
    name = "pixel-lens-ocr";
    runtimeInputs = [tesseract];
    text = ''
      export PIXEL_LENS_TESSDATA=${tessdata}
      exec ${lensPython}/bin/python ${./lens/lens_ocr.py} "$@"
    '';
  };

  # Оболочка рисует интерфейс, а тяжёлое делает этот скрипт:
  #   pixel-lens shot <монитор> <файл>         — снимок экрана
  #   pixel-lens crop <файл> <ШxВ+X+Y> <файл>  — вырезать область
  #   pixel-lens ocr <файл> <языки>            — текст картинки
  #   pixel-lens translate <файл> <языки> <в>  — абзацы с координатами,
  #                                              цветами и переводом (TSV)
  #   pixel-lens text <в> <текст>              — перевести строку
  #   pixel-lens search <файл>                 — найти картинку в Google Lens
  pixel-lens = pkgs.writeShellApplication {
    name = "pixel-lens";
    runtimeInputs = with pkgs; [grim imagemagick curl wl-clipboard xdg-utils coreutils pixel-lens-ocr];
    text = ''
      cmd=''${1:?команда}; shift
      case "$cmd" in
        shot)
          grim -o "$1" "$2" ;;
        crop)
          magick "$1" -crop "$2" +repage "$3" ;;
        ocr)
          pixel-lens-ocr text "$1" "''${2:-eng+rus}" ;;
        translate)
          pixel-lens-ocr translate "$1" "''${2:-eng+rus}" "''${3:-ru}" ;;
        text)
          pixel-lens-ocr string "$1" "$2" ;;
        search)
          # Google Lens принимает картинку и отвечает адресом страницы с результатами
          url=$(curl -s -o /dev/null -w '%{redirect_url}' \
            -F "encoded_image=@$1;type=image/png" -F "image_url=" -F "sbisrc=Chromium" \
            "https://lens.google.com/v3/upload?hl=ru" || true)
          if [ -n "$url" ]; then
            xdg-open "$url"
          else
            # не вышло — картинка в буфер, Lens в браузере (там Ctrl+V)
            wl-copy --type image/png < "$1"
            xdg-open "https://lens.google.com/"
          fi ;;
        *) echo "pixel-lens shot|crop|ocr|text|translate|search" >&2; exit 1 ;;
      esac
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
    pixel-lens
    pixel-calendar
    pixel-metrics
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
          libarchive # bsdtar: архивы в «Файлах»
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

  # Напоминания календаря: читают ~/.local/state/pixel-calendar/reminders.json,
  # который пишет оболочка; работают и пока оболочка перезапускается.
  systemd.user.services.pixel-reminders = {
    Unit = {
      Description = "Pixel Shell: напоминания календаря";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      ExecStart = lib.getExe pixel-reminders;
      Restart = "always";
      RestartSec = 5;
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

  xdg.desktopEntries.pixel-shell-notes = {
    name = "Заметки";
    genericName = "Заметки";
    comment = "Заметки в Markdown: папки, поиск, закреплённые";
    icon = "accessories-text-editor";
    exec = "pixel-shell notes open";
    categories = ["Office" "Utility"];
    settings.StartupWMClass = "pixel-shell";
  };
  xdg.desktopEntries.pixel-shell-calendar = {
    name = "Календарь";
    genericName = "Календарь";
    comment = "События, повторы, напоминания, импорт и экспорт .ics";
    icon = "x-office-calendar";
    exec = "pixel-calendar %f";
    categories = ["Office" "Calendar"];
    mimeType = ["text/calendar"];
    settings.StartupWMClass = "pixel-shell";
  };

  xdg.desktopEntries.pixel-shell-store = {
    name = "Магазин";
    genericName = "Установка приложений";
    comment = "Приложения из Nixpkgs, Chaotic-Nyx и Flatpak";
    icon = "system-software-install";
    exec = "pixel-shell store open";
    categories = ["System" "PackageManager"];
    settings.StartupWMClass = "pixel-shell";
  };

  # «Файлы» — свой проводник оболочки; он же открывает папки по умолчанию
  # (inode/directory в modules/system/nemo.nix).
  xdg.desktopEntries.pixel-shell-files = {
    name = "Файлы";
    genericName = "Файловый менеджер";
    comment = "Папки, загрузки, диски и корзина";
    icon = "system-file-manager";
    exec = "pixel-shell files open %U";
    categories = ["System" "FileManager" "Utility"];
    mimeType = ["inode/directory"];
    settings.StartupWMClass = "pixel-shell";
  };

  # Архиватор оболочки: zip, 7z, rar, tar — отдельным окном
  xdg.desktopEntries.pixel-shell-archive = {
    name = "Архиватор";
    genericName = "Архивы";
    comment = "Открыть, распаковать и дополнить zip, 7z, rar, tar";
    icon = "package-x-generic";
    exec = "pixel-shell archive open %f";
    categories = ["Utility" "Archiving" "Compression"];
    mimeType = [
      "application/zip"
      "application/x-7z-compressed"
      "application/vnd.rar"
      "application/x-rar"
      "application/x-tar"
      "application/x-compressed-tar"
      "application/x-xz-compressed-tar"
      "application/x-zstd-compressed-tar"
      "application/x-bzip2-compressed-tar"
      "application/gzip"
    ];
    noDisplay = true;
    settings.StartupWMClass = "pixel-shell";
  };

  # Каталоги, куда оболочка пишет сама.
  home.activation.pixelShellDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "${stateDir}" "${configHome}/hypr/shell" "${config.home.homeDirectory}/Pictures/Wallpapers"
  '';
}
