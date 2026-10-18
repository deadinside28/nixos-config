# Загрузка, ядро, параметры железа AMD.
{
  config,
  lib,
  pkgs,
  host,
  ...
}: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ранняя загрузка драйвера видеокарты (чтобы не было серого экрана)
  boot.initrd.kernelModules = lib.optionals host.amdGpu ["amdgpu"];

  # Отключаем текстовые логи при загрузке
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # Экран загрузки с логотипом материнки (как в Fedora).
  # Включается в system.json («Настройки → Система»).
  boot.plymouth.theme = "bgrt";

  boot.kernelParams =
    lib.optionals host.amdGpu ["amdgpu.ppfeaturemask=0xffffffff"]
    ++ [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "usbcore.autosuspend=-1"
    ];

  # Планировщик sched-ext (по умолчанию scx_rustland)
  # (включается в system.json)
  # services.scx.scheduler = "scx_rusty"; # если захочешь сменить вручную

  # Чтение потребляемой мощности и управление Curve Optimizer
  boot.extraModulePackages = lib.optionals (host.undervolt != null) [config.boot.kernelPackages.ryzen-smu];
  boot.kernelModules = ["k10temp"] ++ lib.optionals (host.undervolt != null) ["ryzen_smu"];
  boot.blacklistedKernelModules = [];

  # Андервольт CPU. Скрипт лежит в scripts/ и подтягивается декларативно.
  # Curve Optimizer сбрасывается и при загрузке, и после сна — запускаемся
  # в обоих случаях. Без RemainAfterExit: иначе после загрузки юнит
  # оставался бы «active», и запуск после пробуждения ничего не делал бы.
  # Список сна — как у штатного post-resume.service в NixOS.
  systemd.services.ryzen-undervolt = let
    sleepTargets = ["suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target"];
  in
    lib.mkIf (host.undervolt != null) {
      description = "AMD Ryzen 7 5700X3D Undervolt";
      wantedBy = ["multi-user.target"] ++ sleepTargets;
      after = sleepTargets;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python ${../../scripts/ruv.py} -c ${toString host.undervolt.cores} -o ${toString host.undervolt.offset}";
      };
    };
}
