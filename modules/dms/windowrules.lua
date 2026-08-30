-- Window rules wiki https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Generic floating position
hl.window_rule({ match = { float = true }, center = true })

-- Picture-in-Picture
hl.window_rule({
    match             = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
    float             = true,
    keep_aspect_ratio = true,
    size              = { "max(monitor_w, monitor_h)*0.25", "min(monitor_w, monitor_h)*0.25" },
    pin               = true,
})

-- Gaming

-- Добавляем Battle.net в одну группу со steam-играми и gamescope
local gamingApps = "^(steam_app.*|gamescope|[Bb]attle\\.net\\.exe)$"
local gamingWorkspace = 5

hl.window_rule({ match = { content = "game" }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = gamingApps }, workspace = gamingWorkspace })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Launching\\.{3})$" }, float = true, center = true, workspace = gamingWorkspace })

-- Игры и Battle.net: плавающие окна по умолчанию. 
-- Без ограничений fullscreen_state Hyprland автоматически развернет окно, если игра это запросит.
hl.window_rule({
    match = { class = gamingApps },
    float = true,
    center = true,
})

-- Лаунчеры Lutris и Heroic принудительно переведены в тайлинг
hl.window_rule({
    match = { class = "^(net\\.lutris\\.Lutris|com\\.heroicgameslauncher\\.hgl)$" },
    float = false,
    workspace = gamingWorkspace
})

-- Apps
-- Убрано fullscreen_state = 0, чтобы остальные .exe файлы также могли открываться на весь экран
hl.window_rule({ match = { class = "^(.*\\.exe)$" }, float = true, monitor = PRIMARY_MONITOR, center = true })
hl.window_rule({ match = { class = "^(.*[Ll]auncher.*)$" }, float = true, monitor = PRIMARY_MONITOR })
--hl.window_rule({ match = { class = "^(vesktop|discord)$" }, monitor = PRIMARY_MONITOR })
hl.window_rule({ match = { class = "^(.*[Cc]alc.*)$" }, float = true, size = { "max(monitor_w, monitor_h)*0.17", "min(monitor_w, monitor_h)*0.43" } })
hl.window_rule({ match = { class = "^(org\\.kde\\.keditfiletype)$" }, float = true })
hl.window_rule({ match = { class = "^(org\\.kde\\.ark)$" }, size = { "max(monitor_w, monitor_h)*0.40", "min(monitor_w, monitor_h)*0.40" } })
hl.window_rule({ match = { class = "^(.*satty.*)$", title = "^(Satty)$" }, min_size = { "max(monitor_w, monitor_h)*0.35", "min(monitor_w, monitor_h)*0.35" }, float = true })

-- Плавающее окно выбора экрана для стрима (портал xdg)
hl.window_rule({
    match = {
        title = "^(Select what to share)$"
    },
    float = true,
    center = true,
    size = { "400", "400" }
})

hl.window_rule({ 
    match = { 
        class = "^(org\\.telegram\\.desktop)$", 
        title = "^(Media viewer|Просмотр медиа)$" 
    }, 
    float = true, 
    center = true 
})

hl.window_rule({
    match = {
        class = "^([Gg]oogle-chrome)$",
        title = "^(Вход – Google Аккаунты.*)$"
    },
    float = true,
    center = true
})

-- Плавающие диалоговые окна и настройки Steam (всё, кроме главного окна)
hl.window_rule({ 
    match = { 
        class = "^(steam)$", 
        title = "negative:^(Steam)$" 
    }, 
    float = true, 
    center = true 
})

-- Opacity Overrides
local terminals = "^(kitty|ghostty|[Kk]onsole|Alacritty|gnome-terminal|xfce[0-9]?-terminal)$"

-- Float Utility Windows
local floatApps = {
    { class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
    { class = "^(org.pulseaudio.pavucontrol|blueman-manager|nm-applet|nm-connection-editor)$" },
    { title = "^(Winetricks.*|Protontricks.*)$" },
}
for _, m in ipairs(floatApps) do hl.window_rule({ match = m, float = true }) end

-- Float Common Modals
local modalMatches = {
    { title = "^(Open|Authentication Required|Add Folder to Workspace|Choose Files|Save As|Confirm to replace files|File Operation Progress)$" },
    { initial_title = "^(Open File)$" },
    { class = "^([Xx]dg-desktop-portal-gtk)$" },
    { title = "^(File Upload|Choose wallpaper|Library)(.*)$" },
    { class = "^(.*dialog.*)$" },
    { title = "^(.*dialog.*)$" },
    { class = "^(hyprland-share-picker)$"},
}
for _, m in ipairs(modalMatches) do hl.window_rule({ match = m, float = true }) end

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Autostart Apps to Monitor 2
hl.window_rule({ match = { class = "^(discord)$" }, workspace = "6" })
hl.window_rule({ match = { class = "^(org\\.telegram\\.desktop)$" }, workspace = "7" })
hl.window_rule({ match = { class = "^(youtube-music-desktop-app)$" }, workspace = "8" })
hl.window_rule({ match = { class = "^(steam)$" }, workspace = "9" })