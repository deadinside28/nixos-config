# Системные настройки из GUI («Настройки → Система» в оболочке).
#
# Значения лежат в system.json в корне flake: его правит оболочка, но
# и руками — пожалуйста. Здесь они превращаются в опции NixOS. Подробная
# настройка самих служб (порты Sunshine, аргументы Steam и т.п.) осталась
# в профильных модулях — отсюда только «включено/выключено» и списки.
#
# Схема файла — опции pixel.system ниже: тип, допустимые значения и
# значение по умолчанию у каждого ключа. Ключа нет в файле — берётся
# значение по умолчанию, поэтому старый или неполный system.json сборку
# не ломает. А неизвестный ключ (опечатка) или неверный тип останавливают
# пересборку ещё до сборки, с именем ключа в сообщении:
#   The option `pixel.system.firewall.tcp."[definition 1-entry 1]"' …
{
  config,
  lib,
  pkgs,
  sys,
  ...
}: let
  inherit (lib) mkOption types;
  opt = type: default: description: mkOption {inherit type default description;};
  flag = opt types.bool;

  s = config.pixel.system;

  # Последняя версия схемы. Меняется, когда ключи переименовываются или
  # меняют смысл; оболочка тогда переписывает system.json по-новому.
  schemaVersion = 1;

  # "obs-studio", "python3Packages.rich" → пакет из pkgs
  package = name:
    lib.attrByPath (lib.splitString "." name)
    (throw "system.json: пакета «${name}» нет в nixpkgs")
    pkgs;
in {
  options.pixel.system = {
    schemaVersion = opt types.ints.positive schemaVersion "Версия схемы system.json.";
    timeZone = opt (types.strMatching "[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)*") "Europe/Moscow" "Часовой пояс из базы tz, например Europe/Moscow.";
    locale = opt (types.strMatching "[a-z]{2,3}(_[A-Z]{2})?\\.UTF-8(@[a-z]+)?") "ru_RU.UTF-8" "Язык и региональные форматы, например ru_RU.UTF-8.";
    extraPackages = opt (types.listOf (types.strMatching "[A-Za-z0-9_+-]+(\\.[A-Za-z0-9_+-]+)*")) [] "Дополнительные пакеты: имена атрибутов nixpkgs.";
    flatpaks = opt (types.listOf (types.strMatching "[A-Za-z0-9_.-]+(//[A-Za-z0-9_.-]+)?")) [] "Flatpak-приложения: app ID, при необходимости //ветка.";
    flatpakAutoUpdate = flag true "Еженедельное обновление Flatpak.";
    services = {
      bluetooth = flag true "Bluetooth.";
      printing = flag true "Печать (CUPS).";
      avahi = flag true "Avahi: обнаружение устройств в сети.";
      docker = flag true "Docker.";
      sunshine = flag true "Sunshine: стриминг рабочего стола.";
      scx = flag true "Планировщик sched-ext.";
      plymouth = flag true "Заставка загрузки Plymouth.";
      zram = flag false "Сжатый swap в памяти.";
    };
    gaming = {
      steam = flag true "Steam.";
      gamescope = flag true "Gamescope.";
      gamemode = flag true "GameMode.";
    };
    firewall = {
      tcp = opt (types.listOf types.port) [] "Открытые TCP-порты.";
      udp = opt (types.listOf types.port) [] "Открытые UDP-порты.";
    };
    nix = {
      autoGc = flag true "Еженедельная очистка старых поколений.";
      gcDays = opt (types.ints.between 1 3650) 14 "Сколько дней хранить поколения.";
      autoOptimise = flag true "Дедупликация /nix/store.";
    };
  };

  config = {
    pixel.system = sys;

    assertions = [
      {
        assertion = s.schemaVersion <= schemaVersion;
        message = "system.json: схема версии ${toString s.schemaVersion} новее этой конфигурации (${toString schemaVersion}) — обнови конфигурацию.";
      }
    ];

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
  };
}
