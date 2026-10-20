# pixel-metrics — исходные метрики ресурсов DE (раздел 14 роадмапа).
#
# Память процессов — PSS и USS из /proc/<pid>/smaps_rollup, не RSS: RSS
# считает общие библиотеки в каждом процессе, и сумма врёт. PSS делит общее
# между процессами, поэтому суммы по группам можно складывать. Своих
# процессов — без root; чужие (системные службы) видны только с sudo.
#
#   pixel-metrics [секунд замера CPU, по умолчанию 10]
# Пишет Markdown в stdout и в ~/.local/state/pixel-shell/metrics/<время>.md.
# Снимать в одинаковом состоянии: после входа, в простое, с теми же обоями.

secs=${1:-10}
out_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pixel-shell/metrics"
mkdir -p "$out_dir"
out="$out_dir/$(date +%Y-%m-%d_%H-%M-%S).md"

# Группа процесса по имени команды
group() {
    case "$1" in
        quickshell | qs | .quickshell-wra*) echo "Оболочка (Quickshell)" ;;
        Hyprland | .Hyprland-wrapp*) echo "Hyprland" ;;
        xdg-desktop-por* | .xdg-desktop-po*) echo "Порталы" ;;
        pipewire* | wireplumber | .wireplumber-wr*) echo "Звук (PipeWire)" ;;
        mpvpaper | linux-wallpaper*) echo "Живые обои" ;;
        pixel-* | python3 | .python3-wrappe*) echo "Службы Pixel и Python" ;;
        cliphist | wl-paste) echo "Буфер обмена" ;;
        dbus-* | systemd | at-spi*) echo "Сессия (D-Bus, systemd --user)" ;;
        ollama | .ollama-wrapped) echo "Ollama" ;;
        *) echo "Прочее" ;;
    esac
}

declare -A pss=() uss=() cnt=()
declare -a top=()
for d in /proc/[0-9]*; do
    [ -r "$d/smaps_rollup" ] || continue
    comm=$(cat "$d/comm" 2>/dev/null) || continue
    read -r p u < <(awk '/^Pss:/ {p=$2} /^Private_(Clean|Dirty):/ {u+=$2} END {print p+0, u+0}' "$d/smaps_rollup" 2>/dev/null) || continue
    [ "${p:-0}" -gt 0 ] || continue
    g=$(group "$comm")
    pss[$g]=$((${pss[$g]:-0} + p))
    uss[$g]=$((${uss[$g]:-0} + u))
    cnt[$g]=$((${cnt[$g]:-0} + 1))
    top+=("$p	$u	$comm	${d#/proc/}")
done

mib() { awk -v k="$1" 'BEGIN { printf "%.1f", k / 1024 }'; }

# CPU: доля простоя за $secs секунд по /proc/stat
cpu() {
    local a b
    read -ra a < <(head -n 1 /proc/stat)
    sleep "$secs"
    read -ra b < <(head -n 1 /proc/stat)
    local total=0 idle i
    for i in 1 2 3 4 5 6 7 8; do total=$((total + b[i] - a[i])); done
    idle=$((b[4] - a[4] + b[5] - a[5]))
    awk -v t="$total" -v i="$idle" 'BEGIN { if (t > 0) printf "%.1f", 100 * (t - i) / t; else print "?" }'
}
busy=$(cpu)

{
    printf '# Метрики Pixel DE — %s\n\n' "$(date '+%Y-%m-%d %H:%M')"
    printf 'Хост: %s, ядро %s. Мониторы: %s.\n\n' "$(uname -n)" "$(uname -r)" \
        "$(hyprctl monitors -j 2>/dev/null | jq -r 'map("\(.name) \(.width)x\(.height)@\(.refreshRate|floor) ×\(.scale)") | join(", ")' 2>/dev/null || echo "?")"
    awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2} END {printf "Память системы: всего %.1f ГиБ, доступно %.1f ГиБ, занято %.1f ГиБ.\n\n", t/1048576, a/1048576, (t-a)/1048576}' /proc/meminfo
    for f in /sys/class/drm/card*/device/mem_info_vram_used; do
        [ -r "$f" ] && printf 'Видеопамять занята (%s): %s МиБ.\n\n' "$(basename "$(dirname "$(dirname "$f")")")" "$(($(cat "$f") / 1048576))"
    done
    printf 'Загрузка CPU за %s с: %s%%.\n\n' "$secs" "$busy"
    printf '| Группа | Процессов | PSS, МиБ | USS, МиБ |\n|---|---:|---:|---:|\n'
    for g in "${!pss[@]}"; do
        printf '%s\t%s\t%s\t%s\n' "${pss[$g]}" "$g" "${cnt[$g]}" "${uss[$g]}"
    done | sort -rn | while IFS=$'\t' read -r p g c u; do
        printf '| %s | %s | %s | %s |\n' "$g" "$c" "$(mib "$p")" "$(mib "$u")"
    done
    printf '\n## Крупнейшие процессы (PSS)\n\n| Процесс | PID | PSS, МиБ | USS, МиБ |\n|---|---:|---:|---:|\n'
    printf '%s\n' "${top[@]}" | sort -rn | awk 'NR <= 15' | while IFS=$'\t' read -r p u c pid; do
        printf '| %s | %s | %s | %s |\n' "$c" "$pid" "$(mib "$p")" "$(mib "$u")"
    done
    # Оболочка подробно: из чего её RSS и какие потоки. GPU-буферы,
    # отображённые в процесс (/dev/dri), считаются в RSS, но это видеопамять
    # драйвера, а не данные оболочки.
    for d in /proc/[0-9]*; do
        case "$(cat "$d/comm" 2>/dev/null)" in quickshell | qs | .quickshell-wra*) ;; *) continue ;; esac
        printf '\n## Оболочка (PID %s)\n\n' "${d#/proc/}"
        # Когда запущена и не старше ли её конфиг: после пересборки
        # home-manager перекладывает ссылки ~/.config/quickshell/pixel, и
        # замер старого процесса показал бы старый код.
        btime=$(awk '/^btime/ {print $2}' /proc/stat)
        ticks=$(getconf CLK_TCK 2>/dev/null || echo 100)
        started=$(($(awk '{print $22}' "$d/stat") / ticks + btime))
        printf -- '- запущена: %s\n' "$(date -d "@$started" '+%Y-%m-%d %H:%M')"
        cfg=${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/pixel/shell.qml
        if [ -L "$cfg" ] && [ "$(stat -c %Y "$cfg")" -gt "$started" ]; then
            printf -- '- **конфиг оболочки новее процесса** (обновлён %s): замер может быть по старому коду — systemctl --user restart pixel-shell\n' "$(date -d "@$(stat -c %Y "$cfg")" '+%Y-%m-%d %H:%M')"
        fi
        awk '/^(VmRSS|RssAnon|RssFile|RssShmem):/ {printf "- %s %.1f МиБ\n", $1, $2/1024}' "$d/status"
        awk '/^[0-9a-f]+-[0-9a-f]+ / {dri = ($6 ~ /^\/dev\/dri/ || $6 ~ /^\/memfd:/ || $6 ~ /dmabuf|anon_inode:dmabuf/)} /^Rss:/ && dri {k += $2} END {printf "- из них отображено GPU-буферов (/dev/dri, dmabuf, memfd): %.1f МиБ\n", k/1024}' "$d/smaps" 2>/dev/null
        printf -- '- потоков: %s; по именам:\n\n' "$(find "$d/task" -mindepth 1 -maxdepth 1 | wc -l)"
        for t in "$d"/task/*; do cat "$t/comm" 2>/dev/null; done | sed 's/[0-9]*$//' | sort | uniq -c | sort -rn | awk 'NR <= 12 {printf "  - %s × %d\n", $2, $1}'
        n=$(hyprctl layers -j 2>/dev/null | jq '[.. | objects | select(.namespace? and (.namespace | test("^pixel-shell|^quickshell")))] | length' 2>/dev/null)
        printf -- '- слоёв оболочки в Hyprland: %s\n' "${n:-?}"
        break
    done
    if [ "$(id -u)" -ne 0 ]; then
        printf '\nСнято без root: системные службы (Xwayland от root, демоны) не учтены — для полного замера: sudo pixel-metrics.\n'
    fi
} | tee "$out"
printf '\nСохранено: %s\n' "$out" >&2
