# pixel-fileops — файловые операции «Файлов» и архиватора: вставка,
# копирование и перемещение, распаковка, сжатие, добавление в архив.
#
# Собирается в writeShellApplication (bash, errexit, nounset, pipefail).
# Проверка со сбоями: modules/shell/fileops-test.sh (nix flake check).
#
# Договорённость об ошибках: каждая ошибка пишется в stderr своей строкой,
# последняя строка stderr — итог для пользователя (её показывает окно).
# Код выхода 1, если не получилось хоть что-то — даже когда остальные
# файлы скопировались. Ничего, что уже было у пользователя, при сбое
# не удаляется.

fail() { printf '%s\n' "$*" >&2; }

# Последняя непустая строка вывода команды — обычно в ней причина
lastline() { printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 1; }

# Свободное имя в папке: «имя (2).ext», «имя (3).ext»…
# Третий аргумент noext — не отделять расширение (для папок).
unique() {
    local dest=$1 base=$2 noext=${3:-} target n=2
    target="$dest/$base"
    while [ -e "$target" ] || [ -L "$target" ]; do
        case "$noext:$base" in
            :?*.*) target="$dest/${base%.*} ($n).${base##*.}" ;;
            *) target="$dest/$base ($n)" ;;
        esac
        n=$((n + 1))
    done
    printf '%s' "$target"
}

# transfer copy|move DEST SRC… — копирование или перемещение с подбором
# свободного имени. Ошибка одного файла не прерывает остальные и не
# теряется за успехом следующих.
transfer() {
    local mode=$1 dest=$2 src name target err verb total=0 failed=0 first=""
    shift 2
    if [ "$mode" = move ]; then verb="переместить"; else verb="скопировать"; fi
    for src in "$@"; do
        if [ "$mode" = move ] && [ "$(dirname -- "$src")" = "$dest" ]; then continue; fi
        total=$((total + 1))
        name=$(basename -- "$src")
        if [ ! -e "$src" ] && [ ! -L "$src" ]; then
            err="файла больше нет"
        else
            target=$(unique "$dest" "$name")
            if [ "$mode" = move ]; then
                # -n: если имя успели занять, не затирать чужой файл
                if err=$(mv -n -- "$src" "$target" 2>&1) && [ ! -e "$src" ] && [ ! -L "$src" ]; then
                    continue
                fi
                [ -n "$err" ] || err="не перемещено"
            else
                if err=$(cp -a -- "$src" "$target" 2>&1); then
                    continue
                fi
                # Недокопированная копия выглядела бы целой — убираем её.
                # Это только что созданный путь, исходник не трогаем.
                rm -rf -- "$target"
            fi
        fi
        failed=$((failed + 1))
        err=$(lastline "$err")
        fail "Не удалось $verb «$name»: $err"
        [ -n "$first" ] || first="«$name»: $err"
    done
    if [ "$failed" -eq 1 ] && [ "$total" -eq 1 ]; then
        fail "Не удалось $verb $first"
        return 1
    elif [ "$failed" -gt 0 ]; then
        fail "Не удалось $verb $failed из $total (первая ошибка — $first)"
        return 1
    fi
}

# paste copy|cut DEST [SRC…] — вставка. Вырезанное в «Файлах» (cut)
# перемещается; иначе источник — системный буфер: файлы (text/uri-list —
# из «Файлов», Nemo, браузера…) копируются, картинка сохраняется файлом.
paste_clip() {
    local mode=$1 dest=$2 types u img ext f
    shift 2
    if [ "$mode" = cut ]; then
        transfer move "$dest" "$@"
        return
    fi
    types=$(wl-paste --list-types 2>/dev/null || true)
    if grep -qx 'text/uri-list' <<<"$types"; then
        local list=()
        while IFS= read -r u; do
            u=${u%$'\r'}
            case "$u" in file://*) ;; *) continue ;; esac
            u=${u#file://}
            list+=("$(printf '%b' "${u//%/\\x}")")
        done < <(wl-paste --type text/uri-list 2>/dev/null || true)
        if [ "${#list[@]}" -eq 0 ]; then
            fail "В буфере обмена нет локальных файлов"
            return 1
        fi
        transfer copy "$dest" "${list[@]}"
        return
    fi
    img=$(grep -m1 '^image/' <<<"$types" || true)
    if [ -z "$img" ]; then
        fail "В буфере обмена нет файлов или изображения"
        return 1
    fi
    ext=${img#image/}
    ext=${ext%%;*}
    if [ "$ext" = jpeg ]; then ext=jpg; fi
    f=$(unique "$dest" "Снимок экрана $(date '+%Y-%m-%d %H-%M-%S').$ext")
    if ! wl-paste --type "$img" >"$f" || [ ! -s "$f" ]; then
        rm -f -- "$f"
        fail "Не удалось сохранить изображение из буфера обмена"
        return 1
    fi
}

# extract SRC DEST NAME — распаковать в папку NAME рядом (если внутри
# один каталог — просто его). Распаковка идёт во временную папку внутри
# DEST; если финальный перенос не удался, распакованное остаётся там,
# и путь к нему попадает в сообщение об ошибке.
extract() {
    local src=$1 dest=$2 name=$3 tmp err f items=0 one="" from target
    if ! tmp=$(mktemp -d "$dest/.pixel-extract.XXXXXX" 2>&1); then
        fail "Не удалось распаковать «$(basename -- "$src")»: $(lastline "$tmp")"
        return 1
    fi
    if ! err=$(bsdtar -xf "$src" -C "$tmp" 2>&1); then
        rm -rf -- "$tmp"
        fail "Не удалось распаковать «$(basename -- "$src")»: $(lastline "$err")"
        return 1
    fi
    for f in "$tmp"/* "$tmp"/.[!.]* "$tmp"/..?*; do
        if [ -e "$f" ] || [ -L "$f" ]; then
            items=$((items + 1))
            one=$f
        fi
    done
    if [ "$items" -eq 1 ] && [ -d "$one" ] && [ ! -L "$one" ]; then
        from=$one
        name=$(basename -- "$one")
    else
        from=$tmp
    fi
    target=$(unique "$dest" "$name" noext)
    # -T: переносим саму папку, а не внутрь одноимённой; -n: не затирать
    if ! err=$(mv -n -T -- "$from" "$target" 2>&1) || [ -e "$from" ]; then
        fail "Не удалось перенести распакованное в «$target»: $(lastline "${err:-путь занят}"). Файлы сохранены в $tmp"
        return 1
    fi
    # Если переносили единственную папку изнутри — временная теперь пуста
    if [ "$from" != "$tmp" ]; then rmdir -- "$tmp" 2>/dev/null || true; fi
}

# add-to-archive ARCHIVE ROOT DIR SUFFIX PATH… — кладём файлы в
# распакованную копию (ROOT — её корень, DIR — текущая папка в ней) и
# собираем архив заново в том же формате (bsdtar выбирает его по SUFFIX).
# Исходный архив заменяется только готовым новым.
add_to_archive() {
    local archive=$1 root=$2 dir=$3 suffix=$4 tmp err
    shift 4
    if ! err=$(cp -a -- "$@" "$dir"/ 2>&1); then
        # Копия в кеше разошлась с архивом — при следующем открытии
        # архиватор распакует его заново
        rm -f -- "$root/.pixel-done"
        fail "Не удалось добавить файлы в архив: $(lastline "$err")"
        return 1
    fi
    tmp="$(dirname -- "$archive")/.pixel-repack-$$$suffix"
    if ! err=$(cd "$root" && find . -mindepth 1 -maxdepth 1 ! -name .pixel-done -printf '%P\0' | xargs -0 bsdtar -a -cf "$tmp" 2>&1); then
        rm -f -- "$tmp" "$root/.pixel-done"
        fail "Не удалось пересобрать архив: $(lastline "$err")"
        return 1
    fi
    if ! err=$(mv -f -- "$tmp" "$archive" 2>&1); then
        rm -f -- "$tmp" "$root/.pixel-done"
        fail "Не удалось заменить архив: $(lastline "$err")"
        return 1
    fi
    touch -- "$root/.pixel-done"
}

# compress DIR NAME FILE… — сжать FILE… (имена внутри DIR) в «NAME.zip»
compress() {
    local dir=$1 name=$2 t err
    shift 2
    if ! cd -- "$dir" 2>/dev/null; then
        fail "Нет папки «$dir»"
        return 1
    fi
    t=$(unique . "$name.zip")
    t=${t#./}
    if ! err=$(bsdtar -a -cf "$t" -- "$@" 2>&1); then
        # Недописанный архив выглядел бы целым — убираем
        rm -f -- "$t"
        fail "Не удалось создать «$t»: $(lastline "$err")"
        return 1
    fi
}

cmd=${1:-}
[ "$#" -eq 0 ] || shift
case "$cmd" in
    transfer) transfer "$@" ;;
    paste) paste_clip "$@" ;;
    extract) extract "$@" ;;
    add-to-archive) add_to_archive "$@" ;;
    compress) compress "$@" ;;
    *)
        fail "pixel-fileops transfer|paste|extract|add-to-archive|compress …"
        exit 2
        ;;
esac
