# Общее определение враппера appimage-run.
# Импортируется и системным модулем (binfmt + systemPackages),
# и модулем Home Manager (.desktop и служба ярлыков).
#
# Использование: import ./appimage-wrapper.nix { inherit pkgs; }
{pkgs}: let
  appimageRunFixed = pkgs.appimage-run.override {
    extraPkgs = pkgs:
      with pkgs; [
        harfbuzz libepoxy freetype fontconfig icu openssl zlib
        mesa libGL libGLU vulkan-loader libdrm
        alsa-lib libpulseaudio nss nspr dbus
        cairo pango atk gdk-pixbuf gtk3 libadwaita cups

        # Аудио-бэкенды (ShadPS4, RPCS3 и т.п.)
        openal libjack2 sndio

        # Ввод и контроллеры
        SDL2 libevdev udev

        # Легаси-юникс/крипто-стек
        e2fsprogs libuuid libedit

        # Видео
        ffmpeg libpng

        # Математика и компрессия
        gmp nettle libtasn1 p11-kit bzip2 xz zstd brotli libffi

        # Qt6 для образов без своего Qt внутри.
        # Имена по-новому: xorg.xcbutil* переименованы в libxcb-*.
        qt6.qtbase qt6.qtwayland qt6.qtsvg
        libxcb-util libxcb-wm libxcb-image
        libxcb-keysyms libxcb-render-util libxcb-cursor
      ];
  };
in
  pkgs.writeShellScriptBin "appimage-run" ''
    export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:$XDG_DATA_DIRS"

    if [ -z "$1" ] || [ ! -f "$1" ]; then
      exec ${appimageRunFixed}/bin/appimage-run "$@"
    fi

    REAL_PATH="$(realpath "$1")"
    shift

    # Отфильтровываем нераскрытые field code'ы (%f %F %u %U ...)
    FILTERED_ARGS=()
    for arg in "$@"; do
      case "$arg" in
        %[fFuUdDnNickvm]) ;;
        *) FILTERED_ARGS+=("$arg") ;;
      esac
    done
    set -- "''${FILTERED_ARGS[@]}"

    HASH="$(${pkgs.coreutils}/bin/sha256sum "$REAL_PATH" | ${pkgs.coreutils}/bin/cut -d' ' -f1)"
    META="$HOME/.cache/appimage-meta/$HASH"
    EXTRACT_ROOT="$HOME/.cache/appimage-extracted"
    EXTRACT="$EXTRACT_ROOT/$HASH"
    FHS_CACHE="$HOME/.cache/appimage-run/$HASH"

    # ================================================================
    # РАСПАКОВКА ЧЕРЕЗ РОДНОЙ РАНТАЙМ, НО БЕЗ ПОВТОРНОГО BINFMT
    # ================================================================
    # Исходный файл исполнять нельзя: с включённым binfmt exec вернул бы
    # управление в этот же скрипт и зациклил его, а вызвать ld.so напрямую
    # не выйдет — AppImage держит сигнатуру "AI" в поле EI_ABIVERSION,
    # и загрузчик отвергает файл ("ELF file ABI version invalid").
    #
    # Поэтому делаем временную копию и зануляем три байта сигнатуры по
    # смещению 8. Ядро такой файл за AppImage больше не считает, ld.so
    # претензий не имеет, а рантайм внутри работает как ни в чём не бывало
    # и сам разбирается, squashfs там или DwarFS.
    # Имя копии без расширения .AppImage — иначе сработала бы вторая
    # регистрация binfmt, по расширению.
    extract_appimage() {
      [ -d "$EXTRACT" ] && return 0

      mkdir -p "$EXTRACT_ROOT"
      local tmpd
      tmpd="$(mktemp -d "$EXTRACT_ROOT/.tmp.XXXXXX")" || return 1

      ${pkgs.coreutils}/bin/cp --reflink=auto "$REAL_PATH" "$tmpd/img" || {
        rm -rf "$tmpd"; return 1;
      }
      printf '\0\0\0' | ${pkgs.coreutils}/bin/dd of="$tmpd/img" bs=1 seek=8 \
        conv=notrunc status=none
      chmod +x "$tmpd/img"

      ( cd "$tmpd" && ./img --appimage-extract >/dev/null 2>&1 ) || true

      if [ -e "$tmpd/squashfs-root/AppRun" ]; then
        mv "$tmpd/squashfs-root" "$EXTRACT"
        chmod -R u+w "$EXTRACT" 2>/dev/null || true
      fi
      rm -rf "$tmpd"
      [ -d "$EXTRACT" ]
    }

    # ================================================================
    # ЗАПУСК
    # ================================================================
    STATUS=0
    if [ -d "$EXTRACT" ]; then
      # Образ уже разложен — значит appimage-run его не осилил.
      # Идём сразу в AppDir, не тратя время на заведомо провальную попытку.
      ${appimageRunFixed}/bin/appimage-run -w "$EXTRACT" "$@"
      STATUS=$?
    else
      START=$SECONDS
      ${appimageRunFixed}/bin/appimage-run "$REAL_PATH" "$@"
      STATUS=$?
      ELAPSED=$(( SECONDS - START ))

      if [ $STATUS -ne 0 ] && [ $STATUS -ne 130 ] && [ $STATUS -ne 143 ] && [ $ELAPSED -lt 5 ]; then
        echo "appimage-run: контейнер не справился (код $STATUS), распаковываю вручную..." >&2

        # Пустой каталог от сорвавшейся распаковки заставляет
        # appimage-exec.sh считать образ уже установленным — убираем.
        [ -d "$FHS_CACHE" ] && [ ! -e "$FHS_CACHE/AppRun" ] && rm -rf "$FHS_CACHE"

        if extract_appimage; then
          ${appimageRunFixed}/bin/appimage-run -w "$EXTRACT" "$@"
          STATUS=$?
        else
          echo "appimage-run: не удалось вскрыть payload" >&2
        fi
      fi
    fi

    # ================================================================
    # МЕТАДАННЫЕ ДЛЯ ЯРЛЫКА
    # ================================================================
    if [ ! -f "$META/.harvested" ]; then
      SRC=""
      [ -e "$FHS_CACHE/AppRun" ] && SRC="$FHS_CACHE"
      [ -z "$SRC" ] && [ -d "$EXTRACT" ] && SRC="$EXTRACT"

      if [ -n "$SRC" ]; then
        mkdir -p "$META"
        DESKTOP_SRC="$(${pkgs.findutils}/bin/find "$SRC" -maxdepth 1 -name '*.desktop' | head -n 1)"
        [ -n "$DESKTOP_SRC" ] && cp "$DESKTOP_SRC" "$META/app.desktop" 2>/dev/null

        ICON_SRC="$(${pkgs.findutils}/bin/find "$SRC" \( -name '*.png' -o -name '*.svg' \) -printf '%s %p\n' 2>/dev/null | sort -rn | head -n 1 | cut -d' ' -f2-)"
        [ -n "$ICON_SRC" ] && cp "$ICON_SRC" "$META/icon.''${ICON_SRC##*.}" 2>/dev/null

        touch "$META/.harvested"
      fi
    fi

    if [ -d "$META" ]; then
      echo "$REAL_PATH" > "$META/.origin"
      ${pkgs.systemd}/bin/systemctl --user start --no-block sync-appimage-desktops.service 2>/dev/null || true
    fi

    exit $STATUS
  ''
