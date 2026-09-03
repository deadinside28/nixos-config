local SUPER = "SUPER"

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("systemctl --user start hyprland-session.target")
  require("dms.autostart")
  hl.exec_cmd("xrandr --output HDMI-A-1 --primary")

end)

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_QPA_PLATFORMTHEME_QT6", "gtk3")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("MANGOHUD", "1")

-- Monitors
MONITOR1 = "HDMI-A-1"
MONITOR2 = "HDMI-A-2"
MONITOR3 = ""
PRIMARY_MONITOR = MONITOR1

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle",
    },
    general = {
        layout = "scrolling",
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
    },
    decoration = {
        
        blur = {
            enabled = true,
            size = 5,           -- Радиус размытия (чем выше, тем сильнее "мыло")
            passes = 3,         -- Количество проходов рендера. Значения 2 или 3 дают плотный эффект красивого матового стекла
            ignore_opacity = true, -- Делает блюр равномерным независимо от того, насколько прозрачно окно
            noise = 0.0117,     -- Добавляет легкий шум, чтобы на размытии не появлялись уродливые градиентные полосы
            contrast = 0.8916,  -- Контрастность того, что находится под окном
            brightness = 1.0,   -- Яркость фона под окном
            vibrancy = 0.2,     -- Насыщенность (если выкрутить, цвета обоев под окнами станут более сочными)
        }
    }
})

hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "5", monitor = MONITOR1, default = true, persistent = true  })
hl.workspace_rule({ workspace = "6", monitor = MONITOR2, persistent = true })
hl.workspace_rule({ workspace = "7", monitor = MONITOR2, persistent = true })
hl.workspace_rule({ workspace = "8", monitor = MONITOR2, persistent = true })
hl.workspace_rule({ workspace = "9", monitor = MONITOR2, persistent = true })

-- Делаем все окна прозрачными на 90%, чтобы сквозь них стало видно размытие,
-- но при этом жестко фиксируем 100% непрозрачность (1.0) для полноэкранных окон.
hl.window_rule({ 
    match = { class = ".*" }, 
    opacity = "0.93 override 0.93 override 1.0 override" 
})

hl.window_rule({
    match = {
        class = "^(com\\.google\\.Chrome|google-chrome|mpv|io\\.mpv\\.Mpv)$"
    },
    monitor = PRIMARY_MONITOR,
    no_vrr = true
})

require("dms.colors")
require("dms.layout")
require("dms.outputs")
require("dms.binds")
require("dms.binds-user")
require("dms.windowrules")
require("dms.cursor")
