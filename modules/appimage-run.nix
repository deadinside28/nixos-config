{pkgs, ...}: {
  # ==============================================================
  # 1. ОБЕРТКА ДЛЯ ЗАПОМИНАНИЯ ПУТИ К APPIMAGE
  # ==============================================================
  home.packages = [
    (pkgs.writeShellScriptBin "appimage-run" ''
      if [ -z "$1" ] || [ ! -f "$1" ]; then
        exec ${pkgs.appimage-run}/bin/appimage-run "$@"
      fi

      REAL_PATH="$(realpath "$1")"
      shift

      # Сохраняем метку пути для службы генерации ярлыков
      HASH="$(${pkgs.coreutils}/bin/sha256sum "$REAL_PATH" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
      CACHE_DIR="$HOME/.cache/appimage-run/$HASH"
      mkdir -p "$CACHE_DIR"
      echo "$REAL_PATH" > "$CACHE_DIR/.origin"

      # 1. Пробуем запустить через контейнер appimage-run
      ${pkgs.appimage-run}/bin/appimage-run "$REAL_PATH" "$@"
      STATUS=$?

      # 2. Если контейнер упал (конфликт библиотек Python/Qt, код != 0) —
      # прозрачно перезапускаем AppImage напрямую через Nix-LD
      if [ $STATUS -ne 0 ]; then
        chmod +x "$REAL_PATH"
        exec "$REAL_PATH" "$@"
      fi
    '')
  ];

  # ==============================================================
  # 2. АССОЦИАЦИЯ В NAUTILUS (ЗАПУСК ДАБЛКЛИКОМ)
  # ==============================================================
  xdg.desktopEntries.appimage-run = {
    name = "AppImage Runner";
    comment = "Запуск AppImage пакетов в NixOS";
    exec = "appimage-run %F";
    terminal = false;
    icon = "application-x-executable";
    mimeType = [
      "application/vnd.appimage"
      "application/x-iso9660-appimage"
      "application/x-appimage"
    ];
    categories = ["Utility"];
  };

  # ==============================================================
  # 3. АВТОМАТИЧЕСКИЙ ИМПОРТ ЯРЛЫКОВ В ДЕСКТОП (DMS)
  # ==============================================================
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

          ${pkgs.findutils}/bin/find "$CACHE_DIR" -mindepth 2 -maxdepth 2 -name "*.desktop" | while read -r desktop_file; do
            app_dir="$(dirname "$desktop_file")"
            filename="$(basename "$desktop_file")"
            target="$APPS_DIR/$filename"

            # 1. Ищем оригинальный путь из метки .origin
            orig_appimage=""
            if [ -f "$app_dir/.origin" ]; then
              orig_appimage="$(cat "$app_dir/.origin")"
            fi

            # Если файла уже не существует на диске — пропускаем
            if [ -n "$orig_appimage" ] && [ ! -f "$orig_appimage" ]; then
              continue
            fi

            # 2. Ищем иконку внутри папки кэша
            icon_file="$(${pkgs.findutils}/bin/find "$app_dir" -maxdepth 2 \( -name "*.png" -o -name "*.svg" \) | head -n 1)"

            # 3. Копируем .desktop файл
            cp "$desktop_file" "$target"
            chmod +w "$target"

            # 4. Убираем TryExec
            ${pkgs.gnused}/bin/sed -i '/^TryExec=/d' "$target"

            # 5. Прописываем команду запуска
            if [ -n "$orig_appimage" ]; then
              ${pkgs.gnused}/bin/sed -i -E "s|^Exec=.*|Exec=appimage-run \"$orig_appimage\" %U|" "$target"
            fi

            # 6. Прописываем прямой путь к найденной иконке
            if [ -n "$icon_file" ]; then
              ${pkgs.gnused}/bin/sed -i -E "s|^Icon=.*|Icon=$icon_file|" "$target"
            fi

            chmod +x "$target"
          done
        fi
      '';
    };
  };

  systemd.user.paths.sync-appimage-desktops = {
    Unit = {
      Description = "Watch ~/.cache/appimage-run for new AppImages";
    };
    Path = {
      PathModified = "%h/.cache/appimage-run";
      Unit = "sync-appimage-desktops.service";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
