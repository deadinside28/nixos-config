# Отдаёт шрифты, иконки и темы по обычным FHS-путям /usr/share/*.
#
# Кому это нужно: всему, что собрано не нами и про /nix/store не знает —
# AppImage, OnlyOffice, FreeRDP внутри winboat, Steam и часть игр. Такие
# программы ищут шрифты ровно в /usr/share/fonts, не находят и рисуют
# собственным встроенным.
#
# Flatpak-у отдельно не нужно: в nixpkgs flatpak пропатчен и сам
# пробрасывает nix-овые каталоги шрифтов и иконок в песочницу, а
# fonts.fontDir.enable по умолчанию включается вместе с services.flatpak.
# Здесь он выставлен явно, потому что от него зависят монтирования ниже.
{pkgs, ...}: let
  # resolve-symlinks обязателен: в /run/current-system/sw/share лежат
  # симлинки в стор, а OnlyOffice и компания по ним не ходят.
  # nofail — страховка: если каталог-источник вдруг окажется пустым,
  # система не свалится в emergency при загрузке.
  mountOptions = [
    "ro"
    "nofail"
    "x-gvfs-hide"
    "resolve-symlinks"
  ];
in {
  fonts.fontDir.enable = true;

  system.fsPackages = [pkgs.bindfs];

  fileSystems = {
    "/usr/share/fonts" = {
      device = "/run/current-system/sw/share/X11/fonts";
      fsType = "fuse.bindfs";
      options = mountOptions;
    };

    "/usr/share/icons" = {
      device = "/run/current-system/sw/share/icons";
      fsType = "fuse.bindfs";
      options = mountOptions;
    };

    "/usr/share/themes" = {
      device = "/run/current-system/sw/share/themes";
      fsType = "fuse.bindfs";
      options = mountOptions;
    };
  };
}
