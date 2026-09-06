{
  description = "My Gaming NixOS with CachyOS Kernel via Chaotic-Nyx";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # База "какой файл в каком пакете" для nix-locate
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    chaotic,
    home-manager,
    nix-flatpak,
    nix-index-database,
    ...
  }: let
    # Одна точка правды: имя пользователя и хост.
    # Прокидываются в модули через specialArgs, чтобы не хардкодить
    # "deadinside" по всему конфигу.
    username = "deadinside";
    hostname = "nixos";
    system = "x86_64-linux";
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit username hostname;};
      modules = [
        chaotic.nixosModules.default
        ({pkgs, ...}: {
          boot.kernelPackages = pkgs.linuxPackages_cachyos;
        })

        ./configuration.nix

        nix-flatpak.nixosModules.nix-flatpak
        nix-index-database.nixosModules.nix-index

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = {inherit username;};
          home-manager.users.${username} = import ./home.nix;
        }
      ];
    };
  };
}
