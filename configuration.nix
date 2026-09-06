# Точка сборки системы. Сам по себе файл ничего не настраивает —
# только собирает модули. Всё содержательное лежит в modules/system/.
{...}: {
  imports = [
    ./hardware-configuration.nix
    ./disks.nix

    ./modules/system/boot.nix
    ./modules/system/network.nix
    ./modules/system/services.nix
    ./modules/system/desktop.nix
    ./modules/system/gaming.nix
    ./modules/system/packages.nix
    ./modules/system/nix-ld.nix
    ./modules/system/users.nix

    ./modules/appimage-system.nix
  ];
}
