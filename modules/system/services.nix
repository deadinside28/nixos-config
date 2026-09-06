# Фоновые сервисы: звук, печать, ключи, Flatpak, контейнеры.
{...}: {
  services.gvfs.enable = true; # Корзина, сетевые диски и MTP для Nautilus
  services.printing.enable = true;

  # Хранилище ключей
  services.gnome.gnome-keyring.enable = true;

  # Мост для передачи статуса из нативной системы в Flatpak-Discord
  systemd.user.services.discord-flatpak-rpc = {
    description = "Bridge Discord Flatpak RPC to host";
    wantedBy = ["default.target"];
    script = ''
      ln -sf $XDG_RUNTIME_DIR/app/com.discordapp.Discord/discord-ipc-0 $XDG_RUNTIME_DIR/discord-ipc-0
    '';
  };

  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
    packages = [
      "com.discordapp.Discord"
      "io.github.kolunmi.Bazaar"
      "com.github.tchx84.Flatseal"
    ];
  };

  # Звук (PipeWire)
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Контейнеры (WinBoat, distrobox)
  virtualisation.docker.enable = true;
  virtualisation.podman.enable = true;
}
