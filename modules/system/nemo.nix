# Файловый менеджер Nemo (вместо Nautilus) + пункты контекстного меню
# «Добавить в меню приложений» / «Убрать из меню» для AppImage.
#
# Почему Nemo: две панели (F3), вкладки, больше настроек, свои действия
# в меню, быстрый просмотр по пробелу (nemo-preview). Он на GTK3, поэтому
# adw-gtk3 и DMS красят его так же, как остальные приложения.
#
# Ярлык AppImage генерируется САМ, без Gear Lever. Что важно:
#   • образ остаётся там, где лежит — никаких копий и переносов;
#   • Exec идёт через шим appimage-run (см. modules/system/appimage.nix).
#     Образ исполняется сам и шим его не распаковывает — он только
#     выставляет переменные, чтобы диалоги выбора файлов шли через
#     портал, как у всех остальных приложений;
#   • имя, описание, категории и StartupWMClass берутся из .desktop
#     внутри образа, иконка — оттуда же;
#   • ничего не распаковывается: образ монтируется своим рантаймом
#     через FUSE, из него копируются два файла, и он размонтируется.
#
# Как Nemo находит расширение: nemo-with-extensions собирает nemo вместе
# со списком расширений и оборачивает его бинарники и D-Bus-сервисы
# переменными NEMO_EXTENSION_DIR / NEMO_PYTHON_EXTENSION_DIR. Поэтому, в
# отличие от Nautilus, никаких переменных окружения руками не нужно:
# достаточно положить пакет с share/nemo-python/extensions/*.py в extensions.
{pkgs, ...}: let
  binPath = pkgs.lib.makeBinPath (with pkgs; [
    coreutils
    findutils
    gnused
    gawk
    desktop-file-utils
    libnotify
  ]);

  # Общая часть обоих скриптов: пути и вычисление имени ярлыка по образу.
  common = ''
    export PATH="${binPath}''${PATH:+:$PATH}"

    DATA_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}"
    APPS="$DATA_HOME/applications"
    ICONS="$DATA_HOME/appimage/icons"

    # Имя ярлыка выводится из имени файла, а не из хеша: повторный запуск
    # на том же образе обновляет запись, а не плодит вторую.
    slug_of() {
      local b
      b="$(basename -- "$1")"
      b="''${b%.[Aa]pp[Ii]mage}"
      printf '%s' "$b" | tr -c 'A-Za-z0-9._-' '_'
    }
  '';

  integrate = pkgs.writeShellScript "appimage-menu-add" ''
    set -u
    ${common}

    mkdir -p "$APPS" "$ICONS"

    MOUNT_PID=""
    MOUNT_POINT=""

    # Монтируем образ его собственным рантаймом. Он печатает точку
    # монтирования в stdout и продолжает жить, пока его не убьют.
    #
    # Результат кладём в MOUNT_POINT, а не печатаем: вызов через $(...)
    # уходил бы в подоболочку, и присвоенный там MOUNT_PID до родителя
    # не доезжал бы — процесс монтирования оставался бы висеть навсегда.
    mount_appimage() {
      local img="$1" out mnt i
      out="$(mktemp)"
      MOUNT_POINT=""

      "$img" --appimage-mount >"$out" 2>/dev/null &
      MOUNT_PID=$!

      for i in $(seq 1 100); do
        mnt="$(head -n1 "$out" 2>/dev/null || true)"
        if [ -n "$mnt" ] && [ -d "$mnt" ]; then
          rm -f "$out"
          MOUNT_POINT="$mnt"
          return 0
        fi
        kill -0 "$MOUNT_PID" 2>/dev/null || break
        sleep 0.05
      done

      rm -f "$out"
      [ -n "$MOUNT_PID" ] && kill "$MOUNT_PID" 2>/dev/null
      MOUNT_PID=""
      return 1
    }

    unmount_appimage() {
      if [ -n "$MOUNT_PID" ]; then
        kill "$MOUNT_PID" 2>/dev/null || true
        wait "$MOUNT_PID" 2>/dev/null || true
        MOUNT_PID=""
      fi

      # Подстраховка: рантайм по SIGTERM размонтирует себя сам, но если
      # он этого не сделал — точка осталась бы висеть вместе с процессом
      # squashfuse. Ошибку глушим: чаще всего размонтировано уже всё.
      if [ -n "$MOUNT_POINT" ]; then
        fusermount -u "$MOUNT_POINT" 2>/dev/null || true
        MOUNT_POINT=""
      fi
    }

    # Если скрипт прервут посреди работы, монтирование не должно пережить его
    trap unmount_appimage EXIT INT TERM

    # Иконку берём из темы внутри образа — там она крупнее и чище,
    # чем .DirIcon, который бывает 48x48.
    pick_icon() {
      local mnt="$1" slug="$2" src="" size ext
      for size in 512x512 256x256 128x128 scalable 64x64 48x48; do
        src="$(find "$mnt/usr/share/icons/hicolor/$size/apps" -maxdepth 1 -type f \
                 \( -name '*.png' -o -name '*.svg' \) 2>/dev/null | head -n1)"
        [ -n "$src" ] && break
      done

      if [ -z "$src" ] && [ -e "$mnt/.DirIcon" ]; then
        src="$(readlink -f -- "$mnt/.DirIcon" 2>/dev/null || true)"
      fi

      if [ -z "$src" ]; then
        src="$(find "$mnt" -maxdepth 1 -type f \( -name '*.png' -o -name '*.svg' \) \
                 -printf '%s %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)"
      fi

      [ -n "$src" ] && [ -f "$src" ] || return 1

      case "$(od -An -tx1 -N4 -- "$src" | tr -d ' \n')" in
        89504e47) ext=png ;;
        *)        ext=svg ;;
      esac

      rm -f "$ICONS/$slug".png "$ICONS/$slug".svg
      cp -f -- "$src" "$ICONS/$slug.$ext" || return 1
      chmod 0644 "$ICONS/$slug.$ext" 2>/dev/null || true
      printf '%s' "$ICONS/$slug.$ext"
    }

    # Берём .desktop из образа и меняем в нём ровно три вещи: Exec, Icon
    # и метку происхождения. Всё остальное — Name на всех языках, Comment,
    # Categories, Keywords, StartupWMClass — переносится как есть.
    #
    # Группы [Desktop Action ...] отбрасываем: у них свои Exec, которые
    # после подмены пути превратились бы в дубли главного.
    build_desktop() {
      local mnt="$1" img="$2" icon="$3" out="$4" src name

      src="$(find "$mnt" -maxdepth 1 -type f -name '*.desktop' 2>/dev/null | head -n1)"

      if [ -n "$src" ]; then
        awk \
          -v exec_line="Exec=appimage-run \"$img\" %U" \
          -v icon_line="''${icon:+Icon=$icon}" \
          -v origin_line="X-AppImage-Origin=$img" '
          /^\[/ {
            ingroup = ($0 == "[Desktop Entry]")
            if (ingroup) print
            next
          }
          !ingroup { next }
          /^[[:space:]]*(Exec|TryExec|Icon|Actions|DBusActivatable|X-AppImage-Origin)[[:space:]]*=/ { next }
          { print }
          END {
            print exec_line
            if (icon_line != "") print icon_line
            print origin_line
          }
        ' "$src" > "$out"
        return 0
      fi

      # Внутри образа .desktop не нашлось — собираем минимальный сами
      name="$(basename -- "$img")"
      name="''${name%.[Aa]pp[Ii]mage}"
      {
        echo "[Desktop Entry]"
        echo "Type=Application"
        echo "Name=$name"
        echo "Comment=AppImage в $(dirname -- "$img")"
        echo "Categories=Utility;"
        echo "Terminal=false"
        echo "Exec=appimage-run \"$img\" %U"
        [ -n "$icon" ] && echo "Icon=$icon"
        echo "X-AppImage-Origin=$img"
      } > "$out"
    }

    ok=0
    fail=0
    noicon=0

    for img in "$@"; do
      [ -f "$img" ] || continue
      chmod +x "$img" 2>/dev/null || true

      slug="$(slug_of "$img")"
      tmp="$(mktemp)"
      icon=""

      if mount_appimage "$img"; then
        icon="$(pick_icon "$MOUNT_POINT" "$slug" || true)"
        build_desktop "$MOUNT_POINT" "$img" "$icon" "$tmp"
        unmount_appimage
        [ -n "$icon" ] || noicon=$((noicon + 1))
      else
        # Смонтировать не вышло — ярлык всё равно делаем, просто без
        # иконки и описания из образа.
        build_desktop "" "$img" "" "$tmp"
        noicon=$((noicon + 1))
      fi

      if install -Dm644 "$tmp" "$APPS/appimage-$slug.desktop" 2>/dev/null; then
        ok=$((ok + 1))
      else
        fail=$((fail + 1))
      fi
      rm -f "$tmp"
    done

    update-desktop-database "$APPS" 2>/dev/null || true

    if [ "$fail" -gt 0 ]; then
      notify-send -u critical -i dialog-error \
        "AppImage" "Добавлено: $ok, не вышло: $fail"
    elif [ "$noicon" -gt 0 ]; then
      notify-send -i application-x-executable \
        "AppImage" "Добавлено в меню: $ok (без иконки: $noicon)"
    else
      notify-send -i application-x-executable \
        "AppImage" "Добавлено в меню: $ok"
    fi
  '';

  remove = pkgs.writeShellScript "appimage-menu-remove" ''
    set -u
    ${common}

    n=0
    for img in "$@"; do
      slug="$(slug_of "$img")"
      rm -f "$APPS/appimage-$slug.desktop" \
            "$ICONS/$slug".png "$ICONS/$slug".svg && n=$((n + 1))
    done

    update-desktop-database "$APPS" 2>/dev/null || true

    # Сам образ не трогаем — убирается только запись в меню.
    notify-send -i user-trash "AppImage" "Убрано из меню: $n"
  '';

  extension = pkgs.writeTextFile {
    name = "nemo-appimage-extension";
    destination = "/share/nemo-python/extensions/appimage-menu.py";
    text = ''
      # Пункты контекстного меню Nemo для AppImage.
      # Сгенерировано из modules/system/nemo.nix

      import os
      import subprocess

      import gi

      # nemo-python загружает namespace Nemo до импорта расширений; если
      # версия уже выбрана хостом, повторный запрос бросает ValueError.
      try:
          gi.require_version("Nemo", "3.0")
      except ValueError:
          pass

      from gi.repository import GObject, Nemo

      ADD = "${integrate}"
      REMOVE = "${remove}"

      APPIMAGE_MIMES = frozenset((
          "application/vnd.appimage",
          "application/x-iso9660-appimage",
          "application/x-appimage",
      ))


      def _has_ai_signature(path):
          # Часть образов раздаётся без расширения, а определения MIME-типа
          # для AppImage в системе может не быть. Тогда смотрим сами:
          # ELF-заголовок плюс маркер AI в байтах 8-9.
          try:
              if not os.access(path, os.X_OK):
                  return False
              with open(path, "rb") as handle:
                  head = handle.read(11)
          except OSError:
              return False

          return head[:4] == b"\x7fELF" and head[8:10] == b"AI"


      def _appimage_paths(files):
          paths = []

          for item in files:
              try:
                  if item.get_uri_scheme() != "file" or item.is_directory():
                      continue

                  location = item.get_location()
                  if location is None:
                      continue

                  path = location.get_path()
                  if not path:
                      continue

                  matched = (
                      item.get_name().lower().endswith(".appimage")
                      or item.get_mime_type() in APPIMAGE_MIMES
                      or _has_ai_signature(path)
                  )
                  if matched:
                      paths.append(path)
              except Exception:
                  continue

          return paths


      class AppImageMenuProvider(GObject.GObject, Nemo.MenuProvider):
          # В Nemo сигнатура get_file_items(window, files). *args с последним
          # аргументом — на случай, если в будущей версии window уберут,
          # как это сделали в Nautilus 4.
          def get_file_items(self, *args):
              files = args[-1] if args else []
              paths = _appimage_paths(files)

              if not paths:
                  return []

              add = Nemo.MenuItem(
                  name="AppImage::add",
                  label="Добавить в меню приложений",
                  tip="Создать ярлык с иконкой и описанием из образа",
              )
              add.connect("activate", self._run, ADD, paths)

              rm = Nemo.MenuItem(
                  name="AppImage::remove",
                  label="Убрать из меню приложений",
                  tip="Удалить ярлык и иконку. Сам образ останется на месте",
              )
              rm.connect("activate", self._run, REMOVE, paths)

              return [add, rm]

          def _run(self, menu_item, script, paths):
              subprocess.Popen([script] + paths)
    '';
  };

  # Nemo со стандартным набором расширений Linux Mint (nemo-python,
  # сжатие/распаковка через File Roller, эмблемы, цвет папок) плюс наше
  # расширение и быстрый просмотр по пробелу.
  nemo = pkgs.nemo-with-extensions.override {
    extensions = [
      extension
      pkgs.nemo-preview
    ];
  };
in {
  environment.systemPackages = [nemo];

  # Файловый менеджер по умолчанию на уровне системы. Это именно умолчание:
  # если выбрать другое в DMS → Приложения по умолчанию, пользовательский
  # mimeapps.list его перекроет.
  xdg.mime.defaultApplications = {
    "inode/directory" = "nemo.desktop";
    "application/x-gnome-saved-search" = "nemo.desktop";
  };

  # Системные умолчания dconf (пользователь может их менять — это не
  # жёсткая запись, а значения по умолчанию).
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        # «Открыть в терминале» — kitty, а не gnome-terminal
        "org/cinnamon/desktop/default-applications/terminal" = {
          exec = "kitty";
          exec-arg = "";
        };
        # Nemo не должен рисовать свой рабочий стол поверх обоев DMS
        "org/nemo/desktop" = {
          show-desktop-icons = false;
        };
      };
    }
  ];
}
