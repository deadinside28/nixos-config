# Сквозная проверка патчей Wine: GetOpenFileNameW и GetSaveFileNameW из
# Windows-программы (dialogs.c) → портал FileChooser → настоящий
# xdg-desktop-portal → pixel-portal → заглушка оболочки «выбирает» файл →
# путь возвращается в программу. Своя сессия D-Bus, без экрана.
#   dbus-run-session -- bash e2e.sh <wine> <xdg-desktop-portal> <pixel-portal> <dialogs.exe>
# <wine> — bin/wine из modules/system/wine-portal.nix: обёртка сама включает
# HostFileChooser в новом префиксе, тест это и проверяет.
set -u
wine=$1 xdp=$2 portal=$3 exe=$4
E=$(mktemp -d)
export HOME=$E/home XDG_RUNTIME_DIR=$E/run XDG_CONFIG_HOME=$E/config LANG=C.UTF-8 XDG_CURRENT_DESKTOP=Hyprland
export WINEPREFIX=$E/prefix WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml="
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME/xdg-desktop-portal" && chmod 700 "$XDG_RUNTIME_DIR"
printf '[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.FileChooser=pixel\n' >"$XDG_CONFIG_HOME/xdg-desktop-portal/hyprland-portals.conf"
export XDG_DATA_DIRS="$portal/share:${XDG_DATA_DIRS:-}"
mkdir -p "$E/файлы"
echo hi >"$E/файлы/выбранный файл.txt"

# Заглушка оболочки: открыть — существующий файл, сохранить — новое имя
cat >"$E/fake-shell" <<FAKE
#!$(command -v python3)
import json, sys, os
if sys.argv[1:3] == ["filechooser", "request"]:
    req = json.loads(sys.argv[3])
    with open("$E/requests.log", "a") as f:
        f.write(sys.argv[3] + "\n")
    path = "$E/файлы/выбранный файл.txt" if req["kind"] == "open" else "$E/файлы/сохранено " + req["currentName"]
    tmp = req["reply"] + ".tmp"
    open(tmp, "w").write(json.dumps({"response": 0, "paths": [path]}))
    os.rename(tmp, req["reply"])
FAKE
chmod +x "$E/fake-shell"

PIXEL_SHELL=$E/fake-shell "$portal/bin/pixel-portal" >"$E/portal.log" 2>&1 &
"$xdp" >"$E/xdp.log" 2>&1 &
sleep 2

timeout 300 "$wine" wineboot -i >"$E/wineboot.log" 2>&1
timeout 120 "$wine" "$exe" >"$E/app.log" 2>&1
timeout 30 "$(dirname "$wine")/wineserver" -k 2>/dev/null
kill %1 %2 2>/dev/null

res=$WINEPREFIX/drive_c/pixel-result.txt
cat "$res" 2>/dev/null
ok=1
grep -q '^open 1 .*выбранный файл\.txt$' "$res" 2>/dev/null || ok=0
grep -q '^save 1 .*сохранено отчёт\.txt$' "$res" 2>/dev/null || ok=0
[ "$(grep -c '"kind"' "$E/requests.log" 2>/dev/null)" = 2 ] || ok=0
if [ "$ok" = 1 ]; then
    echo "wine-e2e: открыть и сохранить прошли через портал"
    rm -rf "$E"
    exit 0
fi
echo "FAIL: диалоги Wine не дошли до портала ($E)" >&2
tail -n 20 "$E/app.log" "$E/portal.log" >&2
cat "$E/requests.log" >&2 2>/dev/null
exit 1
