# Проверка pixel-store: индекс строится из того же входа flake и не
# перестраивается без смены ревизии; поиск ранжирует точное имя выше.
#   bash modules/shell/store-test.sh modules/shell/store.sh
# nix и flatpak подменяются заглушками в PATH.
set -u

script=$(realpath "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash=$(command -v bash)
export HOME="$work/home" XDG_CACHE_HOME="$work/cache"
mkdir -p "$HOME" "$work/bin"

cat >"$work/bin/nix" <<EOF
#!$bash
echo "\$*" >>"$work/nix.log"
case "\$1" in
    eval) printf '{"description":"Web browser","homepage":"https://x","license":"MPL-2.0"}' ;;
    flake) printf '{"locks":{"nodes":{"nixpkgs":{"locked":{"rev":"%s"}}}}}' "\${REV:-r1}" ;;
    search)
        [ -n "\${SEARCH_FAIL:-}" ] && exit 1
        printf '%s' '{"legacyPackages.x86_64-linux.firefox":{"version":"140","description":"Web\tbrowser"},"legacyPackages.x86_64-linux.firefox-esr":{"version":"128","description":"ESR"},"legacyPackages.x86_64-linux.python3Packages.firefox-tools":{"version":"1","description":"tools"},"legacyPackages.x86_64-linux.librewolf":{"version":"1","description":"Fork of Firefox"}}' ;;
esac
EOF
cat >"$work/bin/flatpak" <<EOF
#!$bash
case "\$1" in
    search) printf 'org.mozilla.firefox\t140\tFast browser\tFirefox\tflathub\n' ;;
    list) printf 'org.mozilla.firefox\n' ;;
esac
EOF
cat >"$work/bin/curl" <<EOF
#!$bash
echo "\$*" >>"$work/curl.log"
[ -n "\${CURL_FAIL:-}" ] && exit 7
case "\$*" in
    *popular*) printf '{"hits":[{"app_id":"org.gnome.Calculator"},{"app_id":"com.example.Plain"}]}' ;;
    *) printf '{"hits":[]}' ;;
esac
EOF
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH"

passed=0 failures=0
check() {
    if eval "$2"; then passed=$((passed + 1)); else
        failures=$((failures + 1))
        printf 'FAIL: %s [%s]\n' "$1" "$2" >&2
    fi
}
run() { out=$(bash -euo pipefail "$script" "$@" 2>"$work/err"); rc=$?; }
tsv="$XDG_CACHE_HOME/pixel-shell/store/nixpkgs.tsv"

run index /flake nixpkgs
check "индекс построен" '[ $rc -eq 0 ] && [[ $out == *"done	4"* ]] && [ "$(head -n 1 "$tsv")" = "#rev r1" ]'
check "поиск идёт во входах flake, не в реестре" 'grep -q -- "--inputs-from /flake nixpkgs" "$work/nix.log"'
check "табуляция в описании не ломает строки" '[ "$(grep -c . "$tsv")" -eq 5 ]'

: >"$work/nix.log"
run index /flake nixpkgs
check "та же ревизия — без пересборки" '[[ $out == *cached* ]] && ! grep -q search "$work/nix.log"'

REV=r2 SEARCH_FAIL=1 run index /flake nixpkgs
check "сбой — старый индекс остаётся" '[[ $out == *failed* ]] && [ "$(head -n 1 "$tsv")" = "#rev r1" ]'

run index /flake nope
check "неизвестный вход — сообщение" '[[ $(cat "$work/err") == *"nope"* ]]'

run search Firefox
first=$(printf '%s\n' "$out" | head -n 1 | cut -f2)
check "точное имя первым" '[ "$first" = firefox ]'
check "вложенный атрибут и описание тоже находятся" '[[ $out == *python3Packages.firefox-tools* && $out == *librewolf* ]]'
check "строка индекса с ревизией не попадает" '! printf "%s\n" "$out" | grep -q "^nixpkgs	#rev"'

run search ""
check "пустой запрос — пусто" '[ $rc -eq 0 ] && [ -z "$out" ]'

run flatpak-search firefox
check "Flatpak: поля в нужном порядке" '[ "$out" = "flatpak	org.mozilla.firefox	140	Fast browser	Firefox	flathub" ]'

# --- catalog / featured / nix-info -----------------------------------------
as="$work/appstream/flathub/x86_64/active"
mkdir -p "$as/icons/128x128"
touch "$as/icons/128x128/org.gnome.Calculator.png"
cat >"$as/appstream.xml" <<'XML'
<components version="0.8" origin="flathub">
  <component type="desktop-application">
    <id>org.gnome.Calculator.desktop</id>
    <name>Calculator</name><name xml:lang="ru">Калькулятор</name>
    <summary>Arithmetic</summary><summary xml:lang="ru">Вычисления</summary>
    <description><p>Solves.</p><p xml:lang="ru">Решает.</p><ul><li>Basic</li><li xml:lang="ru">Обычный</li></ul></description>
    <icon type="cached" width="128" height="128">org.gnome.Calculator.png</icon>
    <categories><category>Utility</category></categories>
    <screenshots><screenshot type="default"><image type="source">https://x/full.png</image><image type="thumbnail" width="752">https://x/752.png</image></screenshot></screenshots>
    <releases><release version="46" timestamp="100"/><release version="47" timestamp="200"/></releases>
    <custom><value key="flathub::verification::verified">true</value></custom>
  </component>
  <component type="runtime"><id>org.gnome.Platform</id><name>GNOME</name></component>
  <component type="desktop-application">
    <id>com.example.Plain</id><name>Plain</name><summary>Plain app</summary>
    <description xml:lang="ru"><p>Отдельно.</p></description><description><p>Separate.</p></description>
  </component>
</components>
XML
export PIXEL_APPSTREAM_DIRS="$as" PIXEL_APPSTREAM_PY="$(dirname "$script")/store-appstream.py"
run catalog
cat_json=$(printf '%s' "$out" | cut -f2)
check "каталог: два приложения, без среды выполнения" '[[ $out == catalog*2 ]] && [ "$(jq -r ".apps | map(.id) | join(\",\")" "$cat_json")" = "org.gnome.Calculator,com.example.Plain" ]'
check "каталог: русские название и описание, версия, проверено" '[ "$(jq -r ".apps[0] | [.name, .summary, .description, .version, .verified] | @tsv" "$cat_json")" = "$(printf "Калькулятор\tВычисления\tРешает.\\\\n\\\\n• Обычный\t47\ttrue")" ]'
check "каталог: абсолютный путь к значку" '[[ $(jq -r ".apps[0].icon" "$cat_json") == /*128x128/org.gnome.Calculator.png ]]'
check "каталог: отдельный русский description, скриншот" '[ "$(jq -r ".apps[1].description" "$cat_json")" = "Отдельно." ] && [ "$(jq -r ".apps[0].screenshots[0].thumb" "$cat_json")" = "https://x/752.png" ]'
before=$(stat -c %Y "$cat_json")
sleep 1
run catalog
check "AppStream не менялся — каталог не пересобирается" '[ "$(stat -c %Y "$cat_json")" = "$before" ] && [[ $out == catalog*2 ]]'
touch "$as/appstream.xml"
run catalog
check "AppStream обновился — пересборка" '[ "$(stat -c %Y "$cat_json")" != "$before" ]'
mkdir -p "$work/empty"
PIXEL_APPSTREAM_DIRS="" HOME="$work/empty" run catalog
check "нет Flathub — пустой каталог и сообщение" '[ $rc -eq 0 ] && [ "$out" = "$(printf "catalog\t\t0")" ]'

run featured
fj=$(printf '%s' "$out" | cut -f2)
check "подборки: популярное с Flathub" '[ "$(jq -r ".popular | join(\",\")" "$fj")" = "org.gnome.Calculator,com.example.Plain" ] && [ "$(jq -r ".\"recently-updated\" | length" "$fj")" = 0 ]'
: >"$work/curl.log"
run featured
check "подборки кешируются на сутки" '[ ! -s "$work/curl.log" ]'
touch -d "2 days ago" "$fj"
CURL_FAIL=1 run featured
check "нет сети — остаются прошлые подборки" '[ "$(jq -r ".popular | length" "$fj")" = 2 ]'

run nix-info /flake nixpkgs firefox
check "описание пакета Nix" '[ "$(printf "%s" "$out" | jq -r .license)" = "MPL-2.0" ] && grep -q "eval --json --inputs-from /flake nixpkgs#legacyPackages.x86_64-linux.firefox" "$work/nix.log"'

printf 'pixel-store: %d проверок пройдено, %d провалено\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
