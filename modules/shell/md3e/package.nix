# Pixel.MD3E — библиотека Material 3 Expressive на чистом Qt Quick: тема
# и виджеты Pixel Shell для самостоятельных приложений. Подключение —
# QML_IMPORT_PATH=<пакет>/lib/qt-6/qml, затем `import Pixel.MD3E`.
{runCommand}:
runCommand "pixel-md3e" {
  passthru.qmlPath = "lib/qt-6/qml";
  meta.description = "Material 3 Expressive для Qt Quick (тема и виджеты Pixel Shell)";
} ''
  mkdir -p $out/lib/qt-6/qml $out/share/pixel-md3e
  cp -r ${./Pixel} $out/lib/qt-6/qml/Pixel
  cp ${./gallery.qml} $out/share/pixel-md3e/gallery.qml
''
