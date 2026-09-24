🇷🇺 [Читать на русском](README.md)

# ❄️ NixOS Gaming Config

My personal **NixOS** configuration: a gaming desktop built on **Hyprland** and the **DankMaterialShell (DMS)** shell that feels like one coherent desktop environment rather than a tiling WM with some panels bolted on. Fonts, colors, cursor, file pickers and animations are the same everywhere — in native apps, Flatpak, cpak and AppImage.

Everything is declarative: **Flakes** + **Home Manager**, with the Hyprland config written in **Lua**. The look is defined in one place (`flake.nix`) and propagates across the whole system on its own.

## 💻 My Hardware
* **CPU:** AMD Ryzen 7 5700X3D
* **GPU:** AMD Radeon RX 7800 XT
* **Monitors:**
  * 🖥️ LG Ultrawide (2560x1080 @ 100Hz) — Primary
  * 🖥️ Acer (1920x1080 @ 100Hz) — Secondary

## 🎯 The Idea: a Single Source of Truth

Everything that can differ is defined in one place and passed into every module:

* `username` in `flake.nix` — the user name isn't hardcoded anywhere else;
* `appearance` in `flake.nix` — the UI font and its weight, the monospace font, sizes, and the cursor;
* `hosts/<name>/host.nix` — what's specific to one machine: monitors and their workspaces, AMD GPU, undervolt. The folder name is the host name.

```nix
appearance = {
  uiFont = "Google Sans";
  uiFontStyle = "Medium";   # Regular / Medium / Bold
  uiFontSize = 12;
  monoFont = "JetBrainsMono Nerd Font";
  monoFontStyle = "Medium";
  monoFontSize = 12;
  termFontSize = 14;
  cursorTheme = "Adwaita";
  cursorSize = 24;
};
```

Change one line, rebuild, and the font or cursor changes in GTK, Qt, Flatpak, cpak, AppImage, the terminal and the login screen at once. Colors, icons and light/dark mode are DMS's job: you change them in its settings and they reach everything too.

## 🚀 Features

### ⚙️ System & Performance
* **Kernel:** `linuxPackages_cachyos` from [Chaotic-Nyx](https://github.com/chaotic-cx/nyx) + the `sched-ext` scheduler (scx_rustland) for responsiveness and high FPS.
* **Undervolting:** on every boot and after resume, a systemd service runs `scripts/ruv.py`, which applies a Curve Optimizer offset (-25) via `ryzen_smu`.
* **GPU:** LACT for fans and clocks, unlocked `ppfeaturemask`.
* **Quiet boot:** Plymouth with the motherboard logo, no text logs.

### 🪟 Desktop
* **[Hyprland](https://hyprland.org/) 0.56** with a Lua config and the `scrolling` layout: windows line up on a horizontal tape that you scroll through.
* **[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell):** bar, launcher, notifications, clipboard, window overview, lock screen and login screen (`dms-greeter`). Through matugen, DMS themes GTK, Qt, Kitty and Zed with colors taken from the wallpaper.
* **Material 3 Expressive animations, like on a Pixel:** the springs are converted from Android's own tokens (`ExpressiveMotionTokens`). Windows open without any jitter at the end, and workspaces slide vertically.
* **Drag files between workspaces** (a custom DMS plugin, `dndSpring`; see below).
* **Transparency and blur** on windows; fullscreen windows stay opaque.

### 🎨 A Uniform Look for Every App
* **Google Sans** (the Pixel system font) at Medium weight across the whole system. A fontconfig rule swaps the "regular" weight for the chosen one, so GTK, Qt, Chrome, Electron and Flatpak all render medium-weight text.
* **Qt via GTK:** Qt apps take their font, icons and palette from GTK — no separate qt6ct needed.
* **Flatpak** sees the host's themes, icons, fonts, GTK/Qt settings and cursor — read-only. Apps get no extra permissions: they reach files through the shared file picker, and specific permissions can be granted in Flatseal.
* **FHS compatibility:** `/usr/share/fonts`, `/usr/share/icons` and `/usr/share/themes` are mounted from the system, so AppImages, Steam, OnlyOffice and other software not built for NixOS find fonts and icons where they expect them.

### 📂 The Same File Picker Everywhere
The same host GTK file chooser opens everywhere, through xdg-desktop-portal:
* **native GTK3/GTK4 and Qt apps** — via session variables;
* **Flatpak** — via the portal;
* **cpak** — the policy in `modules/cpak-policy.nix` grants every app the host file picker automatically. It runs at login and on every app install or update;
* **AppImage** — via the `appimage-run` shim that every AppImage shortcut goes through.

### 📦 Packages & App Formats
* **Nix** for system packages, **Home Manager** for user settings.
* **Flatpak** declaratively via `nix-flatpak`, with weekly auto-updates.
* **[cpak](https://github.com/Containerpak/cpak)** — containerized apps, with one shared policy for all of them.
* **AppImages** run directly, the way they do on any ordinary distro: `chmod +x` and `./image.AppImage`. The loader comes from `nix-ld`, and the runtime mounts itself over FUSE. Nothing is extracted or cached. If an image is missing a library, add it to `programs.nix-ld.libraries` (find it with `nix-locate`).
* **Distrobox and Docker** (including for WinBoat).

### 🗂 Applications
* **Nemo file manager** with previews (`nemo-preview`); "Open in Terminal" opens Kitty. An AppImage extension adds "Add to application menu" / "Remove from application menu" to the context menu. The desktop entry, its icon and description come from the image itself, and the image stays where it is.
* **Zed** as the code editor; DMS generates its `DankShell Dark/Light` theme.
* **btop as an overlay** (`SUPER + M` or `SUPER + SHIFT + Esc`): CPU, AMD GPU, memory, network and processes in a drop-in window on the focused monitor. It takes its colors from the terminal, i.e. from DMS.
* Qalculate!, Celluloid, Papers, Baobab, Loupe, GNOME Text Editor, GNOME Calendar, OnlyOffice, qBittorrent, Google Chrome, Telegram, YouTube Music.
* **Terminal:** Kitty + Fish + Fastfetch (Fastfetch is skipped inside VS Code and Zed terminals).
* **Live wallpapers** from the Steam Workshop via `linux-wallpaperengine`.

### 🎮 Gaming & Streaming
* Steam (with a Gamescope session), Gamemode, MangoHud, Lutris, Heroic, ProtonPlus, Protontricks.
* **Sunshine** starts automatically: streams games to Moonlight, with firewall ports open and LAN discovery via Avahi (MoonDeck).
* **Steam Remote Play** on Wayland: Steam runs with `-pipewire` and captures the screen through the portal.
* **Screen recording** with GPU Screen Recorder in AV1 at 60 FPS.

## 🖥️ Monitors & Workspaces

Workspaces are strictly assigned to the two monitors, so you always know where each app lives and nothing gets lost while gaming. The layout lives in `hosts/nixos/host.nix`: it generates the monitors and workspace rules for Hyprland (`hypr/host.lua`) and the login screen's monitors.

**Primary monitor (LG Ultrawide, HDMI-A-1):**
* Workspaces **1–4** plus the **5 (Gaming)** workspace. Switch with `SUPER + [1, 2, 3, 4, G]`.
* 🎮 Processes flagged as `game`, launchers (Lutris, Heroic, Bottles) and Gamescope are sent to workspace **5** automatically. Anything that opens there becomes a floating window.

**Secondary monitor (Acer, HDMI-A-2):**
* Workspaces **6–9**. Switch with `SUPER + [F1, F2, F3, F4]`.
* Apps open in their own places automatically:
  * **6 (F1):** Discord
  * **7 (F2):** Telegram
  * **8 (F3):** YouTube Music
  * **9 (F4):** Steam main window

## 🖱️ Dragging Files Between Workspaces (`dndSpring`)

A custom DMS plugin (`modules/dms/plugins/dndSpring`) that adds macOS-style spring-loaded workspaces:

* **Top edge of the screen.** Drag a file to the top and a row with this monitor's workspaces appears. Hold the file over one and that workspace opens while the file stays in your hand, ready to drop into any window there. Just sliding along the row doesn't trigger anything.
* **Left and right edges.** Hold a file at an edge and the window tape scrolls that way, speeding up the longer you hold.
* It works on the DMS frame too, and plays nicely with the bar: on the bar's edge the strip sits next to it and doesn't block its buttons.
* If you release the file right over a strip, the plugin refuses the drop, so the source app neither copies nor deletes anything.

The plugin is enabled automatically on rebuild. You can turn it off in DMS Settings → Plugins, and that choice is kept. The speed can be tuned with the numbers at the top of `DndSpring.qml`.

To move a **window** to another workspace, use the overview (`SUPER + TAB`): window thumbnails can be dragged between workspaces with the mouse.

---

## ⌨️ Keybindings

The main modifier key is **SUPER (Windows)**.

### 🚀 Quick Launch
| Hotkey | Action |
| :--- | :--- |
| `SUPER + W` | Web browser (Google Chrome) |
| `SUPER + T` | Terminal (Kitty) |
| `SUPER + E` | File manager (Nemo) |
| `SUPER + C` | Code editor (Zed) |
| `SUPER + Space` | 🔍 Global search (DMS) |

### 🛠 Utilities & Menus (DMS)
| Hotkey | Action |
| :--- | :--- |
| `SUPER + V` | Clipboard |
| `SUPER + M` / `SUPER + SHIFT + Esc` | System monitor (btop overlay) |
| `SUPER + S` | DMS settings |
| `SUPER + N` | Notification center |
| `SUPER + Y` | Wallpaper picker |
| `SUPER + TAB` | Window overview |
| `SUPER + SHIFT + Q` | ⚡ Power menu |
| `SUPER + ALT + L` | 🔒 Lock screen |

### 📸 Screenshots & Screen Recording (AV1, 60 FPS)
*Grim, Slurp and GPU Screen Recorder.*
| Hotkey | Action |
| :--- | :--- |
| `SUPER + SHIFT + S` | Screenshot a region (to clipboard + notification) |
| `SUPER + SHIFT + A` | Screenshot the whole screen |
| `SUPER + SHIFT + D` | Screenshot the active window |
| `ALT + F9` | 🔴 Start/stop recording **without** microphone |
| `ALT + F10` | 🎙️ Start/stop recording **with** microphone |

### 🪟 Window Management
| Hotkey | Action |
| :--- | :--- |
| `SUPER + Q` | Close window |
| `SUPER + Escape` | Kill an unresponsive window (`hyprctl kill`) |
| `SUPER + ALT + Space` | Toggle floating |
| `SUPER + F` | Fullscreen |
| `SUPER + D` | Maximize, keeping the bar visible |
| `SUPER + J` | Toggle split direction |
| `SUPER + Arrows` | Move focus between windows |
| `SUPER + SHIFT + Arrows` | Move window |
| `ALT + Tab` | Cycle through windows |
| `SUPER + LMB / RMB` | Drag / resize window |

### 🗂 Workspaces
* **Switch:** `SUPER + [1-4, G]` (primary monitor), `SUPER + [F1-F4]` (secondary).
* **Send window:** `SUPER + SHIFT + [1-4, G, F1-F4]`.
* **Neighbors:** `SUPER + CTRL + ←/→` flips through workspaces on the current monitor, `SUPER + CTRL + ↓` jumps to the first empty one.
* **Window to a neighbor:** `SUPER + CTRL + SHIFT + ←/→`, or the mouse wheel with the same keys.
* **Mouse:** the wheel with `SUPER` or `SUPER + CTRL` held flips through workspaces.

## 🗃 Repository Layout

```
flake.nix                 inputs, username, appearance; one host per folder in hosts/
configuration.nix         list of system modules
home.nix                  list of Home Manager modules

hosts/nixos/              my machine (folder name = host name)
  host.nix                monitors and workspaces, AMD GPU, undervolt
  default.nix             pulls in the hardware:
  hardware-configuration.nix, disks.nix

scripts/
  ruv.py                  Ryzen undervolt via ryzen_smu
  safe-update.sh          update: build → diff → trial run → switch
.github/workflows/        config check on every push, weekly update

modules/system/
  boot.nix                bootloader, kernel, Plymouth, undervolt
  desktop.nix             Hyprland, DMS, login screen, portals, fonts
  google-sans.nix         Google Sans font from google/fonts
  fhs-compat.nix          /usr/share/{fonts,icons,themes} for foreign software
  nemo.nix                Nemo, previews and the AppImage menu
  appimage.nix            direct AppImage launch and the appimage-run shim
  nix-ld.nix              libraries for third-party binaries
  gaming.nix              Steam, Gamescope, Sunshine, LACT
  packages.nix            system packages
  services.nix            audio, Flatpak, cpak, gvfs, Docker
  flatpak-overrides.nix   Flatpak permissions: shared look, files via the portal
  network.nix, users.nix  network, locale, user

modules/
  appearance.nix          GTK/fontconfig fonts, font weight, cursor
  cpak-policy.nix         shared file-picker policy for cpak apps
  terminal.nix            Kitty, Fish, Fastfetch
  dms/
    hyprland.lua          main Hyprland config and animations
    binds.lua             keybindings
    windowrules.lua       window and workspace rules
    default.nix           config placement, xdph, plugin enabling
    host.nix              generates hypr/host.lua from host.nix
    plugins/dndSpring/    file drag-and-drop plugin
```

## 📦 How to Apply

> **Your own machine.** All hardware lives in `hosts/<name>/`. Copy `hosts/nixos` to a folder named after your host, put your own `hardware-configuration.nix` there (`nixos-generate-config --show-hardware-config`), adjust or empty `disks.nix`, and describe your monitors, GPU and undervolt in `host.nix` (better to disable the undervolt: `undervolt = null;` — the offset is tuned per CPU). Change `username` in `flake.nix`. Build with `.#<folder name>`.

The config lives in the home directory as a regular git repository:

```bash
# 1. Clone
git clone https://github.com/deadinside28/nixos-config.git ~/nixos-config
cd ~/nixos-config

# 2. Update the lock file (optional)
nix flake update

# 3. Apply
sudo nixos-rebuild switch --flake .#nixos
```

> Flakes only see files that git knows about. A new module has to be `git add`ed, or the build will act as if it doesn't exist.

## ⚠️ Known Limitations
* **Steam Remote Play on Wayland** may flicker and crash — that's a bug in Steam itself. Streaming from the Gamescope session or via Sunshine + Moonlight is more reliable.
* **Wine apps** draw their own file picker: Wine doesn't use the portal.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
