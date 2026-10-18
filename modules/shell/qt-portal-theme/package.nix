# Плагин темы Qt «hyprland» = gtk3 (см. plugin.cpp). Подключается вместе со
# своим диалогом выбора файлов: QT_QPA_PLATFORMTHEME=xdgdesktopportal
# и QT_PLUGIN_PATH с этим плагином (modules/system/desktop.nix).
{
  stdenv,
  cmake,
  qt6,
}:
stdenv.mkDerivation {
  pname = "pixel-qt-hyprland-theme";
  version = "1";
  src = ./.;
  nativeBuildInputs = [cmake];
  buildInputs = [qt6.qtbase];
  dontWrapQtApps = true;
  cmakeFlags = ["-DQT6_INSTALL_PLUGINS=lib/qt-6/plugins"];
}
