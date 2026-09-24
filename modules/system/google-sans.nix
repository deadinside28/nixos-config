# Google Sans — системный шрифт Pixel. С конца 2025 года он открыт
# под лицензией OFL и лежит в репозитории google/fonts.
#
# Почему не Google Sans Flex, хотя на свежих Pixel стоит именно он:
# во Flex нет кириллицы вообще (проверено по таблице символов шрифта),
# и весь русский интерфейс рисовался бы запасным шрифтом. Обычный
# Google Sans кириллицу покрывает полностью, а на Pixel русский текст
# и так показывается им.
#
# Шрифт переменный (ось веса 400–700) с именованными начертаниями
# Regular / Medium / Bold — их и выбирает GTK по строке вида
# «Google Sans Medium 12».
#
# В пакете nixpkgs google-fonts его пока нет (снимок старше), поэтому
# файлы берутся напрямую из google/fonts по зафиксированному коммиту.
{pkgs, ...}: let
  rev = "23e54b51ddffbc7713c583748e3bd86f62b1fa4a";
  base = "https://raw.githubusercontent.com/google/fonts/${rev}/ofl/googlesans";

  google-sans = pkgs.stdenvNoCC.mkDerivation {
    pname = "google-sans";
    version = "0-unstable-2026-09-24";

    # В именах файлов квадратные скобки и запятые — в URL они экранированы,
    # а в имени в /nix/store недопустимы, поэтому name задан явно.
    srcs = [
      (pkgs.fetchurl {
        name = "GoogleSans.ttf";
        url = "${base}/GoogleSans%5BGRAD%2Copsz%2Cwght%5D.ttf";
        hash = "sha256-0Kh9g1qUS4tA0OgqVlG7WauXuTairu1ZRutX57KjqQo=";
      })
      (pkgs.fetchurl {
        name = "GoogleSans-Italic.ttf";
        url = "${base}/GoogleSans-Italic%5BGRAD%2Copsz%2Cwght%5D.ttf";
        hash = "sha256-tmYqvSExytGySHUBSafytkT4cevMmvf+TNETXNKQttE=";
      })
    ];

    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      for f in $srcs; do
        install -Dm444 "$f" "$out/share/fonts/truetype/$(stripHash "$f")"
      done
      runHook postInstall
    '';

    meta = {
      description = "Google Sans — системный шрифт Pixel";
      homepage = "https://github.com/google/fonts/tree/main/ofl/googlesans";
      license = pkgs.lib.licenses.ofl;
    };
  };
in {
  fonts.packages = [google-sans];
}
