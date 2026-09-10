# Поддержка AppImage: ни враппера, ни раннера, ни кэша, ни binfmt.
# Образ запускается напрямую — загрузчик даёт nix-ld (см. ./nix-ld.nix),
# рантайм монтирует свой squashfs через FUSE в /tmp и сам размонтирует.
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
  # ~/Games/bloodborne/start.sh.
  #
  # Распаковывать при этом нечего: образ исполняется сам. Поэтому шим
  # только передаёт управление — никакого кэша, FHS-песочницы и прочего
  # наследия старой схемы за этим именем больше не стоит.
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

      exec "$img" "$@"
    '')
  ];
}
