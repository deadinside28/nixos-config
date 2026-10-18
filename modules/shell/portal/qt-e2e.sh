# Сквозная проверка своего диалога выбора файлов для Qt-приложений:
# QML FileDialog с темой xdgdesktopportal (+ плагин «hyprland» = gtk3) →
# настоящий xdg-desktop-portal (FileChooser=pixel;gtk) → pixel-portal →
# заглушка оболочки, которая «выбирает» файл → путь возвращается в
# приложение. Всё — под headless sway и своей сессией D-Bus.
#   bash qt-e2e.sh <sway> <xdg-desktop-portal> <pixel-portal> <qml> <QT_PLUGIN_PATH> <QML_IMPORT_PATH> <XDG_DATA_DIRS> <тема-плагин>
set -u
sway=$1 xdp=$2 portal=$3 qml=$4 qtplugins=$5 qmlimports=$6 datadirs=$7 themeplugin=$8
E=$(mktemp -d)
export XDG_RUNTIME_DIR=$E/run HOME=$E/home XDG_CONFIG_HOME=$E/config LANG=C.UTF-8 XDG_CURRENT_DESKTOP=Hyprland
mkdir -p "$XDG_RUNTIME_DIR" "$HOME" "$XDG_CONFIG_HOME/xdg-desktop-portal" && chmod 700 "$XDG_RUNTIME_DIR"
printf '[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.FileChooser=pixel;gtk\n' >"$XDG_CONFIG_HOME/xdg-desktop-portal/hyprland-portals.conf"
export XDG_DATA_DIRS="$portal/share:$datadirs"
echo hi >"$E/выбранный файл.txt"

cat >"$E/fake-shell" <<FAKE
#!$(command -v python3)
import json, sys, os
if sys.argv[1:3] == ["filechooser", "request"]:
    req = json.loads(sys.argv[3])
    open("$E/request.json", "w").write(sys.argv[3])
    tmp = req["reply"] + ".tmp"
    open(tmp, "w").write(json.dumps({"response": 0, "paths": ["$E/выбранный файл.txt"]}))
    os.rename(tmp, req["reply"])
FAKE
chmod +x "$E/fake-shell"

cat >"$E/app.qml" <<'QML'
import QtQuick
import QtQuick.Dialogs
Window {
    visible: true
    width: 200; height: 100
    FileDialog {
        id: fd
        title: "Тест"
        nameFilters: ["Текст (*.txt)"]
        onAccepted: { console.log("SELECTED", selectedFile); Qt.quit() }
        onRejected: { console.log("REJECTED"); Qt.quit() }
    }
    Timer { interval: 2500; running: true; onTriggered: fd.open() }
}
QML

printf 'output HEADLESS-1 resolution 1280x720\n' >"$E/sway.conf"
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman "$sway" -c "$E/sway.conf" >"$E/sway.log" 2>&1 &
for _ in $(seq 1 100); do ls "$XDG_RUNTIME_DIR"/wayland-? >/dev/null 2>&1 && break; sleep 0.1; done
WAYLAND_DISPLAY=$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-? | head -n 1)")
export WAYLAND_DISPLAY
PIXEL_SHELL=$E/fake-shell "$portal/bin/pixel-portal" >"$E/portal.log" 2>&1 &
"$xdp" >"$E/xdp.log" 2>&1 &
sleep 2

QT_PLUGIN_PATH="$themeplugin:$qtplugins" QML_IMPORT_PATH=$qmlimports QT_FORCE_STDERR_LOGGING=1 \
    QT_QUICK_BACKEND=software QT_QPA_PLATFORM=wayland QT_QPA_PLATFORMTHEME=xdgdesktopportal \
    timeout 30 "$qml" "$E/app.qml" >"$E/app.log" 2>&1
kill %1 %2 %3 2>/dev/null

if grep -q "SELECTED file://$E/выбранный файл.txt" "$E/app.log" && [ -s "$E/request.json" ]; then
    echo "qt-e2e: Qt-приложение получило файл из своего диалога через портал"
    rm -rf "$E"
    exit 0
fi
echo "FAIL: файл не вернулся в приложение" >&2
tail -n 20 "$E/app.log" "$E/portal.log" >&2
grep -i "pixel\|error" "$E/xdp.log" | tail -n 10 >&2
exit 1
