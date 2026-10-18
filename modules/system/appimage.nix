# Поддержка AppImage — как на любом обычном дистрибутиве: образ
# исполняется сам, без распаковки, кэша и FHS-песочницы. Загрузчик даёт
# nix-ld (см. ./nix-ld.nix — там же библиотеки, которые образы ожидают от
# системы), рантайм монтирует свой squashfs через FUSE и сам размонтирует.
{pkgs, ...}: {
  # programs.fuse.enable по умолчанию false, а setuid-обёртки
  # fusermount/fusermount3 сидят под mkIf cfg.enable. Без этой строки
  # рантайм AppImage не может смонтировать сам себя.
  programs.fuse.enable = true;

  # Виртуальные /usr/bin и /bin из PATH — для софта с хардкодом путей.
  services.envfs.enable = true;

  # Шим совместимости.
  #
  # Gear Lever читает /etc/os-release, видит NAME=NixOS и после этого
  # жёстко вызывает `appimage-run` — иначе кнопка «Запустить» в его
  # интерфейсе не работает. Того же имени ждут старые скрипты вроде
  # ~/Games/bloodborne/start.sh, его же зовут «Файлы» и ярлыки.
  #
  # Распаковывать при этом нечего: шим только выставляет окружение и
  # передаёт управление самому образу. Штатный pkgs.appimage-run
  # (распаковка в ~/.cache и FHS-окружение) за этим именем не стоит.
  #
  # Заодно шим — единственная точка, через которую проходят все ярлыки
  # AppImage, поэтому здесь же выставляется поведение диалогов выбора
  # файлов. Запуск образа руками из терминала шим обходит.
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "appimage-run" ''
      if [ $# -eq 0 ]; then
        echo "usage: appimage-run <образ.AppImage> [аргументы]" >&2
        exit 1
      fi

      img="$1"
      shift

      if [ ! -f "$img" ]; then
        echo "appimage-run: файл не найден: $img" >&2
        exit 1
      fi

      [ -x "$img" ] || chmod +x "$img" 2>/dev/null || true

      # Переменные nix-ld ставит сессия, но службы systemd --user и
      # программы, запущенные не из неё, их могут не получить. Без них
      # загрузчик образа не найдёт библиотек.
      export NIX_LD="''${NIX_LD:-/run/current-system/sw/share/nix-ld/lib/ld.so}"
      export NIX_LD_LIBRARY_PATH="''${NIX_LD_LIBRARY_PATH:-/run/current-system/sw/share/nix-ld/lib}"
      # Рантайму нужен setuid-fusermount, чтобы смонтировать образ
      export PATH="$PATH:/run/wrappers/bin"

      # Образ принёс свои Qt/GTK. Им выбор файла — только через портал:
      # тогда показывается тот же хостовый диалог, что и везде. Вариант
      # «рисуй GTK у себя» (qgtk3) хуже: он тянет в чужой процесс хостовые
      # GTK и glib через nix-ld, а они могут конфликтовать с библиотеками,
      # которые лежат внутри образа.
      export QT_QPA_PLATFORMTHEME=xdgdesktopportal
      export GTK_USE_PORTAL=1
      export GDK_DEBUG=portals

      exec "$img" "$@"
    '')
  ];
}
