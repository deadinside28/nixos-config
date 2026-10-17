# Всё, что делает вид системы единым.
#
# Шрифты, цвета и значки раздаёт оболочка (modules/shell) — их меняют в
# «Настройки → Обои и стиль», и выбор переживает пересборку:
#   - шрифт: ~/.config/fontconfig/conf.d/61-pixel-shell-fonts.conf (Qt,
#     Chrome, Electron, Flatpak), gsettings + gtk-3.0/4.0 settings.ini (GTK),
#     ~/.config/kitty/pixel-font.conf. Значения appearance во flake.nix —
#     только начальные, пока в настройках ничего не выбрано;
#   - цвета: matugen по обоям → gtk.css, тема kitty, рамки окон Hyprland;
#   - светлая/тёмная тема и значки: gsettings + settings.ini.
#
# Здесь остаётся то, что задаётся из Nix один раз: курсор.
#
# ВНИМАНИЕ: модуль gtk из home-manager здесь не используется намеренно.
# Он кладёт ~/.config/gtk-3.0/settings.ini симлинком в /nix/store, файл
# становится недоступным для записи, и оболочка не смогла бы менять
# в нём шрифт и значки.
{
  pkgs,
  appearance,
  ...
}: {
  # Сглаживание для GTK4/libadwaita и портала (а значит и Flatpak).
  # Сам шрифт сюда не пишем — его ставит оболочка через gsettings.
  dconf.settings."org/gnome/desktop/interface" = {
    font-antialiasing = "grayscale";
    font-hinting = "slight";
  };

  # Один курсор на Wayland, XWayland и Flatpak.
  # gtk.enable = false — иначе home-manager утащит settings.ini себе,
  # см. комментарий выше.
  home.pointerCursor = {
    enable = true;
    name = appearance.cursorTheme;
    package = pkgs.adwaita-icon-theme;
    size = appearance.cursorSize;
    gtk.enable = false;
    x11.enable = true;
  };
}
