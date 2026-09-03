{ config, pkgs, ... }:

{
  # --- Терминал Kitty ---
  programs.kitty = {
    enable = true;
    font = {
      name = "Noto Sans Mono CJK SC";
      size = 14;
    };
    settings = {
      confirm_os_window_close = 0;
    };
    extraConfig = ''
      include ~/.config/kitty/dank-theme.conf
      include ~/.config/kitty/dank-tabs.conf
      allow_remote_control yes
      listen_on unix:/tmp/kitty
    '';
  };
  
  # --- Fastfetch конфиг ---
  xdg.configFile."fastfetch/config.jsonc".text = ''
    {
      "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
      "logo": {
        "type": "auto",
        "padding": { "right": 3 }
      },
      "display": {
        "separator": " -> ",
        "color": { "separator": "white" }
      },
      "modules": [
        { "type": "os", "key": "OS ", "keyColor": "white" },
        { "type": "kernel", "key": " ├  ", "keyColor": "white" },
        { "type": "packages", "key": " ├ 󰏖 ", "keyColor": "white" },
        { "type": "shell", "key": " └  ", "keyColor": "white" },
        "break",
        { "type": "wm", "key": "WM ", "keyColor": "white" },
        { "type": "theme", "key": " ├ 󰉼 ", "keyColor": "white" },
        { "type": "icons", "key": " ├ 󰀻 ", "keyColor": "white" },
        { "type": "terminal", "key": " ├  ", "keyColor": "white" },
        { "type": "terminalfont", "key": " └  ", "keyColor": "white" },
        "break",
        { "type": "host", "key": "PC ", "keyColor": "white" },
        { "type": "cpu", "key": " ├  ", "keyColor": "white" },
        { "type": "gpu", "key": " ├ 󰢮 ", "keyColor": "white" },
        { "type": "memory", "key": " ├  ", "keyColor": "white" },
        { "type": "swap", "key": " ├ 󰓡 ", "keyColor": "white" },
        { "type": "disk", "key": " ├  ", "folders": "/", "keyColor": "white" },
        { "type": "disk", "key": " ├  ", "folders": "/mnt/GAMES", "keyColor": "white" },
        { "type": "display", "key": " └ 󰍹 ", "keyColor": "white" }
      ]
    }
  '';
  
  # --- Настройка Fish ---
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
      fastfetch
    '';
  };
}