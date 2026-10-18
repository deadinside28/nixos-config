# Проверка pixel-storage: очистка не выходит за каталоги данных программ,
# не трогает настройки Home Manager и запущенные приложения; размеры
# приложений Nix и Flatpak разбираются верно.
#   bash modules/shell/storage-test.sh modules/shell/storage.sh
# nix, flatpak и pgrep подменяются заглушками в PATH.
set -u

script=$(realpath "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash=$(command -v bash)

export HOME="$work/home"
mkdir -p "$HOME" "$work/bin" "$work/store"

# Заглушки
cat >"$work/bin/flatpak" <<EOF
#!$bash
case "\$1" in
    ps) printf '%s\n' \${RUNNING_FLATPAK:-} ;;
    info) [ "\$2" = --show-location ] && [ "\$4" = org.Some.App ] && echo "$work/flatpak-deploy" ;;
esac
EOF
cat >"$work/bin/nix" <<EOF
#!$bash
# nix path-info -sS -- путь… → «путь размер замыкание»
shift 3
for p in "\$@"; do printf '%s\t%s\t%s\n' "\$p" 1000 5000; done
EOF
cat >"$work/bin/pgrep" <<EOF
#!$bash
for a; do last=\$a; done
[ -n "\${RUNNING_PROCESS:-}" ] && [ "\$last" = "\$RUNNING_PROCESS" ]
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
st() {
    out=$(bash -euo pipefail "$script" "$@" 2>"$work/err")
    rc=$?
    err=$(cat "$work/err")
}

# --- clean ----------------------------------------------------------------
mkdir -p "$HOME/.cache/app/sub" "$HOME/.config/app" "$HOME/Documents"
echo x >"$HOME/.cache/app/sub/f"
echo x >"$HOME/.config/app/settings"
echo doc >"$HOME/Documents/important"

st clean cache -- "$HOME/.cache/app"
check "кеш очищен, каталог остался" '[ $rc -eq 0 ] && [ -d "$HOME/.cache/app" ] && [ -z "$(ls -A "$HOME/.cache/app")" ]'

st clean data -- "$HOME/Documents" "$HOME/.config/app"
check "документы — вне каталогов данных, не тронуты" '[ $rc -ne 0 ] && [ -f "$HOME/Documents/important" ]'
check "остальные пути всё равно очищены" '[ ! -e "$HOME/.config/app" ]'
check "итог в последней строке" '[[ $(printf "%s\n" "$err" | tail -n 1) == *"не удалось: 1"* ]]'

st clean data -- "$HOME" "$HOME/.config" "$HOME/.config/../Documents"
check "сама домашняя папка, корень .config и «..» — отказ" '[ $rc -ne 0 ] && [ -f "$HOME/Documents/important" ] && [ -d "$HOME/.config" ]'

mkdir -p "$HOME/.config/hm" && ln -s "/nix/store/abc-home-manager-files/x" "$HOME/.config/hm/managed" && echo y >"$HOME/.config/hm/own"
st clean data -- "$HOME/.config/hm"
check "каталог со ссылками Home Manager не тронут" '[ $rc -ne 0 ] && [ -L "$HOME/.config/hm/managed" ] && [ -f "$HOME/.config/hm/own" ] && [[ $err == *"Home Manager"* ]]'

mkdir -p "$HOME/.var/app/org.Some.App/cache" && echo z >"$HOME/.var/app/org.Some.App/cache/c"
RUNNING_FLATPAK=org.Some.App st clean data --flatpak org.Some.App -- "$HOME/.var/app/org.Some.App"
check "запущенный Flatpak — отказ, данные целы" '[ $rc -eq 3 ] && [ -f "$HOME/.var/app/org.Some.App/cache/c" ]'
st clean data --flatpak org.Some.App -- "$HOME/.var/app/org.Some.App"
check "закрытый Flatpak — данные сброшены" '[ $rc -eq 0 ] && [ ! -e "$HOME/.var/app/org.Some.App" ]'

mkdir -p "$HOME/.cache/tg" && echo z >"$HOME/.cache/tg/c"
RUNNING_PROCESS='/nix/store/abc-telegram\.1' st clean cache --running /nix/store/abc-telegram.1 -- "$HOME/.cache/tg"
check "запущенная программа — отказ" '[ $rc -eq 3 ] && [ -f "$HOME/.cache/tg/c" ]'

st clean wipe -- "$HOME/.cache/tg"
check "неизвестное действие" '[ $rc -eq 2 ] && [ -f "$HOME/.cache/tg/c" ]'

# --- apps / paths ---------------------------------------------------------
mkdir -p "$work/store/nix/store" "$work/flatpak-deploy"
head -c 4096 /dev/zero >"$work/flatpak-deploy/blob"
pkg="/nix/store/aaaa-chrome-1.0"
# .desktop из профиля — ссылка в стор (как в /run/current-system/sw)
mkdir -p "$work/profile/share/applications"
if [ -d /nix/store ]; then
    st_target=""
else
    st_target="$pkg/share/applications/chrome.desktop"
fi
out=$(bash -euo pipefail "$script" apps org.Some.App flatpak "")
check "Flatpak: размер каталога развёртывания" '[[ $out == *"app	org.Some.App	own	"[1-9]* ]]'

if [ -n "$st_target" ]; then
    ln -s "$st_target" "$work/profile/share/applications/chrome.desktop"
    # readlink -f висячей ссылки в несуществующий /nix/store даёт тот же путь
    out=$(bash -euo pipefail "$script" apps chrome nix "$work/profile/share/applications/chrome.desktop")
    check "Nix: свой размер и замыкание по пути в сторе" '[[ $out == *"app	chrome	own	1000"* && $out == *"app	chrome	closure	5000"* && $out == *"app	chrome	store	$pkg"* ]]'
fi

st paths "$work/flatpak-deploy" "$work/nope"
check "размеры путей, нет пути — 0" '[[ $out == *"path	$work/nope	0"* ]] && [[ $out == *done ]]'

st overview
check "обзор: диск и итог" '[[ $out == disk* ]] && [[ $out == *done ]]'

printf 'pixel-storage: %d проверок пройдено, %d провалено\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
