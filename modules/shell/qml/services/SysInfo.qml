pragma Singleton

// Сведения о системе для «Настройки → О системе».
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var info: ({})

    function refresh() {
        proc.running = true;
    }

    Process {
        id: proc
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "os=$PRETTY_NAME"
            echo "version=$VERSION_ID"
            echo "host=$(cat /proc/sys/kernel/hostname)"
            echo "kernel=$(uname -r)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
            echo "cores=$(nproc)"
            echo "mem=$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo)"
            echo "gpu=$(for d in /sys/class/drm/card*/device; do [ -r "$d/uevent" ] || continue; p=$(grep PCI_ID "$d/uevent" | cut -d= -f2); n=$(lspci -d "$p" -mm 2>/dev/null | head -1 | awk -F'"' '{print $6}'); [ -n "$n" ] && echo "$n" && break; done)"
            echo "uptime=$(awk '{d=int($1/86400); h=int($1%86400/3600); m=int($1%3600/60); if (d) printf "%d д ", d; printf "%d ч %d мин", h, m}' /proc/uptime)"
            echo "disk=$(df -h / | awk 'NR==2 {print $3 " из " $2}')"
            echo "generation=$(readlink /nix/var/nix/profiles/system | grep -o '[0-9]*')"
            echo "nixpkgs=$(nixos-version 2>/dev/null)"
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf("=");
                    if (i > 0)
                        o[l.slice(0, i)] = l.slice(i + 1);
                }
                root.info = o;
            }
        }
    }
}
