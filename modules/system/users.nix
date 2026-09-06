# Пользователь, оболочка и общесистемные мелочи systemd.
{
  pkgs,
  username,
  ...
}: {
  programs.fish.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = ["networkmanager" "wheel" "docker"];
    shell = pkgs.fish;
    packages = [];
  };

  # ВНИМАНИЕ: пять секунд получает КАЖДЫЙ юнит, включая те, которым
  # нужна долгая финализация. Если что-то начнёт терять данные при
  # выключении — выноси таймаут в конкретные юниты вместо глобального.
  systemd.settings.Manager.DefaultTimeoutStopSec = "5s";
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "5s";

  system.stateVersion = "26.11";
}
