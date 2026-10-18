local SUPER = "SUPER"

-- Файлы, которые пишет оболочка (Настройки → …), лежат в hypr/shell/.
-- На первом запуске их ещё нет — тогда просто остаются значения отсюда.
local function shell(name)
    local ok, err = pcall(require, "shell." .. name)
    if not ok and not tostring(err):find("not found") then
        print("hypr/shell/" .. name .. ".lua: " .. tostring(err))
    end
end

hl.on("hyprland.start", function()
    -- Сначала передаём окружение Wayland, затем запускаем службы сессии.
    -- Два независимых exec_cmd могли запустить приложения со старым окружением.
    -- За целью сессии поднимаются оболочка (pixel-shell.service),
    -- cliphist и автозапуск приложений из ~/.config/autostart.
    hl.exec_cmd([[sh -c 'dbus-update-activation-environment --systemd --all && systemctl --user start hyprland-session.target']])
    -- Курсор: тема и размер приходят из сессии (flake.nix → appearance).
    hl.exec_cmd([[sh -c 'hyprctl setcursor "$XCURSOR_THEME" "$XCURSOR_SIZE"']])
end)

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("MANGOHUD", "1")
hl.env("HYPRCURSOR_THEME", os.getenv("XCURSOR_THEME") or "Adwaita")
hl.env("HYPRCURSOR_SIZE", os.getenv("XCURSOR_SIZE") or "24")

-- QT_QPA_PLATFORMTHEME переехал в environment.sessionVariables:
-- отсюда он доставался только детям Hyprland, а нужен ещё грайтеру,
-- systemd --user и всему, что стартует не из компоновщика.

-- Мониторы и воркспейсы этой машины: MONITOR1.., PRIMARY_MONITOR и
-- правила воркспейсов. hypr/host.lua генерируется из hosts/<хост>/host.nix.
require("host")

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle",
    },
    general = {
        layout = "scrolling",
        -- Значения по умолчанию; оболочка перекрывает их из
        -- «Настройки → Рабочий стол и окна» (hypr/shell/look.lua).
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = "rgba(adc6ffff)",
            inactive_border = "rgba(44474faa)",
        },
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
    },
    decoration = {
        rounding = 16,
        rounding_power = 2.4,
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
            offset = "0 4",
        },
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

-- Прозрачность окон (93% по умолчанию, полноэкранные — 100%) задаёт
-- оболочка правилом "shell-opacity" в hypr/shell/look.lua: ползунок в
-- «Настройки → Рабочий стол и окна».

hl.window_rule({
    match = {
        class = "^(com\\.google\\.Chrome|google-chrome|mpv|io\\.mpv\\.Mpv|io\\.github\\.celluloid_player\\.Celluloid)$"
    },
    monitor = PRIMARY_MONITOR,
    no_vrr = true
})

require("binds")
require("windowrules")

-- Настройки из оболочки — после своих, чтобы перекрывать их:
shell("colors")   -- рамки окон в цветах обоев (matugen)
shell("look")     -- отступы, скругления, рамка, размытие, прозрачность
shell("input")    -- раскладки, повтор клавиш, мышь
shell("monitors") -- разрешение, частота, масштаб, расположение
shell("tiling")   -- раскладка окон и поведение фокуса
shell("modes")    -- режимы окон: плавающие, смешанный, свой режим стола
shell("rules")    -- свои правила окон (после режимов — перекрывают их)
shell("binds")    -- свои бинды и отключённые стандартные


-- ==========================================
-- АНИМАЦИИ: Material 3 Expressive, как на Pixel
-- ==========================================
-- Блок стоит В КОНЦЕ файла намеренно: подключённые выше модули тоже могут трогать
-- анимации, и выигрывает тот, кто выполнился последним.
--
-- Сами кривые и анимации генерирует оболочка (shell/animations.lua) из
-- той же таблицы движения, что и у её панелей: одна настройка скорости
-- в «Рабочий стол и окна» меняет и окна Hyprland, и оболочку.
shell("animations")

-- Панели, лаунчер, уведомления и OSD оболочка анимирует САМА, своими
-- M3-анимациями. Если Hyprland анимирует их поверх, получается двойная
-- анимация, и она выглядит дёшево.
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^pixel-shell:.*" }, no_anim = true })
-- Живые обои (mpvpaper, linux-wallpaperengine) появляются без затухания:
-- иначе при смене обоев экран мигает.
hl.layer_rule({ match = { namespace = "^(mpvpaper|linux-wallpaperengine.*|wallpaperengine.*)$" }, no_anim = true })
-- Матовое стекло под панелью задач, лаунчером и быстрыми настройками.
-- ignore_alpha — не размывать полностью прозрачные части поверхностей
-- (оверлеи панелей занимают весь экран, но видна только карточка).
hl.layer_rule({
    -- все слои оболочки; почти прозрачные (затемнение, перехватчик кликов)
    -- ignore_alpha пропускает, непрозрачные (рамка, обои) размывать нечего
    match = { namespace = "^pixel-shell:.*$" },
    blur = true,
    ignore_alpha = 0.4,
})

-- Прочим слоям (slurp, hyprpicker и т.п.) анимация задаётся там же, в shell/animations.lua.
