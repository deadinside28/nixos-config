# pixel-portal — backend xdg-desktop-portal FileChooser (pixel-portal.py).
# Подключается в modules/system/desktop.nix, когда в system.json
# desktop.fileChooser = "pixel".
{
  lib,
  writeTextDir,
  python3,
  makeWrapper,
  runCommand,
  symlinkJoin,
  username,
}: let
  py = python3.withPackages (ps: [ps.dbus-next]);
  bin = runCommand "pixel-portal-bin" {nativeBuildInputs = [makeWrapper];} ''
    mkdir -p $out/bin $out/libexec
    cp ${./pixel-portal.py} $out/libexec/pixel-portal.py
    # Активируется D-Bus-ом вне сессии оболочки: pixel-shell ищем в профиле
    # пользователя (Home Manager) и системы
    makeWrapper ${py}/bin/python3 $out/bin/pixel-portal \
      --add-flags $out/libexec/pixel-portal.py \
      --prefix PATH : /etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin
  '';
in
  symlinkJoin {
    name = "pixel-portal";
    paths = [
      bin
      (writeTextDir "share/xdg-desktop-portal/portals/pixel.portal" ''
        [portal]
        DBusName=org.freedesktop.impl.portal.desktop.pixel
        Interfaces=org.freedesktop.impl.portal.FileChooser
      '')
      (writeTextDir "share/dbus-1/services/org.freedesktop.impl.portal.desktop.pixel.service" ''
        [D-BUS Service]
        Name=org.freedesktop.impl.portal.desktop.pixel
        Exec=${bin}/bin/pixel-portal
      '')
    ];
    meta.mainProgram = "pixel-portal";
  }
