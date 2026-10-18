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

printf 'pixel-store: %d проверок пройдено, %d провалено\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
