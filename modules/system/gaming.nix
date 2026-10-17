# Игры, стриминг и утилиты железа.
{
  pkgs,
  lib,
  host,
  ...
}: {
  hardware.steam-hardware.enable = true; # Поддержка Steam Controller
  programs.gpu-screen-recorder.enable = true;

  # Steam, Gamescope, GameMode и Sunshine включаются в system.json
  # («Настройки → Система → Игры»); здесь — как именно они настроены.
  programs.steam = {
    gamescopeSession.enable = true;

    # Remote Play на Wayland. Без -pipewire Steam не умеет захватывать
    # рабочий стол и шлёт на клиент чёрные кадры — в статистике стрима это
    # «Desktop Black Frame». С флагом он берёт экран через портал
    # ScreenCast (xdg-desktop-portal-hyprland) по PipeWire.
    # -pipewire-dmabuf — захват без копирования через CPU, быстрее.
    package = pkgs.steam.override {
      extraArgs = "-pipewire -pipewire-dmabuf";

      # Быстрый захват (dmabuf) требует GBM. Без этого в streaming_log.txt:
      #   CDesktopCapturePipeWire: Couldn't create GBM device
      # и Steam откатывается на копирование кадров через память: ~45 FPS,
      # четверть кадров теряется, поток то и дело переподключается.
      # Вероятная причина: libgbm в окружении Steam нет, и он берёт
      # старый из своего steam-runtime, а тот ищет драйверы по путям
      # Ubuntu. Кладём в окружение Steam свежий libgbm из nixpkgs
      # (и 64-, и 32-битный) — runtime предпочитает системную
      # библиотеку, если она новее своей.
      extraLibraries = p: [p.libgbm];
      # Где libgbm искать бэкенды: 32-битный процесс пропустит 64-битный
      # каталог (не тот класс ELF) и найдёт свой, и наоборот.
      extraEnv.GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm:/run/opengl-driver-32/lib/gbm";
    };
    remotePlay.openFirewall = true;
  };

  services.sunshine = {
    autoStart = true;
    capSysAdmin = true; # Симуляция нажатий геймпада
    openFirewall = true; # Порты для Moonlight
  };

  # Управление кулерами/частотами AMD (LACT)
  systemd.packages = lib.optionals host.amdGpu [pkgs.lact];
  systemd.services.lactd = lib.mkIf host.amdGpu {wantedBy = ["multi-user.target"];};
}
