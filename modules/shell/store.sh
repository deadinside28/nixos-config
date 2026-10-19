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
#   flatpak-updates-all   — то же вместе со средами выполнения и расширениями
#   catalog               — каталог Flathub из локального AppStream (JSON),
#                           пересобирается, когда Flatpak обновил AppStream:
#                           «catalog<TAB>путь<TAB>число приложений»
#   featured              — подборки Flathub (популярное, в тренде, новое),
#                           раз в сутки: «featured<TAB>путь»
#   nix-info FLAKE ВХОД АТРИБУТ — описание пакета Nix (meta) в JSON

fail() { printf '%s\n' "$*" >&2; }

dir="${XDG_CACHE_HOME:-$HOME/.cache}/pixel-shell/store"
# Путь к store-appstream.py подставляет сборка (default.nix)
: "${appstream_py:=${PIXEL_APPSTREAM_PY:-}}"

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

# Каталоги AppStream всех remote: системные и пользовательские
appstream_dirs() {
    if [ -n "${PIXEL_APPSTREAM_DIRS:-}" ]; then
        tr ':' '\n' <<<"$PIXEL_APPSTREAM_DIRS"
        return
    fi
    local d
    for d in /var/lib/flatpak/appstream/*/x86_64/active "$HOME"/.local/share/flatpak/appstream/*/x86_64/active; do
        [ -d "$d" ] && printf '%s\n' "$(readlink -f -- "$d")"
    done
    true
}

catalog() {
    local out="$dir/catalog.json" stale=0 d n
    local -a dirs=()
    mkdir -p "$dir"
    mapfile -t dirs < <(appstream_dirs)
    if [ "${#dirs[@]}" -eq 0 ]; then
        fail "Нет AppStream Flatpak — подключён ли Flathub?"
        printf 'catalog\t\t0\n'
        return 0
    fi
    [ -s "$out" ] || stale=1
    # active — ссылка на свежий снимок, поэтому сверяем и список каталогов
    if [ "$stale" = 0 ] && [ "$(printf '%s\n' "${dirs[@]}")" != "$(cat "$out.src" 2>/dev/null)" ]; then
        stale=1
    fi
    for d in "${dirs[@]}"; do
        if [ "$stale" = 0 ] && [ -n "$(find "$d" -maxdepth 1 -name 'appstream.xml*' -newer "$out" -print -quit 2>/dev/null)" ]; then
            stale=1
        fi
    done
    if [ "$stale" = 1 ]; then
        if ! n=$(nice -n 10 python3 "$appstream_py" "$out" "${dirs[@]}"); then
            fail "Не удалось разобрать AppStream"
            printf 'catalog\t\t0\n'
            return 0
        fi
        printf '%s\n' "${dirs[@]}" >"$out.src"
    else
        n=$(jq '.apps | length' "$out" 2>/dev/null || echo 0)
    fi
    printf 'catalog\t%s\t%s\n' "$out" "$n"
}

# Подборки Flathub. Нет сети — остаётся прошлый файл (или пустые списки)
featured() {
    local out="$dir/featured.json" api=https://flathub.org/api/v2/collection k
    mkdir -p "$dir"
    if [ -z "$(find "$out" -mmin -1440 2>/dev/null)" ]; then
        local tmp
        tmp=$(mktemp)
        printf '{' >"$tmp"
        for k in popular trending recently-updated recently-added; do
            [ "$k" = popular ] || printf ',' >>"$tmp"
            printf '"%s":' "$k" >>"$tmp"
            curl -fsSL -m 20 "$api/$k?page=1&per_page=24" 2>/dev/null |
                jq -c '[.hits[]?.app_id // empty]' >>"$tmp" 2>/dev/null || printf '[]' >>"$tmp"
        done
        printf '}' >>"$tmp"
        # ничего не скачалось — прошлые подборки лучше пустых
        if jq -e '[.[] | length] | add > 0' "$tmp" >/dev/null 2>&1 || [ ! -s "$out" ]; then
            jq -c . "$tmp" >"$out" 2>/dev/null || printf '{}' >"$out"
        fi
        rm -f "$tmp"
    fi
    printf 'featured\t%s\n' "$out"
}

# Описание пакета Nix из той же ревизии, что в flake.lock
nix_info() {
    local flake=$1 input=$2 attr=$3 ref
    case "$input" in
        chaotic) ref="$input#packages.x86_64-linux.$attr" ;;
        *) ref="$input#legacyPackages.x86_64-linux.$attr" ;;
    esac
    nix eval --json --inputs-from "$flake" "$ref" --apply 'p: let m = p.meta or {}; lic = l: if builtins.isList l then map lic l else if builtins.isAttrs l then (l.spdxId or l.fullName or "") else toString l; in { description = m.description or ""; long = m.longDescription or ""; homepage = toString (m.homepage or ""); license = lic (m.license or ""); version = p.version or ""; program = m.mainProgram or ""; }' 2>/dev/null || {
        fail "Не удалось прочитать описание $attr"
        return 1
    }
}

cmd=${1:-}
[ "$#" -eq 0 ] || shift
case "$cmd" in
    index) index "$@" ;;
    search) search "${1:-}" ;;
    flatpak-search) flatpak_search "${1:-}" ;;
    flatpak-installed) flatpak list --app --columns=application 2>/dev/null || true ;;
    flatpak-updates) flatpak remote-ls --updates --app --columns=application 2>/dev/null || true ;;
    flatpak-updates-all) flatpak remote-ls --updates --columns=application 2>/dev/null || true ;;
    catalog) catalog ;;
    featured) featured ;;
    nix-info) nix_info "$@" ;;
    *)
        fail "pixel-store index|search|flatpak-search|flatpak-installed|flatpak-updates|catalog|featured|nix-info …"
        exit 2
        ;;
esac
