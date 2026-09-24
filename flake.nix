{
  description = "My Gaming NixOS with CachyOS Kernel via Chaotic-Nyx";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    cpak.url = "github:Containerpak/cpak/v2";

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
    cpak,
    ...
  }: let
    # Одна точка правды: имя пользователя и хост.
    # Прокидываются в модули через specialArgs, чтобы не хардкодить
    # "deadinside" по всему конфигу.
    username = "deadinside";
    hostname = "nixos";

    # Вторая точка правды — внешний вид. Один и тот же набор значений
    # уезжает и в системные модули, и в home-manager, и в оверрайды
    # Flatpak, чтобы шрифт с курсором совпадали везде, а не в трёх местах
    # по отдельности.
    appearance = {
      uiFont = "Inter";
      uiFontSize = 11;
      monoFont = "JetBrainsMono Nerd Font";
      monoFontSize = 11;
      termFontSize = 14; # у терминала свой кегль
      cursorTheme = "Adwaita";
      cursorSize = 24;
    };
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit username hostname appearance;};
      modules = [
        chaotic.nixosModules.default
        ({pkgs, ...}: {
          boot.kernelPackages = pkgs.linuxPackages_cachyos;
        })

        ./configuration.nix

        nix-flatpak.nixosModules.nix-flatpak
        nix-index-database.nixosModules.nix-index
        cpak.nixosModules.default

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.extraSpecialArgs = {inherit username appearance;};
          home-manager.users.${username} = import ./home.nix;
        }
      ];
    };
  };
}
