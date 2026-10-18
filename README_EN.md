🇷🇺 [Читать на русском](README.md)

# ❄️ NixOS Gaming Config

My personal **NixOS** configuration: a gaming desktop built on **Hyprland** and a custom shell, **Pixel Shell** (Quickshell, Material 3 in the style of Pixel desktop mode and Aluminium OS), that feels like one coherent desktop environment rather than a tiling WM with some panels bolted on. Fonts, colors, cursor, file pickers and animations are the same everywhere — in native apps, Flatpak, cpak and AppImage.

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
* `configDir` in `flake.nix` — where this flake lives (`~/nixos-config` by default); the shell edits and rebuilds it from there;
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

Change one line, rebuild, and the font or cursor changes in GTK, Qt, Flatpak, cpak, AppImage, and the terminal at once. Colors, icons and light/dark mode are the shell's job: you change them in its Settings app and they reach everything too.

## 🚀 Features

### ⚙️ System & Performance
* **Kernel:** `linuxPackages_cachyos` from [Chaotic-Nyx](https://github.com/chaotic-cx/nyx) + the `sched-ext` scheduler (scx_rustland) for responsiveness and high FPS.
* **Undervolting:** on every boot and after resume, a systemd service runs `scripts/ruv.py`, which applies a Curve Optimizer offset (-25) via `ryzen_smu`.
* **GPU:** LACT for fans and clocks, unlocked `ppfeaturemask`.
* **Quiet boot:** Plymouth with the motherboard logo, no text logs.

### 🪟 Desktop
* **[Hyprland](https://hyprland.org/) 0.56** with a Lua config and the `scrolling` layout: windows line up on a horizontal tape that you scroll through.
* **Window modes without logging out:** Scrolling, Dwindle, Master, Mixed (tiling, but chosen apps float) and Floating — one for all workspaces plus a per-workspace override. Switch them in Settings → Windows, with the "Windows" quick-settings tile, or `Super + Shift + Space` (current workspace). Already open windows are rearranged right away.
* **App menu editor** (Settings → App menu): launcher folders, custom names and icons, hiding without uninstalling, extra keywords, arguments, environment variables, working directory, run-in-terminal and custom commands. Edits sit on top of the `.desktop` files and survive package updates; same-named apps from different sources (Nix, Flatpak, AppImage…) are labelled with their source.
* **Storage** (Settings → Storage): what fills the disk — the system and kept generations, Flatpaks and their data, cache, trash, home; per-app sizes (for Nix, the package itself and separately its closure with shared dependencies); clearing cache and resetting data only where the app's data location is known. Home Manager–managed settings and running apps are never touched.
* **Store** (its own window, `pixel-shell store open`): one search across Nixpkgs, Chaotic-Nyx and Flatpak. Nix packages come from a local index of the exact revisions pinned in `flake.lock`, so what you install is what the system builds — without bumping inputs. Install/remove edit `system.json` and are applied by a background rebuild; "Installed" only shows after a successful apply. Tabs for installed apps, updates (system updates are separate from installing) and history.
* **Pixel Shell** (`modules/shell`), a custom [Quickshell](https://quickshell.org) shell: taskbar, launcher, quick settings, notifications, overview, clipboard, lock screen, polkit agent and a Settings app (see below). Login is greetd with autologin.
* **Material 3 Expressive animations, like on a Pixel:** the springs are converted from Android's own tokens (`ExpressiveMotionTokens`). Windows open without any jitter at the end, and workspaces slide vertically.
* **Drag files between workspaces** (the shell's `dndSpring` module; see below).
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
* **AppImages** run directly, the way they do on any ordinary distro: `chmod +x` and `./image.AppImage` — or double-click in Files, which sets the executable bit itself. The loader comes from `nix-ld`, and the runtime mounts itself over FUSE. Nothing is extracted or cached. The libraries images expect from the host are the same set the stock `appimage-run` provides. If an image is still missing a library, add it to `programs.nix-ld.libraries` (find it with `nix-locate`).
* **Distrobox and Docker** (including for WinBoat).

### 🗂 Applications
* **Nemo file manager** with previews (`nemo-preview`); "Open in Terminal" opens Kitty. An AppImage extension adds "Add to application menu" / "Remove from application menu" to the context menu. The desktop entry, its icon and description come from the image itself, and the image stays where it is.
* **Zed** as the code editor.
* **btop as an overlay** (`SUPER + M` or `SUPER + SHIFT + Esc`): CPU, AMD GPU, memory, network and processes in a drop-in window on the focused monitor. It takes its colors from the terminal, i.e. from the wallpaper.
* Qalculate!, Celluloid, Papers, Baobab, Loupe, GNOME Text Editor, GNOME Calendar, OnlyOffice, qBittorrent, Google Chrome, Telegram, YouTube Music.
* **Terminal:** Kitty + Fish + Fastfetch (Fastfetch is skipped inside VS Code and Zed terminals).
* **Live wallpapers** from the Steam Workshop via `linux-wallpaperengine`, picked right in Settings → Wallpaper & style.

### 🎮 Gaming & Streaming
* Steam (with a Gamescope session), Gamemode, MangoHud, Lutris, Heroic, ProtonPlus, Protontricks.
* **Sunshine** starts automatically: streams games to Moonlight, with firewall ports open and LAN discovery via Avahi (MoonDeck).
* **Steam Remote Play** on Wayland: Steam runs with `-pipewire` and captures the screen through the portal.
* **Screen recording** with GPU Screen Recorder in AV1 at 60 FPS.

## 📱 Pixel Shell

Written from scratch on Quickshell to replace DMS, styled after Pixel desktop mode / Aluminium OS: Material 3 Expressive, Google Sans, Material Symbols icons, wallpaper colors via matugen.

* **Taskbar** at the bottom: ring launcher button, workspace dots, pinned and running apps in the center (pill indicator under the focused one), tray, notification counter and a status pill with network, Bluetooth, volume and the clock. Right-click an icon for app actions, new window, pin, close.
* **Launcher** (`SUPER + Space`): search field, frequent apps, grid of all apps. Fuzzy search, arrow keys, calculator (`=2+2`), terminal command (`>htop`), web search.
* **Quick settings** (click the clock, `SUPER + N`): Android 16 style tiles, thick volume/brightness sliders, an MPRIS player and the notification center above.
* **Notifications** with actions, inline reply and swipe to dismiss; **overview** (`SUPER + TAB`), **clipboard** (`SUPER + V`, cliphist), **power menu**, Pixel-style **lock screen**, volume **OSD**, **polkit agent**, **idle** lock/screen-off/suspend timers.

### ⚙️ Settings — the whole system from a GUI

A regular window (`SUPER + S`, or "Настройки" in the launcher) with sections on the left, like on a Pixel: network & Wi-Fi, Bluetooth, displays (drag-to-arrange layout, resolution, refresh rate, scale, VRR, 15 s auto-revert, night light), sound (devices, per-app volume), wallpaper & style (wallpapers, **Wallpaper Engine**, wallpaper or custom colors, 8 palette styles, dark theme, icons), desktop & windows (taskbar, pinned apps, clock, Hyprland rounding/gaps/border/opacity/blur), notifications, apps (defaults, autostart), keyboard & mouse (layouts, repeat, sensitivity, acceleration, shortcut list), power & lock, **System** and About.

Everything except **System** applies instantly. The **System** section edits **`system.json`** at the repo root (read by `modules/system/gui-settings.nix`): time zone and language, services (Bluetooth, printing, Docker, Sunshine, sched-ext, zram…), gaming, **nixpkgs and Flatpak packages with search**, firewall ports, garbage collection. "Apply" builds the system as your user and switches via `pkexec` (the shell's polkit dialog asks for the password) — `nixos-rebuild switch` with progress and a log right in the window. Also: update (flake update + rebuild), test build, roll back to the previous generation.

### 🌌 Wallpaper Engine

Settings → Wallpaper & style → Live wallpapers: the shell finds Steam Workshop wallpapers in every Steam library (native, Flatpak, extra drives from `libraryfolders.vdf`), shows previews and types, and runs `linux-wallpaperengine` on all monitors, with sound, volume, FPS, scaling and pause-in-fullscreen options. The palette is taken from the wallpaper preview. Scene wallpapers need Wallpaper Engine itself installed in Steam (its assets).

## 🖥️ Monitors & Workspaces

Workspaces are strictly assigned to the two monitors, so you always know where each app lives and nothing gets lost while gaming. The layout lives in `hosts/nixos/host.nix`: it generates the default monitor modes and workspace rules for Hyprland (`hypr/host.lua`). Resolution, refresh rate and layout are then changed in Settings → Display.

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

A shell module (`modules/shell/qml/modules/dnd`) that adds macOS-style spring-loaded workspaces:

* **Top edge of the screen.** Drag a file to the top and a row with this monitor's workspaces appears. Hold the file over one and that workspace opens while the file stays in your hand, ready to drop into any window there. Just sliding along the row doesn't trigger anything.
* **Left and right edges.** Hold a file at an edge and the window tape scrolls that way, speeding up the longer you hold.
* If you release the file right over a strip, the plugin refuses the drop, so the source app neither copies nor deletes anything.

The speed can be tuned with the numbers at the top of `DndSpring.qml`.


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
| `SUPER + Space` | 🔍 Launcher |

### 🛠 Utilities & Menus
| Hotkey | Action |
| :--- | :--- |
| `SUPER + V` | Clipboard |
| `SUPER + M` / `SUPER + SHIFT + Esc` | System monitor (btop overlay) |
| `SUPER + S` | Settings |
| `SUPER + N` | Quick settings & notifications |
| `SUPER + Y` | Wallpaper & style |
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
flake.nix                 inputs, username, appearance, system.json; one host per folder in hosts/
system.json               system settings from the GUI (Settings → System)
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
  desktop.nix             Hyprland, greetd, portals, fonts
  gui-settings.nix        system.json → NixOS options
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
  hyprland/
    hyprland.lua          main Hyprland config and animations
    binds.lua             keybindings
    windowrules.lua       window and workspace rules
    default.nix           config placement, xdph, Flatpak overrides
    host.nix              generates hypr/host.lua from host.nix
  shell/
    default.nix           shell service, pixel-* scripts, matugen
    matugen/              color templates: shell, GTK, kitty, Hyprland
    qml/                  the shell itself: common/, widgets/, services/, modules/
```

## 📦 How to Apply

> **Your own machine.** All hardware lives in `hosts/<name>/`. Copy `hosts/nixos` to a folder named after your host, put your own `hardware-configuration.nix` there (`nixos-generate-config --show-hardware-config`), adjust or empty `disks.nix`, and describe your monitors, GPU and undervolt in `host.nix` (better to disable the undervolt: `undervolt = null;` — the offset is tuned per CPU). Change `username` in `flake.nix` (and `configDir` if you cloned somewhere other than `~/nixos-config`). Build with `.#<folder name>`.

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
