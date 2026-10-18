# Проверка pixel-reminders: наступившее напоминание приходит один раз,
# будущее и слишком старое — нет.
#   bash modules/shell/reminders-test.sh modules/shell/reminders.sh
set -u
script=$(realpath "$1")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bash=$(command -v bash)
export XDG_STATE_HOME="$work/state"
mkdir -p "$work/bin" "$XDG_STATE_HOME/pixel-calendar"
printf '#!%s\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$bash" "$work" "$work" >"$work/bin/notify-send"
chmod +x "$work/bin/notify-send"
export PATH="$work/bin:$PATH"

cat >"$XDG_STATE_HOME/pixel-calendar/reminders.json" <<'EOF'
[
  { "id": "a@1", "at": 1000, "title": "Сейчас", "when": "2026-10-18 10:00" },
  { "id": "b@1", "at": 5000, "title": "Потом", "when": "2026-10-18 11:00" },
  { "id": "c@1", "at": 10, "title": "Давно", "when": "2026-10-17 10:00" }
]
EOF

passed=0 failures=0
check() {
    if eval "$2"; then passed=$((passed + 1)); else
        failures=$((failures + 1))
        printf 'FAIL: %s [%s]\n' "$1" "$2" >&2
    fi
}

NOW=1100 GRACE=600 bash -euo pipefail "$script" --once
check "наступившее пришло" 'grep -q "Сейчас" "$work/notified"'
check "будущее и слишком старое — нет" '! grep -q "Потом\|Давно" "$work/notified"'
NOW=1200 GRACE=600 bash -euo pipefail "$script" --once
check "второй раз не приходит" '[ "$(grep -c "Сейчас" "$work/notified")" -eq 1 ]'
NOW=5001 GRACE=600 bash -euo pipefail "$script" --once
check "в своё время приходит и следующее" 'grep -q "Потом" "$work/notified"'
rm -f "$XDG_STATE_HOME/pixel-calendar/reminders.json"
NOW=5001 bash -euo pipefail "$script" --once
check "нет списка — не падает" '[ $? -eq 0 ]'

printf 'pixel-reminders: %d проверок пройдено, %d провалено\n' "$passed" "$failures"
[ "$failures" -eq 0 ]
