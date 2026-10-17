pragma Singleton

// Шрифты всей системы из «Настройки → Обои и стиль → Шрифт».
//
//   fontconfig (~/.config/fontconfig/conf.d/61-pixel-shell-fonts.conf) —
//     sans-serif/monospace и начертание «обычного» текста: это Qt, Chrome,
//     Electron, Flatpak (каталог проброшен в песочницы) и сама оболочка;
//   GTK3/GTK4 и libadwaita — gsettings + settings.ini;
//   kitty — ~/.config/kitty/pixel-font.conf.
// Уже открытые приложения подхватят шрифт после перезапуска.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root

    property var families: []
    readonly property var weights: [
        {
            value: "Regular",
            label: "Обычный"
        },
        {
            value: "Medium",
            label: "Средний"
        },
        {
            value: "Bold",
            label: "Жирный"
        }
    ]

    function refresh() {
        list.running = true;
    }
    Process {
        id: list
        command: ["sh", "-c", "fc-list : family | cut -d, -f1 | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.families = text.split("\n").filter(f => f && !f.startsWith("."))
        }
    }

    function xml(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;");
    }
    function rule(family, style) {
        const f = xml(family);
        const w = style.toLowerCase();
        return `  <match target="pattern">
    <test name="family" qual="first"><string>${f}</string></test>
    <test name="weight" compare="eq"><const>regular</const></test>
    <edit name="weight" mode="assign" binding="strong"><const>${w}</const></edit>
  </match>
  <match target="pattern">
    <test name="family" qual="first"><string>${f}</string></test>
    <test name="style" compare="eq"><string>Regular</string></test>
    <edit name="style" mode="assign" binding="strong"><string>${xml(style)}</string></edit>
  </match>`;
    }

    readonly property string fontconfig: {
        const d = Settings.data;
        return `<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Сгенерировано оболочкой: Настройки → Обои и стиль → Шрифт. -->
<fontconfig>
  <alias binding="strong">
    <family>sans-serif</family>
    <prefer><family>${xml(d.uiFont)}</family></prefer>
  </alias>
  <alias binding="strong">
    <family>monospace</family>
    <prefer><family>${xml(d.monoFont)}</family></prefer>
  </alias>
${rule(d.uiFont, d.uiFontWeight)}
${d.monoFont !== d.uiFont ? rule(d.monoFont, d.monoFontWeight) : ""}
</fontconfig>
`;
    }
    readonly property string gtkFont: `${Settings.data.uiFont} ${Settings.data.uiFontWeight === "Regular" ? "" : Settings.data.uiFontWeight + " "}${Settings.data.uiFontSize}`
    readonly property string gtkMono: `${Settings.data.monoFont} ${Settings.data.monoFontWeight === "Regular" ? "" : Settings.data.monoFontWeight + " "}${Settings.data.monoFontSize}`

    onFontconfigChanged: if (Settings.loaded)
        apply.restart()
    onGtkFontChanged: if (Settings.loaded)
        apply.restart()
    onGtkMonoChanged: if (Settings.loaded)
        apply.restart()
    Connections {
        target: Settings
        function onLoadedChanged() {
            if (Settings.loaded)
                apply.restart();
        }
    }

    FileView {
        id: fcFile
        path: Settings.configDir + "/fontconfig/conf.d/61-pixel-shell-fonts.conf"
        printErrors: false
        atomicWrites: true
    }
    FileView {
        id: kittyFile
        path: Settings.configDir + "/kitty/pixel-font.conf"
        printErrors: false
        atomicWrites: true
    }

    Timer {
        id: apply
        interval: 400
        onTriggered: {
            Quickshell.execDetached(["mkdir", "-p", Settings.configDir + "/fontconfig/conf.d", Settings.configDir + "/kitty"]);
            fcFile.setText(root.fontconfig);
            kittyFile.setText(`# Сгенерировано оболочкой: Настройки → Обои и стиль → Шрифт.\nfont_family ${Settings.data.monoFont}\n`);
            Quickshell.execDetached(["sh", "-c", `
                gsettings set org.gnome.desktop.interface font-name "$1"
                gsettings set org.gnome.desktop.interface document-font-name "$1"
                gsettings set org.gnome.desktop.interface monospace-font-name "$2"
                for f in "${Settings.configDir}/gtk-3.0/settings.ini" "${Settings.configDir}/gtk-4.0/settings.ini"; do
                    mkdir -p "$(dirname "$f")"
                    [ -e "$f" ] || printf '[Settings]\\n' > "$f"
                    [ -w "$f" ] || continue
                    grep -q '^\\[Settings\\]' "$f" || printf '[Settings]\\n' >> "$f"
                    if grep -q '^gtk-font-name=' "$f"; then
                        sed -i "s|^gtk-font-name=.*|gtk-font-name=$1|" "$f"
                    else
                        sed -i "/^\\[Settings\\]/a gtk-font-name=$1" "$f"
                    fi
                done
                fc-cache -f >/dev/null 2>&1 &
                pkill -USR1 -x kitty || true
            `, "sh", root.gtkFont, root.gtkMono]);
        }
    }

    Component.onCompleted: refresh()
}
