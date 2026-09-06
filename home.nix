{username, ...}: {
  imports = [
    ./modules/dms/default.nix
    ./modules/terminal.nix
    ./modules/appimage-run.nix
    ./modules/user-services.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.11";

  programs.home-manager.enable = true;
}
