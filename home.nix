{username, ...}: {
  imports = [
    ./modules/hyprland/default.nix
    ./modules/hyprland/host.nix
    ./modules/shell/default.nix
    ./modules/terminal.nix
    ./modules/btop.nix
    ./modules/appearance.nix
    ./modules/cpak-policy.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
