# Проверка загрузки оболочки: настоящий Quickshell под headless sway, все
# окна и страницы настроек открываются через IPC. Падает, если в журнале
# есть ошибки QML (ReferenceError, TypeError, неизвестные свойства и т. п.).
#   bash load-test.sh <quickshell> <sway> <каталог конфигурации pixel> <путь QML к Pixel.MD3E>
# Окружения нет (Hyprland, D-Bus, PipeWire) — эти предупреждения не в счёт.
set -u
qs=$1 sway=$2 cfg=$3/shell.qml
export QML_IMPORT_PATH=$4
work=$(mktemp -d)
export HOME="$work/home" XDG_RUNTIME_DIR="$work/run" LANG=C.UTF-8
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
printf 'output HEADLESS-1 resolution 1920x1080\n' >"$work/sway.conf"

"$sway" -c "$work/sway.conf" >"$work/sway.log" 2>&1 &
swaypid=$!
for _ in $(seq 1 100); do ls "$XDG_RUNTIME_DIR"/wayland-? >/dev/null 2>&1 && break; sleep 0.1; done
WAYLAND_DISPLAY=$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-? | head -n 1)")
export WAYLAND_DISPLAY

QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software "$qs" -p "$cfg" >"$work/qs.log" 2>&1 &
qspid=$!
for _ in $(seq 1 100); do grep -q "Configuration Loaded\|Failed to load" "$work/qs.log" && break; sleep 0.2; done

call() { "$qs" ipc -p "$cfg" call "$@" >>"$work/ipc.log" 2>&1; sleep 0.7; }
for p in network bluetooth quickshare display sound style desktop quicksettings notifications apps storage menu windows input power system about; do
    call settings open "$p"
done
call store open
call notes open
call calendar open
call files open /
call launcher toggle
call quicksettings toggle
call overview toggle
call filechooser request '{"id":"t","reply":"'"$work"'/r.json","kind":"open","title":"Тест","acceptLabel":"","multiple":true,"directory":false,"filters":[{"name":"Текст","patterns":[{"mime":false,"pattern":"*.txt"}]}],"currentFilter":"","choices":[{"id":"c","label":"Флаг","options":[],"selected":"false"}],"currentName":"","currentFolder":"/","currentFile":"","files":[]}'
call filechooser cancel t
call quickshare send /etc/hostname
call files properties /etc
call files properties /etc/hostname
call store app org.example.Missing
call store search firefox
sleep 2
kill "$qspid" 2>/dev/null
kill "$swaypid" 2>/dev/null
wait 2>/dev/null

log=$(sed 's/\x1b\[[0-9;]*m//g' "$work/qs.log")
fail=0
if ! grep -q "Configuration Loaded" <<<"$log"; then
    echo "FAIL: конфигурация не загрузилась" >&2
    tail -n 20 "$work/sway.log" "$work/qs.log" >&2
    fail=1
fi
errors=$(grep -E "ReferenceError|TypeError|SyntaxError|is not a type|Cannot assign|Unable to assign|non-existent|not defined|Failed to load|ERROR scene|WARN scene: @" <<<"$log" | grep -v "FileView" || true)
if [ -n "$errors" ]; then
    echo "FAIL: ошибки QML:" >&2
    printf '%s\n' "$errors" >&2
    fail=1
fi
if [ ! -s "$work/r.json" ] || ! grep -q '"response":2' "$work/r.json"; then
    echo "FAIL: отмена запроса диалога файлов не записала ответ" >&2
    fail=1
fi
[ "$fail" -eq 0 ] && echo "shell-load: оболочка и все окна загрузились без ошибок QML"
rm -rf "$work"
exit "$fail"
