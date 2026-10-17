# Сеть, брандмауэр, время и локаль.
{hostname, ...}: {
  networking = {
    hostName = hostname; # из flake.nix
    networkmanager.enable = true;
    # Открытые порты (59999 — MoonDeck Buddy) задаются в system.json;
    # порты Sunshine открывает его собственный openFirewall.
  };

  # Обнаружение в локальной сети (Sunshine / MoonDeck)
  # Включается в system.json
  services.avahi = {
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  # Часовой пояс и язык — в system.json (modules/system/gui-settings.nix).
}
