# Значки приложений Pixel Shell: круг в цвете приложения и глиф Material
# Symbols Rounded (залитый, вес 500). Собираются при сборке (package.nix):
#   python3 make-icons.py <MaterialSymbolsRounded*.ttf> <каталог>
# Имя файла = имя значка в .desktop: pixel-shell-<приложение>.svg
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen

# приложение: (глиф, фон, цвет глифа)
ICONS = {
    "settings": ("settings", "#5f6b7a", "#ffffff"),
    "files": ("folder", "#1a73e8", "#ffffff"),
    "archive": ("folder_zip", "#8e44ad", "#ffffff"),
    "calendar": ("calendar_month", "#1e8e3e", "#ffffff"),
    "notes": ("sticky_note_2", "#f29900", "#ffffff"),
    "store": ("storefront", "#d93025", "#ffffff"),
    "quickshare": ("share", "#12a4b8", "#ffffff"),
    "update": ("system_update_alt", "#5f6b7a", "#ffffff"),
}

font = TTFont(sys.argv[1])
font = instantiateVariableFont(font, {"FILL": 1, "wght": 500, "GRAD": 0, "opsz": 48})
glyphs = font.getGlyphSet()
upm = font["head"].unitsPerEm
size = 192  # холст значка
glyph_size = 108  # глиф внутри круга

for app, (name, bg, fg) in ICONS.items():
    g = glyphs[name]
    # по высоте шрифта: глифы Material Symbols сидят в квадрате [0, upm]
    # по горизонтали (advance) и от descender до ascender по вертикали
    scale = glyph_size / upm
    asc = font["hhea"].ascent
    desc = font["hhea"].descent
    off_x = (size - g.width * scale) / 2
    off_y = (size - (asc - desc) * scale) / 2
    pen = SVGPathPen(glyphs)
    # y шрифта вверх, y SVG вниз
    g.draw(TransformPen(pen, (scale, 0, 0, -scale, off_x, off_y + asc * scale)))
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".14"/><stop offset="1" stop-color="#000" stop-opacity=".10"/></linearGradient></defs>
  <circle cx="96" cy="96" r="88" fill="{bg}"/>
  <circle cx="96" cy="96" r="88" fill="url(#g)"/>
  <path fill="{fg}" d="{pen.getCommands()}"/>
</svg>
'''
    with open(f"{sys.argv[2]}/pixel-shell-{app}.svg", "w") as f:
        f.write(svg)
