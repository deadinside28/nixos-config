{...}: {
  imports = [
    ./modules/dms/default.nix
    ./modules/terminal.nix
    ./modules/appimage-run.nix
    ./modules/user-services.nix
  ];

  home.username = "deadinside";
  home.homeDirectory = "/home/deadinside";
  home.stateVersion = "26.11";

  # Разрешаем Home Manager управлять собой
  programs.home-manager.enable = true;
}
