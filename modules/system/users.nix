# Пользователь, оболочка и общесистемные мелочи systemd.
{
  config,
  lib,
  pkgs,
  username,
  ...
}: {
  programs.fish.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = ["networkmanager" "wheel" "docker" "i2c"];
    shell = pkgs.fish;
    packages = [];
  };

  # Сколько ждать остановки зависшего юнита при выключении (по умолчанию
  # в systemd — 90 с). Таймаут получает КАЖДЫЙ юнит, поэтому он не меньше
  # обычного времени корректной остановки: за 5 с запись экрана может не
  # успеть дописать файл. Тем, кому нужно больше, — свой таймаут ниже.
  systemd.settings.Manager.DefaultTimeoutStopSec = "10s";
  systemd.user.settings.Manager.DefaultTimeoutStopSec = "10s";

  # Контейнеры (в том числе Windows-ВМ WinBoat) получают SIGTERM и до
  # 10 с на остановку; убитый раньше dockerd оборвал бы их на полуслове.
  systemd.services.docker = lib.mkIf config.virtualisation.docker.enable {
    serviceConfig.TimeoutStopSec = "30s";
  };

  system.stateVersion = "26.11";
}
