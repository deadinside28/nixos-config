// Значок приложения из темы иконок с запасным вариантом. Оформление —
// как выбрано в «Обои и стиль → Значки»: обычный, в форме или
// тематический (монохромный в цветах обоев, как на Pixel).
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs.common

Item {
    id: root
    property string icon: ""
    property real size: 40
    // false — всегда как в теме (например, крошечные значки)
    property bool styled: true
    // принудительно для превью в настройках
    property string styleOverride: ""
    property string shapeOverride: ""
    property string colorOverride: ""

    readonly property string look: !root.styled ? "original" : (root.styleOverride || IconStyle.style)
    readonly property string shape: root.shapeOverride || IconStyle.shape
    readonly property string role: root.colorOverride || IconStyle.colorRole
    readonly property bool plated: root.look !== "original"

    implicitWidth: size
    implicitHeight: size

    // Не нашлось в теме — пробуем варианты имени: org.gnome.Nautilus →
    // nautilus, Google-chrome → google-chrome и т.п.
    readonly property string src: {
        if (!icon)
            return "";
        if (icon.startsWith("/") || icon.startsWith("file:") || icon.startsWith("image:"))
            return icon;
        const tail = icon.split(".").pop();
        const names = [icon, icon.toLowerCase(), tail, tail.toLowerCase(), icon.toLowerCase().replace(/[ _]/g, "-")];
        for (const n of names) {
            const p = Quickshell.iconPath(n, true);
            if (p)
                return p;
        }
        return "";
    }

    // Подложка выбранной формы
    Shape {
        id: plate
        visible: root.plated
        width: 100
        height: 100
        scale: root.width / 100
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: IconStyle.bgFor(root.role, root.look)
            strokeWidth: -1
            PathPolyline {
                path: root.plated ? IconStyle.points(root.shape) : []
            }
        }
    }

    IconImage {
        id: img
        anchors.centerIn: parent
        // на подложке значок меньше — как адаптивные значки Android
        implicitSize: root.plated ? root.width * 0.66 : root.width
        source: root.src
        visible: root.src !== "" && status !== Image.Error
        asynchronous: true
        mipmap: true
    }

    // Тематический: от значка остаётся символ в цвете темы (шейдер
    // shaders/themed-icon.frag, собирается Nix). Мип-уровни нужны шейдеру,
    // чтобы понять, есть ли у значка своя подложка.
    ShaderEffectSource {
        id: tex
        sourceItem: root.look === "themed" ? img : null
        hideSource: root.look === "themed"
        mipmap: true
        smooth: true
        textureSize: Qt.size(128, 128)
        visible: false
    }
    ShaderEffect {
        anchors.fill: img
        visible: root.look === "themed" && img.visible
        property var source: tex
        property color tint: IconStyle.fgFor(root.role)
        fragmentShader: Qt.resolvedUrl("../shaders/themed-icon.frag.qsb")
    }

    // Значка нет в теме — буква-заглушка на подложке
    Rectangle {
        anchors.fill: parent
        visible: !img.visible && !root.plated
        radius: width / 2
        color: Theme.primaryContainer
    }
    MIcon {
        anchors.centerIn: parent
        visible: !img.visible
        icon: "apps"
        size: root.size * 0.55
        color: root.plated ? IconStyle.fgFor(root.role) : Theme.fgPrimaryContainer
    }
}
