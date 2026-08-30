local mainMod = "SUPER"

---------------------------
---- WINDOW MANAGEMENT ----
---------------------------

-- Window manipulation
hl.bind(mainMod .. " + Escape",      hl.dsp.exec_cmd("hyprctl kill"))
hl.bind(mainMod .. " + Q",           hl.dsp.window.close())
hl.bind(mainMod .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + D",           hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",           hl.dsp.layout("togglesplit"))

-- Change focus
hl.bind(mainMod .. " + Left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down",  hl.dsp.focus({ direction = "down" }))
hl.bind("ALT + Tab",           hl.dsp.window.cycle_next())

-- Move active window around workspaces & monitors
hl.bind(mainMod .. " + SHIFT + Up",                   hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Right",                hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + Left",                 hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + Down",                 hl.dsp.window.move({ direction = "down" }))

-- Воркспейсы
hl.bind(mainMod .. " + CONTROL + SHIFT + Right",      hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + Left",       hl.dsp.window.move({ workspace = "r-1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_up",   hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + CONTROL + SHIFT + mouse_down", hl.dsp.window.move({ workspace = "r-1" }))

-- Перемещение активного окна на воркспейсы основного монитора (1-4 и Gaming)
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ workspace = 5 }))

-- Перемещение активного окна на воркспейсы второго монитора (5-8 на F1-F4)
hl.bind(mainMod .. " + SHIFT + F1", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + F2", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + F3", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + F4", hl.dsp.window.move({ workspace = 9 }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-------------------
---- UTILITIES ----
-------------------

-- Screen Capture
-- Скриншот выделенной области (Win + Shift + S)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd([[sh -c 'hyprpicker -r -z & PID=$!; sleep 0.1; if grim -g "$(slurp -b 00000099 -c ffffff -w 2 -s 00000000)" /tmp/screen.png && wl-copy < /tmp/screen.png; then notify-send -i /tmp/screen.png "Скриншот" "Область скопирована в буфер обмена"; fi; kill $PID']]))

-- Скриншот всего экрана (Win + Shift + A)
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd([[sh -c 'grim /tmp/screen.png && wl-copy < /tmp/screen.png && notify-send -i /tmp/screen.png "Скриншот" "Весь экран скопирован в буфер обмена"']]))

-- Скриншот активного окна (Win + Shift + D)
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd([[sh -c "grim -g \"\$(hyprctl activewindow | awk '/at:/ {at=\$2} /size:/ {size=\$2} END {sub(\",\", \"x\", size); print at \" \" size}')\" /tmp/screen.png && wl-copy < /tmp/screen.png && notify-send -i /tmp/screen.png 'Скриншот' 'Окно скопировано в буфер обмена'"]]))

-- Запись экрана без микрофона (Alt + F9)
hl.bind("ALT + F9", hl.dsp.exec_cmd([[sh -c 'if pidof gpu-screen-recorder > /dev/null; then killall -SIGINT gpu-screen-recorder; while pidof gpu-screen-recorder > /dev/null; do sleep 0.1; done; FILE=$(ls -t /home/deadinside/Videos/video_*.mp4 | head -n 1); ffmpeg -y -i "$FILE" -vframes 1 /tmp/gsr_thumb.jpg -loglevel error; notify-send -i /tmp/gsr_thumb.jpg "Запись завершена" "Файл сохранен в /home/deadinside/Videos/"; else gpu-screen-recorder -w HDMI-A-1 -f 60 -a default_output -k av1 -o /home/deadinside/Videos/video_$(date +%F_%H-%M-%S).mp4 & notify-send -i camera-video "Запись начата" "БЕЗ микрофона (AV1, 60 FPS)"; fi']]))

-- Запись экрана с микрофоном (Alt + F10)
hl.bind("ALT + F10", hl.dsp.exec_cmd([[sh -c 'if pidof gpu-screen-recorder > /dev/null; then killall -SIGINT gpu-screen-recorder; while pidof gpu-screen-recorder > /dev/null; do sleep 0.1; done; FILE=$(ls -t /home/deadinside/Videos/video_*.mp4 | head -n 1); ffmpeg -y -i "$FILE" -vframes 1 /tmp/gsr_thumb.jpg -loglevel error; notify-send -i /tmp/gsr_thumb.jpg "Запись завершена" "Файл сохранен в /home/deadinside/Videos/"; else gpu-screen-recorder -w HDMI-A-1 -f 60 -a "default_output|default_input" -k av1 -o /home/deadinside/Videos/video_$(date +%F_%H-%M-%S).mp4 & notify-send -i camera-video "Запись начата" "С микрофоном (AV1, 60 FPS)"; fi']]))

------------------
---- LAUNCHER ----
------------------

-- Application Launchers
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd("dms ipc call dankdash wallpaper"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exec_cmd("dms ipc call powermenu toggle"))

-- Security
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))

-- Audio Controls
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 2%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 2%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- Brightness Controls
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call spotlight toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call spotlight toggle"), { locked = true, repeating = true })

-- Запуск приложений
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("google-chrome-stable"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))

-------------------------------
---- WORKSPACES & MONITORS ----
-------------------------------

-- Переключение воркспейсов на основном мониторе (1-4)
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + G", hl.dsp.focus({ workspace = 5 }))

-- Переключение воркспейсов на втором мониторе (5-8 на F1-F4)
hl.bind(mainMod .. " + F1", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + F2", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + F3", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + F4", hl.dsp.focus({ workspace = 9 }))

-- Move to adjacent workspaces and next empty on a given monitor
hl.bind(mainMod .. " + CONTROL + Right",       hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + Left",        hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + Down",        hl.dsp.focus({ workspace = "emptym" }))

-- Scroll through existing workspaces & monitors
hl.bind(mainMod .. " + mouse_down",           hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_up",             hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + CONTROL + mouse_up",   hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + CONTROL + mouse_down", hl.dsp.focus({ workspace = "m-1" }))

