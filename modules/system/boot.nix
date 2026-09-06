# Загрузка, ядро, параметры железа AMD.
{
  config,
  pkgs,
  ...
}: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Ранняя загрузка драйвера видеокарты (чтобы не было серого экрана)
  boot.initrd.kernelModules = ["amdgpu"];

  # Отключаем текстовые логи при загрузке
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;

  # Экран загрузки с логотипом материнки (как в Fedora)
  boot.plymouth = {
    enable = true;
    theme = "bgrt";
  };

  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
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
  services.scx.enable = true;
  # services.scx.scheduler = "scx_rusty"; # если захочешь сменить вручную

  # Чтение потребляемой мощности и управление Curve Optimizer
  boot.extraModulePackages = with config.boot.kernelPackages; [ryzen-smu];
  boot.kernelModules = ["ryzen_smu" "k10temp"];
  boot.blacklistedKernelModules = [];

  # Андервольт CPU. Скрипт лежит в scripts/ и подтягивается декларативно.
  systemd.services.ryzen-undervolt = {
    description = "AMD Ryzen 7 5700X3D Undervolt";
    wantedBy = ["multi-user.target" "post-resume.target"];
    after = ["suspend.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python ${../../scripts/ruv.py} -c 8 -o -25";
      RemainAfterExit = true;
    };
  };
}
