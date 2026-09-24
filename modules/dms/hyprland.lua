local SUPER = "SUPER"

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    require("dms.autostart")

end)

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("MANGOHUD", "1")

-- QT_QPA_PLATFORMTHEME переехал в environment.sessionVariables:
-- отсюда он доставался только детям Hyprland, а нужен ещё грайтеру,
-- systemd --user и всему, что стартует не из компоновщика.

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

-- default = true означает «этот воркспейс — дефолтный ДЛЯ ЭТОГО МОНИТОРА».
-- Он должен быть ровно один на монитор; когда их пять, кто победит — лотерея.
hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = MONITOR1, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = MONITOR1, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = MONITOR1, persistent = true })
hl.workspace_rule({ workspace = "5", monitor = MONITOR1, persistent = true })
hl.workspace_rule({ workspace = "6", monitor = MONITOR2, default = true, persistent = true })
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


-- ==========================================
-- АНИМАЦИИ: Material 3 Expressive, как на Pixel
-- ==========================================
-- Блок стоит В КОНЦЕ файла намеренно: модули dms.* тоже могут трогать
-- анимации, и выигрывает тот, кто выполнился последним.
--
-- Значения взяты из самого Android: androidx, ExpressiveMotionTokens.kt —
-- это та схема движения, на которой работает Android 16 на Pixel.
-- В Android пружина задаётся коэффициентом демпфирования ζ и жёсткостью k,
-- в Hyprland — физическим демпфированием c при массе 1. Пересчёт:
--   c = 2 · ζ · √k
-- У пружин параметр speed Hyprland не использует: длительность получается
-- из физики, как на телефоне.

-- «Пространственные» пружины — для движения и масштаба (чуть пружинят).
hl.curve("m3FastSpatial",    { type = "spring", mass = 1, stiffness = 800,  dampening = 33.94 }) -- ζ 0.6: заметный отскок ~9%
hl.curve("m3DefaultSpatial", { type = "spring", mass = 1, stiffness = 380,  dampening = 31.19 }) -- ζ 0.8: лёгкий, ~1.5%
hl.curve("m3SlowSpatial",    { type = "spring", mass = 1, stiffness = 200,  dampening = 22.63 }) -- ζ 0.8: для полноэкранного
-- «Эффектные» пружины — для прозрачности и цвета (без отскока).
hl.curve("m3DefaultEffects", { type = "spring", mass = 1, stiffness = 1600, dampening = 80 })
hl.curve("m3FastEffects",    { type = "spring", mass = 1, stiffness = 3800, dampening = 123.29 })
-- Уход с экрана в M3 делается не пружиной, а ускоряющейся кривой:
-- элемент «уезжает», а не «успокаивается».
hl.curve("m3EmphasizedAccel", { type = "bezier", points = { {0.3, 0},  {0.8, 0.15} } })
hl.curve("m3Standard",        { type = "bezier", points = { {0.2, 0},  {0, 1}     } })

hl.animation({ leaf = "global",      enabled = true, speed = 3,   bezier = "m3Standard" })

-- Открытие окна — как запуск приложения на Pixel: вырастает с 85%
-- и мягко доходит до места.
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3,   spring = "m3DefaultSpatial", style = "popin 85%" })
-- Закрытие — быстро «проваливается» внутрь.
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2,   bezier = "m3EmphasizedAccel", style = "popin 85%" })
-- Движение и ресайз, в том числе прокрутка ленты scrolling-layout.
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3,   spring = "m3DefaultSpatial" })

hl.animation({ leaf = "fadeIn",      enabled = true, speed = 2,   spring = "m3DefaultEffects" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 1.5, bezier = "m3EmphasizedAccel" })
hl.animation({ leaf = "fadeSwitch",  enabled = true, speed = 2,   spring = "m3DefaultEffects" })
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 2,   spring = "m3DefaultEffects" })
hl.animation({ leaf = "border",      enabled = true, speed = 2,   spring = "m3FastEffects" })

-- Воркспейсы: M3 «shared axis» по вертикали — страница чуть сдвигается
-- и одновременно проявляется. Это переход между «экранами» в Android.
--
-- Почему по вертикали: у тебя layout = "scrolling", лента окон уходит
-- вправо за край экрана. Горизонтальный сдвиг воркспейса затаскивает
-- окна из-за края в кадр — те самые призраки. Вертикальный сдвиг их
-- не трогает: что было справа за краем, там и остаётся. Заодно
-- направление совпадает с колесом мыши, которым ты листаешь воркспейсы.
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4, spring = "m3SlowSpatial", style = "slidefadevert 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, spring = "m3SlowSpatial", style = "slidefadevert 20%" })
hl.animation({ leaf = "zoomFactor",       enabled = true, speed = 3, spring = "m3DefaultSpatial" })

-- Панели, лаунчер, уведомления и OSD DMS анимирует САМ, своими
-- M3-анимациями. Если Hyprland анимирует их поверх, получается двойная
-- анимация, и она выглядит дёшево. В штатном конфиге DMS эти два правила
-- есть, в твоём их не было.
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^dms:.*" }, no_anim = true })

-- Прочим слоям (slurp, hyprpicker и т.п.) — короткое проявление.
hl.animation({ leaf = "layers",    enabled = true, speed = 2,   spring = "m3DefaultEffects" })
hl.animation({ leaf = "layersIn",  enabled = true, speed = 2,   spring = "m3DefaultEffects", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "m3EmphasizedAccel", style = "fade" })
