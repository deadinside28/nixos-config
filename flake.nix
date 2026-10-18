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
    self,
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
      reminders = test "reminders" (with pkgs; [bash coreutils gnugrep jq]);
      # Портал FileChooser на настоящей шине (dbus-run-session)
      portal = pkgs.runCommand "pixel-portal-test" {
        nativeBuildInputs = [pkgs.dbus (pkgs.python3.withPackages (ps: [ps.dbus-next]))];
      } ''
        # штатный конфиг session-шины, только сокет — в $TMPDIR
        sed "s|<listen>.*</listen>|<listen>unix:tmpdir=$TMPDIR</listen>|" \
          ${pkgs.dbus}/share/dbus-1/session.conf > bus.conf
        dbus-run-session --config-file=bus.conf -- python3 ${./modules/shell/portal/test_portal.py} ${./modules/shell/portal/pixel-portal.py}
        touch $out
      '';
      # Оболочка целиком: настоящий Quickshell под headless sway, все окна
      # и страницы настроек открываются через IPC, ошибки QML — провал
      shell-load = let
        hm = self.nixosConfigurations.${builtins.head hostNames}.config.home-manager.users.${username};
        nixQml = pkgs.writeText "Nix.qml" hm.xdg.configFile."quickshell/pixel/common/Nix.qml".text;
        cfg = pkgs.runCommand "pixel-shell-qml" {} ''
          cp -r ${./modules/shell/qml} $out
          chmod -R u+w $out
          cp ${nixQml} $out/common/Nix.qml
        '';
      in
        pkgs.runCommand "pixel-shell-load-test" {
          nativeBuildInputs = with pkgs; [bash coreutils gnugrep gnused];
        } ''
          bash ${./modules/shell/load-test.sh} ${pkgs.quickshell}/bin/quickshell ${pkgs.sway-unwrapped}/bin/sway ${cfg}
          touch $out
        '';
      # Свой диалог файлов из Qt-приложения целиком: тема xdgdesktopportal
      # с плагином «hyprland» → xdg-desktop-portal → pixel-portal → путь
      # возвращается в приложение (modules/shell/portal/qt-e2e.sh)
      portal-qt = let
        portalPkg = pkgs.callPackage ./modules/shell/portal/package.nix {inherit username;};
        theme = pkgs.callPackage ./modules/shell/qt-portal-theme/package.nix {};
        qtPlugins = pkgs.lib.makeSearchPath "lib/qt-6/plugins" (with pkgs.qt6; [qtbase qtwayland qtdeclarative]);
        dataDirs = pkgs.lib.concatStringsSep ":" [
          "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
          "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
        ];
      in
        pkgs.runCommand "pixel-portal-qt-test" {
          nativeBuildInputs = with pkgs; [bash coreutils gnugrep dbus python3];
        } ''
          sed "s|<listen>.*</listen>|<listen>unix:tmpdir=$TMPDIR</listen>|" \
            ${pkgs.dbus}/share/dbus-1/session.conf > bus.conf
          dbus-run-session --config-file=bus.conf -- bash ${./modules/shell/portal/qt-e2e.sh} \
            ${pkgs.sway-unwrapped}/bin/sway ${pkgs.xdg-desktop-portal}/libexec/xdg-desktop-portal \
            ${portalPkg} ${pkgs.qt6.qtdeclarative}/bin/qml ${qtPlugins} \
            ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml ${dataDirs} ${theme}/lib/qt-6/plugins
          touch $out
        '';
      # Служба Quick Share собирается (сквозной тест — e2e.py, нужен root)
      quickshare = pkgs.callPackage ./modules/shell/quickshare/package.nix {};
      calendar = pkgs.runCommand "pixel-calendar-test" {nativeBuildInputs = [pkgs.nodejs];} ''
        TZ=Europe/Berlin node ${./modules/shell/calendar-test.js} ${./modules/shell/qml/services/calendar.js}
        touch $out
      '';
    };
  };
}
