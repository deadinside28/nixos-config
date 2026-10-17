# Системные настройки из GUI («Настройки → Система» в оболочке).
#
# Значения лежат в system.json в корне flake: его правит оболочка, но
# и руками — пожалуйста. Здесь они превращаются в опции NixOS. Подробная
# настройка самих служб (порты Sunshine, аргументы Steam и т.п.) осталась
# в профильных модулях — отсюда только «включено/выключено» и списки.
#
# Ключа нет в файле — берётся значение из defaults ниже, поэтому старый
# или неполный system.json сборку не ломает.
{
  lib,
  pkgs,
  sys,
  ...
}: let
  defaults = {
    timeZone = "Europe/Moscow";
    locale = "ru_RU.UTF-8";
    extraPackages = [];
    flatpaks = [];
    flatpakAutoUpdate = true;
    services = {
      bluetooth = true;
      printing = true;
      avahi = true;
      docker = true;
      sunshine = true;
      scx = true;
      plymouth = true;
      zram = false;
    };
    gaming = {
      steam = true;
      gamescope = true;
      gamemode = true;
    };
    firewall = {
      tcp = [];
      udp = [];
    };
    nix = {
      autoGc = true;
      gcDays = 14;
      autoOptimise = true;
    };
  };

  s = lib.recursiveUpdate defaults sys;

  # "obs-studio", "python3Packages.rich" → пакет из pkgs
  package = name:
    lib.attrByPath (lib.splitString "." name)
    (throw "system.json: пакета «${name}» нет в nixpkgs")
    pkgs;
in {
  time.timeZone = s.timeZone;
  i18n.defaultLocale = s.locale;
  i18n.extraLocaleSettings = lib.genAttrs [
    "LC_ADDRESS"
    "LC_IDENTIFICATION"
    "LC_MEASUREMENT"
    "LC_MONETARY"
    "LC_NAME"
    "LC_NUMERIC"
    "LC_PAPER"
    "LC_TELEPHONE"
    "LC_TIME"
  ] (_: s.locale);

  environment.systemPackages = map package s.extraPackages;

  services.flatpak.packages = s.flatpaks;
  services.flatpak.update.auto.enable = s.flatpakAutoUpdate;

  hardware.bluetooth = {
    enable = s.services.bluetooth;
    powerOnBoot = true;
  };
  services.printing.enable = s.services.printing;
  services.avahi.enable = s.services.avahi;
  virtualisation.docker.enable = s.services.docker;
  services.sunshine.enable = s.services.sunshine;
  services.scx.enable = s.services.scx;
  boot.plymouth.enable = s.services.plymouth;
  zramSwap.enable = s.services.zram;

  programs.steam.enable = s.gaming.steam;
  programs.gamescope.enable = s.gaming.gamescope;
  programs.gamemode.enable = s.gaming.gamemode;

  networking.firewall.allowedTCPPorts = s.firewall.tcp;
  networking.firewall.allowedUDPPorts = s.firewall.udp;

  nix.gc = {
    automatic = s.nix.autoGc;
    dates = "weekly";
    options = "--delete-older-than ${toString s.nix.gcDays}d";
  };
  nix.optimise.automatic = s.nix.autoOptimise;

  # Применённая версия — оболочка сравнивает её с system.json и
  # показывает «Есть неприменённые изменения».
  environment.etc."pixel-shell/system.json".text = builtins.toJSON sys;
}
