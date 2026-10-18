# Проверка pixel-fileops со сбоями: ошибка одного файла не должна
# прятаться за успехом остальных, а распакованное — пропадать.
#   bash modules/shell/fileops-test.sh modules/shell/fileops.sh
# Сбои вызываются подменой mv/cp в PATH (работает и от root, в отличие
# от chmod): FAIL_MV / FAIL_CP — подстрока аргумента, на котором падать.
set -u

script=$(realpath "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

shims="$work/shims"
bash=$(command -v bash) # в песочнице Nix нет /usr/bin/env
mkdir -p "$shims"
for tool in mv cp; do
    real=$(command -v "$tool")
    var="FAIL_$(printf '%s' "$tool" | tr a-z A-Z)"
    cat >"$shims/$tool" <<EOF
#!$bash
if [ -n "\${$var:-}" ]; then
    for a in "\$@"; do
        case "\$a" in *"\$$var"*) echo "$tool: имитация сбоя на '\$a'" >&2; exit 1 ;; esac
    done
fi
exec $real "\$@"
EOF
    chmod +x "$shims/$tool"
done
export PATH="$shims:$PATH"

passed=0 failures=0
ok() { passed=$((passed + 1)); }
bad() {
    failures=$((failures + 1))
    printf 'FAIL: %s\n' "$*" >&2
}
check() { if eval "$2"; then ok; else bad "$1 [$2]"; fi; }

# ops ARGS… — запуск как в writeShellApplication; код в $rc, stderr в $err
ops() {
    err=$(bash -euo pipefail "$script" "$@" 2>&1 >/dev/null)
    rc=$?
    last=$(printf '%s\n' "$err" | tail -n 1)
}

fresh() {
    rm -rf "$work/t"
    mkdir -p "$work/t/src" "$work/t/dst"
    cd "$work/t" || exit 1
    printf a >src/a.txt
    printf b >src/b.txt
    printf c >src/c.txt
}

# --- transfer -----------------------------------------------------------------
fresh
ops transfer copy dst src/a.txt src/b.txt src/c.txt
check "копирование без ошибок" '[ $rc -eq 0 ] && [ -f dst/a.txt ] && [ -f dst/b.txt ] && [ -f dst/c.txt ]'

ops transfer copy dst src/a.txt
check "совпадение имён → «a (2).txt»" '[ $rc -eq 0 ] && [ -f "dst/a (2).txt" ]'

fresh
FAIL_CP=b.txt ops transfer copy dst src/a.txt src/b.txt src/c.txt
check "ошибка в середине видна в коде выхода" '[ $rc -ne 0 ]'
check "ошибка в середине не скрыта последним успехом" '[[ $last == *"1 из 3"* && $last == *"«b.txt»"* ]]'
check "остальные файлы скопированы" '[ -f dst/a.txt ] && [ -f dst/c.txt ] && [ ! -e dst/b.txt ]'

fresh
FAIL_CP=a.txt ops transfer copy dst src/a.txt
check "единственный файл: причина в последней строке" '[ $rc -ne 0 ] && [[ $last == *"«a.txt»"*"имитация сбоя"* ]]'

fresh
ops transfer copy dst src/a.txt src/nope.txt
check "пропавший исходник — ошибка, а не тихий пропуск" '[ $rc -ne 0 ] && [[ $last == *"nope.txt"* ]] && [ -f dst/a.txt ]'

fresh
FAIL_MV=b.txt ops transfer move dst src/a.txt src/b.txt src/c.txt
check "перемещение: частичная ошибка видна" '[ $rc -ne 0 ] && [[ $last == *"переместить 1 из 3"* ]]'
check "перемещение: исходник при сбое на месте" '[ -f src/b.txt ] && [ ! -e src/a.txt ] && [ -f dst/a.txt ] && [ -f dst/c.txt ]'

fresh
ops transfer move src src/a.txt
check "перемещение в ту же папку — ничего не делать" '[ $rc -eq 0 ] && [ -f src/a.txt ] && [ ! -e "src/a (2).txt" ]'

# --- extract ------------------------------------------------------------------
fresh
mkdir -p pack/inner && printf x >pack/inner/x.txt
(cd pack && bsdtar -a -cf ../one.zip inner)
(cd src && bsdtar -a -cf ../many.zip a.txt b.txt)

ops extract one.zip dst one
check "один каталог внутри → он сам" '[ $rc -eq 0 ] && [ -f dst/inner/x.txt ] && [ -z "$(ls -A dst | grep pixel-extract)" ]'

ops extract many.zip dst many
check "несколько файлов → папка с именем архива" '[ $rc -eq 0 ] && [ -f dst/many/a.txt ] && [ -f dst/many/b.txt ]'

ops extract many.zip dst many
check "повтор → «many (2)»" '[ $rc -eq 0 ] && [ -f "dst/many (2)/a.txt" ]'

rm -rf dst && mkdir dst
FAIL_MV=pixel-extract ops extract many.zip dst many
check "сбой переноса — не успех" '[ $rc -ne 0 ]'
tmpdir=$(printf '%s\n' "$last" | sed -n 's/.*Файлы сохранены в //p')
check "сбой переноса — распакованное сохранено, путь в сообщении" '[ -n "$tmpdir" ] && [ -f "$tmpdir/a.txt" ] && [ -f "$tmpdir/b.txt" ]'
check "сбой переноса — цель не создана" '[ ! -e dst/many ]'

rm -rf dst && mkdir dst
FAIL_MV=pixel-extract ops extract one.zip dst one
tmpdir=$(printf '%s\n' "$last" | sed -n 's/.*Файлы сохранены в //p')
check "сбой переноса единственной папки — она сохранена" '[ $rc -ne 0 ] && [ -f "$tmpdir/inner/x.txt" ]'

rm -rf dst && mkdir dst
printf 'не архив' >broken.zip
ops extract broken.zip dst broken
check "битый архив — ошибка без мусора" '[ $rc -ne 0 ] && [ -z "$(ls -A dst)" ]'

# --- compress -----------------------------------------------------------------
fresh
ops compress src arch a.txt b.txt
check "сжатие" '[ $rc -eq 0 ] && [ "$(bsdtar -tf src/arch.zip | sort | tr "\n" " ")" = "a.txt b.txt " ]'

ops compress src arch a.txt
check "сжатие: свободное имя" '[ $rc -eq 0 ] && [ -f "src/arch (2).zip" ]'

ops compress src bad a.txt nope.txt
check "сжатие: ошибка без недописанного архива" '[ $rc -ne 0 ] && [ ! -e src/bad.zip ]'

# --- add-to-archive -----------------------------------------------------------
fresh
(cd src && bsdtar -a -cf ../arc.zip a.txt)
mkdir -p cache && (cd cache && bsdtar -xf ../arc.zip) && touch cache/.pixel-done
ops add-to-archive "$PWD/arc.zip" "$PWD/cache" "$PWD/cache" .zip src/b.txt
check "добавление в архив" '[ $rc -eq 0 ] && [ "$(bsdtar -tf arc.zip | sort | tr "\n" " ")" = "a.txt b.txt " ] && [ -e cache/.pixel-done ]'

before=$(md5sum <arc.zip)
FAIL_MV=pixel-repack ops add-to-archive "$PWD/arc.zip" "$PWD/cache" "$PWD/cache" .zip src/c.txt
check "добавление: сбой замены — ошибка" '[ $rc -ne 0 ]'
check "добавление: исходный архив цел" '[ "$(md5sum <arc.zip)" = "$before" ] && [ -z "$(ls -A | grep pixel-repack)" ]'
check "добавление: кеш помечен на перераспаковку" '[ ! -e cache/.pixel-done ]'

touch cache/.pixel-done
FAIL_CP=c.txt ops add-to-archive "$PWD/arc.zip" "$PWD/cache" "$PWD/cache" .zip src/c.txt
check "добавление: сбой копирования — архив цел" '[ $rc -ne 0 ] && [ "$(md5sum <arc.zip)" = "$before" ] && [ ! -e cache/.pixel-done ]'

# --- прочее -------------------------------------------------------------------
ops unknown
check "неизвестная команда" '[ $rc -eq 2 ]'

printf 'pixel-fileops: %d проверок пройдено, %d провалено\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
