# Игры, стриминг и утилиты железа.
{pkgs, ...}: {
  hardware.steam-hardware.enable = true; # Поддержка Steam Controller
  programs.gamemode.enable = true;
  programs.gpu-screen-recorder.enable = true;

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  # Gamescope (Chaotic-Nyx подтянет свежую версию с патчами)
  programs.gamescope.enable = true;

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # Симуляция нажатий геймпада
    openFirewall = true; # Порты для Moonlight
  };

  # Управление кулерами/частотами AMD (LACT)
  systemd.packages = with pkgs; [lact];
  systemd.services.lactd.wantedBy = ["multi-user.target"];
}
