# Фоновые сервисы: звук, печать, ключи, Flatpak, контейнеры.
{...}: {
  services.gvfs.enable = true; # Корзина, сетевые диски и MTP для Nemo
  services.printing.enable = true;

  # Хранилище ключей
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.dms-greeter.enableGnomeKeyring = true;

  systemd.user.targets.hyprland-session = {
    description = "Hyprland Session Target";
    requires = ["graphical-session.target"];
    after = ["graphical-session.target"];
    # Подключаем стандартный автозапуск приложений вместе с DMS
    wants = [
      "dms.service"
      "xdg-desktop-autostart.target"
    ];
  };

  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
    packages = [
      "io.github.kolunmi.Bazaar"
      "com.github.tchx84.Flatseal"
      "io.github.radiolamp.mangojuice"
      "org.freedesktop.Platform.VulkanLayer.MangoHud//26.08"
    ];
  };

  services.cpak.enable = true;

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
}
