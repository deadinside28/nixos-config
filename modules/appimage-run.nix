# Пользовательская часть: ассоциация типов и импорт ярлыков в меню.
# Сам враппер теперь ставится системно (см. modules/appimage-system.nix),
# здесь он импортируется только чтобы прописать абсолютный путь в Exec.
{pkgs, ...}: let
  appimageRunWrapper = import ./appimage-wrapper.nix {inherit pkgs;};
in {
  # home.packages враппер больше не содержит — он в environment.systemPackages,
  # иначе в PATH оказались бы два одинаковых appimage-run из разных профилей.

  xdg.desktopEntries.appimage-run = {
    name = "AppImage Runner";
    comment = "Запуск AppImage пакетов в NixOS";
    exec = "${appimageRunWrapper}/bin/appimage-run %F";
    terminal = false;
    icon = "application-x-executable";
    mimeType = [
      "application/vnd.appimage"
      "application/x-iso9660-appimage"
      "application/x-appimage"
    ];
    categories = ["Utility"];
  };

  systemd.user.services.sync-appimage-desktops = {
    Unit = {
      Description = "Sync .desktop and icons from AppImage metadata cache";
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "sync-appimage-desktops" ''
        META_ROOT="$HOME/.cache/appimage-meta"
        APPS_DIR="$HOME/.local/share/applications"

        [ -d "$META_ROOT" ] || exit 0
        mkdir -p "$APPS_DIR"

        for meta in "$META_ROOT"/*/; do
          [ -d "$meta" ] || continue
          [ -f "$meta/app.desktop" ] || continue
          [ -f "$meta/.origin" ] || continue

          orig_appimage="$(cat "$meta/.origin")"
          hash="$(basename "$meta")"
          target="$APPS_DIR/appimage-$hash.desktop"

          # Образ удалили с диска — убираем и ярлык
          if [ ! -f "$orig_appimage" ]; then
            rm -f "$target"
            continue
          fi

          cp "$meta/app.desktop" "$target"
          chmod +w "$target"
          ${pkgs.gnused}/bin/sed -i '/^TryExec=/d' "$target"

          # Абсолютный путь: лаунчер запускает .desktop не из интерактивного
          # шелла, профиля пользователя в его PATH может не быть.
          ${pkgs.gnused}/bin/sed -i -E \
            "s|^Exec=.*|Exec=${appimageRunWrapper}/bin/appimage-run \"$orig_appimage\"|" "$target"

          icon_file="$(ls "$meta"/icon.* 2>/dev/null | head -n 1)"
          if [ -n "$icon_file" ]; then
            ${pkgs.gnused}/bin/sed -i -E "s|^Icon=.*|Icon=$icon_file|" "$target"
          fi

          chmod +x "$target"
        done

        ${pkgs.desktop-file-utils}/bin/update-desktop-database "$APPS_DIR" || true
      '';
    };
  };
}
