# Фоновые сервисы: звук, печать, ключи, Flatpak, контейнеры.
# Что включено, а что нет (печать, Docker, Bluetooth…), решает system.json —
# см. gui-settings.nix. Здесь только то, без чего система не живёт.
{...}: {
  services.gvfs.enable = true; # Корзина, сетевые диски и MTP для Nemo

  # Хранилище ключей: разблокируется паролем при входе через greetd
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Цель сессии Hyprland. Её запускает hyprland.lua при старте, а за ней
  # поднимаются оболочка (pixel-shell.service из home-manager), история
  # буфера обмена и стандартный автозапуск приложений.
  systemd.user.targets.hyprland-session = {
    description = "Hyprland Session Target";
    requires = ["graphical-session.target"];
    after = ["graphical-session.target"];
    wants = ["xdg-desktop-autostart.target"];
  };

  # Список приложений и автообновление — в system.json
  services.flatpak = {
    enable = true;
    update.auto.onCalendar = "weekly";
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
}
