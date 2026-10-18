# pixel-reminders — напоминания календаря, независимо от оболочки.
#
# Оболочка раскладывает события на ближайшие дни (с повторами) и пишет
# ~/.local/state/pixel-calendar/reminders.json: [{ id, at, title, when }],
# at — секунды Unix. Эта служба (systemd --user) раз в 30 секунд
# показывает наступившие напоминания. Пропущенные во время сна или
# выключения приходят после, если опоздание не больше GRACE (30 мин).
# Показанные запоминаются в fired, повторно не приходят.
#
#   pixel-reminders        — работать постоянно
#   pixel-reminders --once — одна проверка (для теста; NOW — подменить время)

state="${XDG_STATE_HOME:-$HOME/.local/state}/pixel-calendar"
list="$state/reminders.json"
fired="$state/fired"
grace=${GRACE:-1800}

check() {
    local now id title when
    now=${NOW:-$(date +%s)}
    [ -s "$list" ] || return 0
    mkdir -p "$state"
    touch "$fired"
    while IFS=$'\t' read -r id title when; do
        [ -n "$id" ] || continue
        grep -qxF -- "$id" "$fired" && continue
        notify-send -a "Календарь" -i x-office-calendar -u critical -- "$title" "$when" || continue
        printf '%s\n' "$id" >>"$fired"
    done < <(jq -r --argjson now "$now" --argjson grace "$grace" \
        '.[]? | select(.at <= $now and .at > $now - $grace) | [.id, .title, .when] | @tsv' "$list" 2>/dev/null || true)
    # Список показанных не растёт бесконечно
    if [ "$(wc -l <"$fired")" -gt 2000 ]; then
        tail -n 1000 "$fired" >"$fired.tmp" && mv -f "$fired.tmp" "$fired"
    fi
}

if [ "${1:-}" = --once ]; then
    check
    exit 0
fi
while true; do
    check
    sleep 30
done
