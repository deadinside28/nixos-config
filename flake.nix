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
    inherit (nixpkgs) lib;

    # Первая точка правды — пользователь. Один на все машины; прокидывается в
    # модули через specialArgs, чтобы имя не было зашито по конфигу.
    username = "deadinside";

    # Где лежит этот flake на машине. Его правит и пересобирает оболочка
    # («Настройки → Система», обновления). Клонировал в другое место —
    # поменяй здесь.
    configDir = "/home/${username}/nixos-config";

    # Вторая точка правды — внешний вид. Один и тот же набор значений
    # уезжает и в системные модули, и в home-manager, и в оверрайды
    # Flatpak, чтобы шрифт с курсором совпадали везде, а не в трёх местах
    # по отдельности.
    appearance = {
      uiFont = "Google Sans";
      uiFontStyle = "Medium"; # начертание: Regular / Medium / Bold
      uiFontSize = 12;
      monoFont = "JetBrainsMono Nerd Font";
      monoFontSize = 12;
      monoFontStyle = "Medium"; # Regular / Medium / SemiBold / Bold
      termFontSize = 16; # у терминала свой кегль
      cursorTheme = "Adwaita";
      cursorSize = 24;
    };

    # Третья точка правды — системные настройки из GUI. Файл правит
    # оболочка («Настройки → Система»), руками его тоже можно править.
    # Ключи и значения по умолчанию — в modules/system/gui-settings.nix.
    sys = lib.importJSON ./system.json;

    # Машины. Каждая папка в hosts/ — отдельный хост, имя папки становится
    # именем хоста (networking.hostName) и именем конфигурации:
    #   sudo nixos-rebuild switch --flake .#<имя>
    # Внутри папки:
    #   default.nix — железо (hardware-configuration.nix, disks.nix);
    #   host.nix    — данные: мониторы, видеокарта, андервольт.
    # Новая машина = скопировать папку, заменить hardware-configuration.nix
    # и поправить host.nix.
    hostNames = builtins.attrNames (
      lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts)
    );

    mkHost = hostname: let
      host = import ./hosts/${hostname}/host.nix;
    in
      lib.nixosSystem {
        specialArgs = {inherit username configDir hostname host appearance sys;};
        modules = [
          chaotic.nixosModules.default
          ({pkgs, ...}: {
            boot.kernelPackages = pkgs.linuxPackages_cachyos;
          })

          ./hosts/${hostname}
          ./configuration.nix

          nix-flatpak.nixosModules.nix-flatpak
          nix-index-database.nixosModules.nix-index
          cpak.nixosModules.default

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = {inherit username configDir hostname host appearance sys;};
            home-manager.users.${username} = import ./home.nix;
          }
        ];
      };
  in {
    nixosConfigurations = lib.genAttrs hostNames mkHost;

    # nix flake check: файловые операции «Файлов» со сбоями и очистка
    # данных в разделе «Память» (modules/shell/*-test.sh)
    checks.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      test = name: deps:
        pkgs.runCommand "pixel-${name}-test" {nativeBuildInputs = deps;} ''
          bash ${./modules/shell}/${name}-test.sh ${./modules/shell}/${name}.sh
          touch $out
        '';
    in {
      fileops = test "fileops" (with pkgs; [bash coreutils findutils gnused gnugrep libarchive]);
      storage = test "storage" (with pkgs; [bash coreutils findutils gnused gnugrep gawk]);
      store = test "store" (with pkgs; [bash coreutils gnugrep gawk jq]);
    };
  };
}
