# pixel-store — каталог магазина: индекс пакетов Nix и поиск по нему,
# поиск Flatpak, список установленных Flatpak и их обновлений.
#
# Собирается в writeShellApplication (bash, errexit, nounset, pipefail).
# Проверка: modules/shell/store-test.sh (nix flake check).
#
# Пакеты Nix ищутся не в реестре, а в тех же ревизиях, из которых
# собирается система: `nix search --inputs-from <flake> <вход>`. Найденное
# в каталоге — ровно то, что установится, без смены flake.lock.
# Вычислять весь nixpkgs на каждый запрос дорого, поэтому один раз строится
# индекс (TSV в кеше), и он перестраивается, только когда ревизия входа
# поменялась.
#
#   index FLAKE ВХОД…     — построить/обновить индексы (nixpkgs, chaotic)
#   search ЗАПРОС         — поиск по индексам: «вход<TAB>атрибут<TAB>версия<TAB>описание»
#   flatpak-search ЗАПРОС — «flatpak<TAB>id<TAB>версия<TAB>описание<TAB>название<TAB>remote»
#   flatpak-installed     — id установленных приложений Flatpak
#   flatpak-updates       — id приложений Flatpak с доступным обновлением

fail() { printf '%s\n' "$*" >&2; }

dir="${XDG_CACHE_HOME:-$HOME/.cache}/pixel-shell/store"

index() {
    local flake=$1 input rev tsv old
    shift
    mkdir -p "$dir"
    for input in "$@"; do
        tsv="$dir/$input.tsv"
        rev=$(nix flake metadata --json -- "$flake" 2>/dev/null |
            jq -r --arg i "$input" '.locks.nodes[$i].locked | .rev // .narHash // empty' || true)
        if [ -z "$rev" ]; then
            fail "Вход «$input» не найден во flake.lock"
            continue
        fi
        old=$(head -n 1 "$tsv" 2>/dev/null || true)
        if [ "$old" = "#rev $rev" ]; then
            printf 'index\t%s\tcached\n' "$input"
            continue
        fi
        printf 'index\t%s\tbuilding\n' "$input"
        # атрибут без «legacyPackages.<система>.» / «packages.<система>.»
        if nice -n 10 nix search --quiet --json --inputs-from "$flake" "$input" '^' 2>/dev/null |
            jq -r 'to_entries[] | [(.key | split(".") | .[2:] | join(".")), .value.version, (.value.description // "" | gsub("[\t\n]"; " "))] | @tsv' \
                >"$tsv.tmp" && [ -s "$tsv.tmp" ]; then
            { printf '#rev %s\n' "$rev"; cat "$tsv.tmp"; } >"$tsv.new"
            mv -f "$tsv.new" "$tsv"
            rm -f "$tsv.tmp"
            printf 'index\t%s\tdone\t%s\n' "$input" "$(($(wc -l <"$tsv") - 1))"
        else
            rm -f "$tsv.tmp"
            fail "Не удалось построить каталог «$input»"
            printf 'index\t%s\tfailed\n' "$input"
        fi
    done
}

# Ранжирование: точное имя > начало имени > имя содержит > описание
search() {
    local q f
    q=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    [ -n "$q" ] || return 0
    for f in "$dir"/*.tsv; do
        [ -e "$f" ] || continue
        grep -i -F -- "$q" "$f" | awk -F '\t' -v q="$q" -v src="$(basename "$f" .tsv)" '
            /^#rev / { next }
            {
                a = tolower($1); n = a; sub(/.*\./, "", n)
                if (n == q || a == q) r = 0
                else if (index(n, q) == 1) r = 1
                else if (index(a, q)) r = 2
                else r = 3
                printf "%d\t%05d\t%s\t%s\t%s\t%s\n", r, length($1), src, $1, $2, $3
            }' || true
    done | sort -t "$(printf '\t')" -k1,1n -k2,2n | awk 'NR <= 60' | cut -f3-
}

flatpak_search() {
    flatpak search --columns=application,version,description,name,remotes -- "$1" 2>/dev/null |
        awk -F '\t' 'NF >= 3 { printf "flatpak\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5 }' | awk 'NR <= 40' || true
}

cmd=${1:-}
[ "$#" -eq 0 ] || shift
case "$cmd" in
    index) index "$@" ;;
    search) search "${1:-}" ;;
    flatpak-search) flatpak_search "${1:-}" ;;
    flatpak-installed) flatpak list --app --columns=application 2>/dev/null || true ;;
    flatpak-updates) flatpak remote-ls --updates --app --columns=application 2>/dev/null || true ;;
    *)
        fail "pixel-store index|search|flatpak-search|flatpak-installed|flatpak-updates …"
        exit 2
        ;;
esac
