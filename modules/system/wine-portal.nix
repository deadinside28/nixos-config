# Wine со стандартными диалогами Windows через системный диалог выбора
# файлов (портал FileChooser, а с ним — свой диалог оболочки). Включается
# «Настройки → Система → Игры» (gaming.wineHostDialogs в system.json).
#
# Это отдельная сборка Wine 11.0 с патчами из patches/wine (см. README там):
# она становится системным `wine`. Proton в Steam и раннеры Lutris/Heroic
# не подменяются — у них свой Wine. В Lutris её можно выбрать как
# «System» Wine. Сборка из исходников — после включения пересборка идёт
# заметно дольше обычного.
#
# Патч включается ключом реестра в префиксе. Обёртка `wine` ставит его
# один раз на префикс (метка .pixel-host-dialogs), дальше — обычный wine.
{
  config,
  lib,
  pkgs,
  ...
}: let
  enabled = config.pixel.system.gaming.wineHostDialogs;

  wine = pkgs.wineWow64Packages.stable.overrideAttrs (old: {
    pname = "wine-host-dialogs";
    patches =
      (old.patches or [])
      ++ [
        ../../patches/wine/0005-comdlg32-xdg-desktop-portal-file-chooser.patch
        ../../patches/wine/0006-shell32-browse-for-folder-host-chooser.patch
      ];
  });

  # Включить системные диалоги в префиксе (WINEPREFIX или ~/.wine)
  enable-host-dialogs = pkgs.writeShellApplication {
    name = "wine-host-dialogs";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      prefix="''${WINEPREFIX:-$HOME/.wine}"
      ${wine}/bin/wine reg add 'HKCU\Software\Wine\FileDialog' /v HostFileChooser /t REG_SZ /d Y /f >/dev/null
      touch "$prefix/.pixel-host-dialogs"
      echo "Системные диалоги включены в $prefix"
    '';
  };

  # `wine` с включением диалогов при первом запуске в префиксе
  wrapper = pkgs.writeShellScript "wine" ''
    prefix="''${WINEPREFIX:-$HOME/.wine}"
    if [ ! -e "$prefix/.pixel-host-dialogs" ] && [ "''${1:-}" != reg ]; then
      ${lib.getExe enable-host-dialogs} >/dev/null 2>&1 || true
    fi
    exec ${wine}/bin/wine "$@"
  '';
  wrapped = pkgs.symlinkJoin {
    name = "wine-host-dialogs-wrapped";
    paths = [wine];
    postBuild = ''
      rm $out/bin/wine
      ln -s ${wrapper} $out/bin/wine
    '';
  };
in {
  environment.systemPackages = lib.mkIf enabled [wrapped enable-host-dialogs];
}
