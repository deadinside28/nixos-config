# Системная часть поддержки AppImage: враппер в PATH + binfmt.
# Подключается в flake.nix в список modules (НЕ в home.nix).
{pkgs, ...}: let
  appimageRunWrapper = import ./appimage-wrapper.nix {inherit pkgs;};
in {
  environment.systemPackages = [
    appimageRunWrapper
    pkgs.desktop-file-utils # desktop-file-validate, update-desktop-database
  ];

  # Ядро узнаёт AppImage по магическим байтам (ELF + сигнатура "AI" + тип 02)
  # и само подставляет интерпретатор. Благодаря этому работает и даблклик
  # по исполняемому файлу, и ./file.AppImage из терминала.
  #
  # Интерпретатор — наш враппер, а не голый appimage-run: иначе прямой
  # запуск шёл бы мимо FHS-контейнера, и образы вроде shadPS4,
  # которые живут только в нём, снова падали бы молча.
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${appimageRunWrapper}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };

  # Запасная регистрация по расширению — на случай образов, чей
  # ELF-заголовок не совпадает с сигнатурой выше (встречается
  # у сборок на uruntime). Если такие не попадаются, блок можно убрать.
  boot.binfmt.registrations.appimage-ext = {
    wrapInterpreterInShell = false;
    interpreter = "${appimageRunWrapper}/bin/appimage-run";
    recognitionType = "extension";
    magicOrExtension = "AppImage";
  };
}
