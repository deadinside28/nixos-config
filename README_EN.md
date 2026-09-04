🇷🇺 [Читать на русском](README.md)

# ❄️ NixOS Gaming Config

My personal **NixOS** configuration, optimized for maximum performance, gaming, and comfortable tiling. 

Built with **Flakes** and **Home Manager**. The desktop environment is managed by a custom shell based on **Hyprland**, with its configuration written in **Lua**.

## 💻 My Hardware
* **CPU:** AMD Ryzen 7 5700X3D
* **GPU:** AMD Radeon RX 7800 XT
* **Monitors:** 
  * 🖥️ LG Ultrawide (2560x1080 @ 100Hz) — Primary
  * 🖥️ Acer (1920x1080 @ 100Hz) — Secondary

## 🚀 Key Features & Technologies

* **Kernel:** `linuxPackages_cachyos` (via the [Chaotic-Nyx](https://github.com/chaotic-cx/nyx) repository). Uses the `sched-ext` (scx_rustland) scheduler for maximum system responsiveness and high FPS.
* **Window Manager:** [Hyprland](https://hyprland.org/). Window rules, keybinds, and settings are organized in a modular structure using **Lua** (DMS integration).
* **Gaming:** Native Steam, Gamescope, Gamemode, and custom Proton builds (via ProtonPlus/Heroic).
* **Streaming:** Autostarts Sunshine (Moonlight) for streaming games to other devices with open firewall ports.
* **Automated Undervolting:** A systemd service runs a custom Python script (`scripts/ruv.py`) on boot to apply a Curve Optimizer offset (-25) directly to the Ryzen CPU via `ryzen_smu`.
* **Package Management:**
  * System packages — Nix
  * User apps — Home Manager
  * Declarative Flatpaks — via `nix-flatpak`
  * AppImages — via `appimage-run` (includes a `systemd` timer that automatically fetches `.desktop` files and icons for AppImages into the application menu).
* **Terminal:** Kitty + Fish shell + custom Fastfetch output.
* **Customization:** Live wallpapers directly from the Steam Workshop via `linux-wallpaperengine`.

## 🖥️ Monitor & Workspace Logic (Hyprland)

The system has a strictly defined workspace layout across two monitors. This ensures you always know where specific applications are located, keeping them in sight while gaming.

**Primary Monitor (LG Ultrawide, HDMI-A-1):**
* Dedicated to workspaces **1 to 4**, plus a special **5 (Gaming)** workspace.
* 🎮 Workspace **5** is an exclusive gaming screen. All processes with the `game` flag, Steam, Battle.net, and Gamescope windows are automatically routed here.
* Navigation is done using `SUPER + [1, 2, 3, 4, G]`.

**Secondary Monitor (Acer, HDMI-A-2):**
* Dedicated to workspaces **6 to 9**. Navigation: `SUPER + [F1, F2, F3, F4]`.
* These workspaces have a strict auto-start layout (Auto-tiling):
  * **6 (F1):** Discord
  * **7 (F2):** Telegram
  * **8 (F3):** YouTube Music
  * **9 (F4):** Steam Main Window

---

## ⌨️ Keybindings

The main modifier key (MainMod) is **SUPER (Windows)**.

### 🚀 Quick Launch (Launchers)
| Hotkey | Action |
| :--- | :--- |
| `SUPER + W` | Web Browser (Google Chrome) |
| `SUPER + T` | Terminal (Kitty) |
| `SUPER + E` | File Manager (Nautilus) |
| `SUPER + C` | Code Editor (VS Code) |
| `SUPER + Space` | 🔍 Global Search (via DMS) |

### 🛠 Utilities & Menus (DMS Integration)
| Hotkey | Action |
| :--- | :--- |
| `SUPER + V` | Clipboard Manager |
| `SUPER + M` | Task Manager (Processlist) |
| `SUPER + S` | Quick Settings |
| `SUPER + N` | Notification Center |
| `SUPER + Y` | Wallpaper Picker (Dankdash wallpaper) |
| `SUPER + TAB` | Window Overview |
| `SUPER + SHIFT + Q` | ⚡ Powermenu |
| `SUPER + ALT + L` | 🔒 Lock Screen |

### 📸 Screenshots & Screen Recording (AV1, 60 FPS)
*Uses native Wayland utilities (Grim, Slurp) and GPU Screen Recorder.*
| Hotkey | Action |
| :--- | :--- |
| `SUPER + SHIFT + S` | Screenshot selected area (to clipboard + notification) |
| `SUPER + SHIFT + A` | Screenshot full screen |
| `SUPER + SHIFT + D` | Screenshot active window |
| `ALT + F9` | 🔴 Start/Stop screen recording **WITHOUT** microphone |
| `ALT + F10` | 🎙️ Start/Stop screen recording **WITH** microphone |

### 🪟 Window Management
| Hotkey | Action |
| :--- | :--- |
| `SUPER + Q` | Close window |
| `SUPER + Escape` | Kill unresponsive window (`hyprctl kill`) |
| `SUPER + ALT + Space` | Toggle floating mode |
| `SUPER + F` | Fullscreen |
| `SUPER + D` | Maximize window (keep panel visible) |
| `SUPER + J` | Toggle split direction |
| `SUPER + Arrows` | Move focus between windows |
| `SUPER + SHIFT + Arrows` | Move window in grid |
| `ALT + Tab` | Cycle through windows |
| `SUPER + LMB / RMB` | Drag / Resize floating window |

### 🗂 Workspace Navigation
* **Switching:** `SUPER + [1-4, G]` (Primary monitor), `SUPER + [F1-F4]` (Secondary monitor).
* **Move window:** `SUPER + SHIFT + [1-4, G, F1-F4]` — send active window to the corresponding workspace.
* **Adjacent screens:** `SUPER + CTRL + Left/Right Arrows` — scroll through workspaces on the current monitor.
* **Mouse:** Scroll through workspaces using the mouse wheel while holding `SUPER` or `SUPER + CTRL`.

## 📦 How to Apply This Configuration

> **Warning:** This configuration contains hardware-specific settings (disk UUIDs in `disks.nix`, scripts for Ryzen). Before using it on another machine, make sure to edit `hardware-configuration.nix` and `disks.nix`.

Since this is a system configuration, it is stored in the standard `/etc/nixos` directory.

```bash
# 1. Clone the repository (as root)
sudo git clone https://github.com/deadinside28/nixos-config.git /etc/nixos
cd /etc/nixos

# 2. Update the lock file (optional)
sudo nix flake update

# 3. Apply the system configuration
sudo nixos-rebuild switch --flake /etc/nixos#nixos
