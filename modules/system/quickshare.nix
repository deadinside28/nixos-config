# Quick Share с Android: своя служба pixel-quickshare (rqs_lib из
# open-quickshare, см. modules/shell/quickshare и docs/quickshare.md).
# Включается «Настройки → Система → Службы» (services.quickShare).
#
# Обнаружение — mDNS (свой ответчик в службе, Avahi не нужен) и BLE,
# передача — TCP на закреплённый порт. Без общей сети телефон может
# перевести передачу на Wi-Fi Direct / точку доступа (NetworkManager).
{
  config,
  lib,
  pkgs,
  ...
}: let
  enabled = config.pixel.system.services.quickShare;
  port = 47380;
  pkg = pkgs.callPackage ../shell/quickshare/package.nix {};
in
  lib.mkIf enabled {
    environment.systemPackages = [pkg];

    systemd.user.services.pixel-quickshare = {
      description = "Quick Share с Android";
      partOf = ["graphical-session.target"];
      after = ["graphical-session.target"];
      wantedBy = ["hyprland-session.target"];
      serviceConfig = {
        ExecStart = "${lib.getExe pkg} --port ${toString port}";
        # смена имени в «Настройках» — выход с кодом 75 и перезапуск
        Restart = "on-failure";
        RestartSec = 1;
        # mDNS и BLE иногда не останавливаются сразу
        TimeoutStopSec = 10;
      };
    };

    networking.firewall = {
      allowedTCPPorts = [port];
      allowedUDPPorts = [5353];
    };
  }
