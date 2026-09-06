{
  description = "My Gaming NixOS with CachyOS Kernel via Chaotic-Nyx";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Подключаем Chaotic-Nyx
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Подключаем репозиторий nix-flatpak
    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # База "какой файл в каком пакете" для nix-locate.
    # Обновляется еженедельно, собирать самому ничего не надо.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    chaotic,
    home-manager,
    nix-flatpak,
    nix-index-database,
    ...
  }: {
    nixosConfigurations."nixos" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        chaotic.nixosModules.default
        ({pkgs, ...}: {
          boot.kernelPackages = pkgs.linuxPackages_cachyos;
        })
        ./configuration.nix
        ./modules/appimage-system.nix

        # Внедряем модуль nix-flatpak в систему
        nix-flatpak.nixosModules.nix-flatpak

        # Модуль nix-index-database (даёт команду nix-locate)
        nix-index-database.nixosModules.nix-index

        # Инициализируем Home Manager
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users."deadinside" = import ./home.nix;
        }
      ];
    };
  };
}
