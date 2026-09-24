# Железо этой машины: разделы, диски, модули ядра из nixos-generate-config.
# Остальные её особенности — в host.nix.
{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
  ];
}
