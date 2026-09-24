# Точка сборки системы. Сам по себе файл ничего не настраивает —
# только собирает модули. Всё содержательное лежит в modules/system/,
# железо конкретной машины — в hosts/<хост>/ (подключает flake.nix).
{...}: {
  imports = [
    ./modules/system/boot.nix
    ./modules/system/network.nix
    ./modules/system/services.nix
    ./modules/system/desktop.nix
    ./modules/system/google-sans.nix
    ./modules/system/fhs-compat.nix
    ./modules/system/gaming.nix
    ./modules/system/packages.nix
    ./modules/system/nix-ld.nix
    ./modules/system/appimage.nix
    ./modules/system/nemo.nix
    ./modules/system/users.nix
  ];
}
