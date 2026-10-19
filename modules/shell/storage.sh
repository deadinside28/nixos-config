# pixel-storage — раздел «Память» в «Настройках»: сколько места занято и
# чем, размеры приложений и очистка их кеша и данных.
#
# Собирается в writeShellApplication (bash, errexit, nounset, pipefail).
# Проверка: modules/shell/storage-test.sh (nix flake check).
#
# Размеры — занятое на диске место (du, блоки), кроме Nix: у него размер
# пакета (NAR, `nix path-info -s`) и его замыкания со всеми зависимостями
# (`-S`). Это разные числа: замыкания разных программ пересекаются, и
# складывать их нельзя. Сколько освободится после удаления, заранее не
# известно — пакет может держать другая программа или старое поколение.
#
# Вывод — строки «ключ<TAB>значение…», по мере подсчёта: интерфейс
# показывает их сразу и может прервать долгий подсчёт.

fail() { printf '%s\n' "$*" >&2; }

# Занято на диске, байт; нет пути — 0
dsize() {
    if [ -e "$1" ]; then
        du -s -B1 --one-file-system -- "$1" 2>/dev/null | cut -f1 || echo 0
    else
        echo 0
    fi
}

# overview — диск и крупные категории
overview() {
    local home=$HOME size avail target
    read -r size avail < <(df -B1 --output=size,avail -- / | tail -n 1)
    printf 'disk\t%s\t%s\n' "$size" "$avail"
    # /home на своём разделе — покажем и его
    read -r size avail target < <(df -B1 --output=size,avail,target -- "$home" | tail -n 1)
    if [ "$target" != / ]; then
        printf 'homedisk\t%s\t%s\n' "$size" "$avail"
    fi
    if [ -e /run/current-system ] && command -v nix >/dev/null; then
        printf 'system\t%s\n' "$(nix path-info -S /run/current-system 2>/dev/null | awk '{print $2}' || echo 0)"
    fi
    printf 'generations\t%s\n' "$(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' 2>/dev/null | wc -l)"
    printf 'flatpak\t%s\n' "$(($(dsize /var/lib/flatpak) + $(dsize "$home/.local/share/flatpak")))"
    printf 'appdata\t%s\n' "$(dsize "$home/.var/app")"
    printf 'cache\t%s\n' "$(dsize "${XDG_CACHE_HOME:-$home/.cache}")"
    printf 'trash\t%s\n' "$(dsize "${XDG_DATA_HOME:-$home/.local/share}/Trash")"
    # Остальное в домашней папке — пользовательские файлы и настройки
    printf 'home\t%s\n' "$(dsize "$home")"
    printf 'done\n'
}

# apps ID KIND ФАЙЛ … — размеры приложений, тройками: desktop ID, nix|flatpak,
# путь к .desktop. Nix: все пакеты одним вызовом nix path-info;
# Flatpak: каталог развёртывания.
apps() {
    local id kind file real store
    declare -A nixpath=()
    while [ "$#" -ge 3 ]; do
        id=$1 kind=$2 file=$3
        shift 3
        case "$kind" in
            flatpak)
                local loc
                loc=$(flatpak info --show-location -- "$id" 2>/dev/null || true)
                if [ -n "$loc" ]; then
                    printf 'app\t%s\town\t%s\n' "$id" "$(dsize "$loc")"
                fi
                ;;
            nix)
                real=$(readlink -f -- "$file" 2>/dev/null || true)
                case "$real" in
                    /nix/store/*)
                        store=${real#/nix/store/}
                        store="/nix/store/${store%%/*}"
                        nixpath[$id]=$store
                        ;;
                esac
                ;;
        esac
    done
    if [ "${#nixpath[@]}" -gt 0 ] && command -v nix >/dev/null; then
        declare -A size=()
        local p s c
        # «путь  свой  замыкание» — один вызов на все пакеты
        while read -r p s c; do
            size[$p]="$s"$'\t'"$c"
        done < <(nix path-info -sS -- "${nixpath[@]}" 2>/dev/null || true)
        for id in "${!nixpath[@]}"; do
            p=${nixpath[$id]}
            [ -n "${size[$p]:-}" ] || continue
            printf 'app\t%s\town\t%s\n' "$id" "${size[$p]%%$'\t'*}"
            printf 'app\t%s\tclosure\t%s\n' "$id" "${size[$p]#*$'\t'}"
            printf 'app\t%s\tstore\t%s\n' "$id" "$p"
        done
    fi
    printf 'done\n'
}

# paths PATH… — размер каждого пути данных
paths() {
    local p
    for p in "$@"; do
        printf 'path\t%s\t%s\n' "$p" "$(dsize "$p")"
    done
    printf 'done\n'
}

# caches — кеш по программам: каждый элемент ~/.cache и кеш каждого
# Flatpak-приложения (~/.var/app/ID/cache). «cache<TAB>путь<TAB>байт»
caches() {
    local c=${XDG_CACHE_HOME:-$HOME/.cache} d
    for d in "$c"/* "$c"/.[!.]*; do
        [ -e "$d" ] || continue
        printf 'cache\t%s\t%s\n' "$d" "$(dsize "$d")"
    done
    for d in "$HOME"/.var/app/*/cache; do
        [ -d "$d" ] || continue
        printf 'cache\t%s\t%s\n' "$d" "$(dsize "$d")"
    done
    printf 'done\n'
}

# Путь можно чистить, только если он внутри известных каталогов данных
# программ в домашней папке — не сама домашняя папка и не документы.
allowed() {
    local p=$1 home=$HOME
    case "$p" in *"/../"* | *"/.." | *"/./"*) return 1 ;; esac
    case "$p" in
        "$home/.cache/"?* | "$home/.config/"?* | "$home/.local/share/"?* | "$home/.local/state/"?* | "$home/.var/app/"?*) return 0 ;;
    esac
    return 1
}

# clean cache|data [--flatpak ID] [--running ПУТЬ] -- PATH…
#   --running — путь пакета в /nix/store: программа запущена, если он есть
#   в командной строке какого-нибудь процесса (имя процесса у обёрток
#   NixOS — «.имя-wrapped», по нему искать ненадёжно).
#   cache — удалить содержимое (сами каталоги остаются);
#   data  — удалить пути целиком (сброс к первому запуску).
# Программа должна быть закрыта, иначе она запишет старое состояние
# обратно. Настройки, которыми управляет Home Manager (ссылки в
# /nix/store), не трогаются: путь с ними пропускается целиком.
clean() {
    local what=$1 flatpak="" running="" p failed=0 done_=0 err
    shift
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --flatpak) flatpak=$2; shift 2 ;;
            --running) running=$2; shift 2 ;;
            --) shift; break ;;
            *) break ;;
        esac
    done
    case "$what" in cache | data) ;; *) fail "clean cache|data …"; return 2 ;; esac
    if [ -n "$flatpak" ] && flatpak ps --columns=application 2>/dev/null | grep -qxF -- "$flatpak"; then
        fail "Приложение запущено — закройте его и повторите"
        return 3
    fi
    if [ -n "$running" ] && pgrep -f -- "$(printf '%s' "$running" | sed 's/[][\\.^$*+?(){}|]/\\&/g')" >/dev/null 2>&1; then
        fail "Приложение запущено — закройте его и повторите"
        return 3
    fi
    for p in "$@"; do
        if ! allowed "$p"; then
            fail "Пропущено «$p»: вне каталогов данных программ"
            failed=$((failed + 1))
            continue
        fi
        [ -e "$p" ] || [ -L "$p" ] || continue
        if [ -L "$p" ] || [ -n "$(find "$p" -lname '/nix/store/*' -print -quit 2>/dev/null)" ]; then
            fail "Пропущено «$p»: им управляет конфигурация (Home Manager)"
            failed=$((failed + 1))
            continue
        fi
        if [ "$what" = cache ] && [ ! -d "$p" ]; then
            # отдельный файл в ~/.cache — просто удалить
            if ! err=$(rm -f -- "$p" 2>&1) || [ -e "$p" ]; then
                fail "Не удалось удалить «$p»: $(printf '%s\n' "$err" | tail -n 1)"
                failed=$((failed + 1))
                continue
            fi
        elif [ "$what" = cache ]; then
            err=$(find "$p" -mindepth 1 -delete 2>&1) || true
            [ -z "$(find "$p" -mindepth 1 -print -quit 2>/dev/null)" ] || { fail "Не всё удалено в «$p»: $(printf '%s\n' "$err" | tail -n 1)"; failed=$((failed + 1)); continue; }
        else
            if ! err=$(rm -rf -- "$p" 2>&1) || [ -e "$p" ]; then
                fail "Не удалось удалить «$p»: $(printf '%s\n' "$err" | tail -n 1)"
                failed=$((failed + 1))
                continue
            fi
        fi
        done_=$((done_ + 1))
    done
    if [ "$failed" -gt 0 ]; then
        fail "Очищено путей: $done_, не удалось: $failed"
        return 1
    fi
}

cmd=${1:-}
[ "$#" -eq 0 ] || shift
case "$cmd" in
    overview) overview ;;
    apps) apps "$@" ;;
    paths) paths "$@" ;;
    caches) caches ;;
    clean) clean "$@" ;;
    *)
        fail "pixel-storage overview|apps|paths|caches|clean …"
        exit 2
        ;;
esac
