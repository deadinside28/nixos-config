# Значки приложений Pixel Shell (make-icons.py): свои, чтобы «Настройки»,
# «Файлы», «Календарь» и остальные не путались со значками из темы.
{
  runCommand,
  python3,
  material-symbols,
}:
runCommand "pixel-shell-icons" {
  nativeBuildInputs = [(python3.withPackages (ps: [ps.fonttools]))];
} ''
  dir=$out/share/icons/hicolor/scalable/apps
  mkdir -p $dir
  font=$(find ${material-symbols}/share/fonts -name 'MaterialSymbolsRounded*.ttf' | head -n1)
  python3 ${./make-icons.py} "$font" $dir
''
