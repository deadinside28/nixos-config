{username, ...}: {
  imports = [
    ./modules/dms/default.nix
    ./modules/terminal.nix
    ./modules/appearance.nix
    ./modules/cpak-policy.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
