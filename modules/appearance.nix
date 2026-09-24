# Всё, что делает вид системы единым, но чего DMS не умеет раздавать сам.
#
# Что DMS умеет и что мы ему НЕ мешаем делать:
#   - цвета. При включённом matugen он пишет ~/.config/gtk-3.0/dank-colors.css,
#     gtk-4.0/dank-colors.css, qt5ct/qt6ct colors/matugen.conf, темы для kitty,
#     vscode, firefox и патчит adw-gtk3. Включается галкой
#     «Применять темы GTK/Qt» в Настройки → Темы и цвета.
#   - иконки. Он дописывает gtk-icon-theme-name в settings.ini и
#     icon_theme в qt6ct.conf.
#   - курсор для Hyprland: пишет hl.env(XCURSOR_*) в свой модуль и дёргает
#     hyprctl setcursor.
#
# Чего DMS не делает вообще: шрифты за пределами собственной оболочки.
# Вкладка «Типография» масштабирует только саму панель. Поэтому шрифт —
# наша забота, и задаётся он здесь один раз для всех потребителей.
{
  pkgs,
  lib,
  appearance,
  ...
}: let
  uiFontSpec = "${appearance.uiFont} ${toString appearance.uiFontSize}";
  monoFontSpec = "${appearance.monoFont} ${toString appearance.monoFontSize}";
in {
  # ВНИМАНИЕ: модуль gtk из home-manager здесь не используется намеренно.
  # Он кладёт ~/.config/gtk-3.0/settings.ini симлинком в /nix/store, файл
  # становится недоступным для записи, а скрипт иконок DMS проверяет ровно
  # это:  [ -f "$f" ] && [ ! -w "$f" ] && continue  — и молча пропускает
  # файл. То есть включённый gtk-модуль home-manager тихо ломает смену
  # иконок из DMS. Поэтому settings.ini остаётся обычным файлом, а мы
  # правим в нём один ключ.

  # GTK4/libadwaita и портал (а значит и Flatpak) читают шрифт отсюда.
  # Иконки, тему и светлый/тёмный режим сознательно не трогаем — это DMS.
  dconf.settings."org/gnome/desktop/interface" = {
    font-name = uiFontSpec;
    document-font-name = uiFontSpec;
    monospace-font-name = monoFontSpec;
    font-antialiasing = "grayscale";
    font-hinting = "slight";
  };

  # GTK3 (и GTK4 без портала) читает шрифт из settings.ini.
  home.activation.gtkFontName = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ -v DRY_RUN ]]; then
      echo "appearance: выставил бы gtk-font-name=${uiFontSpec} в gtk-3.0 и gtk-4.0"
    else
      for dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
        file="$dir/settings.ini"

        if [ -e "$file" ] && [ ! -w "$file" ]; then
          echo "appearance: $file только для чтения, пропускаю (DMS тоже не сможет туда писать)" >&2
          continue
        fi

        ${pkgs.coreutils}/bin/mkdir -p "$dir"
        [ -e "$file" ] || ${pkgs.coreutils}/bin/install -m644 /dev/null "$file"

        if ! ${pkgs.gnugrep}/bin/grep -q '^\[Settings\]' "$file"; then
          ${pkgs.coreutils}/bin/printf '[Settings]\n' | ${pkgs.coreutils}/bin/tee -a "$file" >/dev/null
        fi

        if ${pkgs.gnugrep}/bin/grep -q '^gtk-font-name=' "$file"; then
          ${pkgs.gnused}/bin/sed -i "s|^gtk-font-name=.*|gtk-font-name=${uiFontSpec}|" "$file"
        else
          ${pkgs.gnused}/bin/sed -i "/^\[Settings\]/a gtk-font-name=${uiFontSpec}" "$file"
        fi
      done
    fi
  '';

  # Один курсор на Wayland, XWayland и Flatpak.
  # gtk.enable = false — иначе home-manager утащит settings.ini себе,
  # см. длинный комментарий выше.
  home.pointerCursor = {
    name = appearance.cursorTheme;
    package = pkgs.adwaita-icon-theme;
    size = appearance.cursorSize;
    gtk.enable = false;
    x11.enable = true;
  };
}
