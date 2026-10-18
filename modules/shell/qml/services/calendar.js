.pragma library

// Календарь: повторения событий и .ics. Чистые функции без QML — их
// проверяет modules/shell/calendar-test.js (nix flake check).
//
// Время событий хранится как местное «настенное» время без пояса
// ("2026-10-18T10:00"): повтор «каждый день в 10:00» остаётся в 10:00 и
// после перехода на летнее/зимнее время — шаги считаются по календарю
// (setDate/setMonth), а не прибавлением часов.

// "2026-10-18T10:00" | "2026-10-18" → Date (местное время)
function parseLocal(s) {
    const m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?$/.exec(s || "");
    if (!m)
        return null;
    return new Date(+m[1], +m[2] - 1, +m[3], +(m[4] || 0), +(m[5] || 0), +(m[6] || 0));
}
function pad(n) {
    return String(n).padStart(2, "0");
}
function dateKey(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
}
function formatLocal(d, allDay) {
    return dateKey(d) + (allDay ? "" : "T" + pad(d.getHours()) + ":" + pad(d.getMinutes()));
}
function daysInMonth(y, m) {
    return new Date(y, m + 1, 0).getDate();
}
const DAYS = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];

// Вхождения события, пересекающие [from, to). Каждое: { ev, start, end }.
// rrule: { freq: daily|weekly|monthly|yearly, interval, count?, until?, byday? }
function occurrences(ev, from, to) {
    const start = parseLocal(ev.start);
    if (!start)
        return [];
    const end = parseLocal(ev.end) || new Date(start.getTime() + (ev.allDay ? 86400000 : 3600000));
    const dur = Math.max(0, end - start);
    const out = [];
    const ex = {};
    for (const e of ev.exdates || [])
        ex[e.slice(0, 10)] = true;
    const r = ev.rrule;
    const push = s => {
        const e = new Date(s.getTime() + dur);
        if (!ex[dateKey(s)] && e > from && s < to)
            out.push({
                ev,
                start: s,
                end: e
            });
    };
    if (!r || !r.freq) {
        push(start);
        return out;
    }
    const interval = Math.max(1, r.interval || 1);
    const until = r.until ? parseLocal(r.until.length === 10 ? r.until + "T23:59:59" : r.until) : null;
    const limit = r.count || Infinity;
    let n = 0;
    const accept = s => {
        if (until && s > until)
            return false;
        if (n >= limit)
            return false;
        n++;
        push(s);
        return true;
    };
    const at = (y, m, d) => new Date(y, m, d, start.getHours(), start.getMinutes(), start.getSeconds());
    // Без COUNT можно сразу перескочить к периоду перед `from`: у давних
    // ежедневных событий перебор с начала упёрся бы в лимит шагов
    let i0 = 0;
    if (!r.count && from > start) {
        const days = Math.floor((from - start) / 86400000);
        const months = (from.getFullYear() - start.getFullYear()) * 12 + from.getMonth() - start.getMonth();
        const per = {
            daily: days / interval,
            weekly: days / 7 / interval,
            monthly: months / interval,
            yearly: months / 12 / interval
        }[r.freq] || 0;
        i0 = Math.max(0, Math.floor(per) - 1);
    }
    // Защита от бесконечных циклов: не дальше `to` и не больше 5000 шагов
    for (let i = i0; i < i0 + 5000; i++) {
        let batch = [];
        if (r.freq === "daily") {
            batch = [at(start.getFullYear(), start.getMonth(), start.getDate() + i * interval)];
        } else if (r.freq === "weekly") {
            const days = (r.byday && r.byday.length ? r.byday : [DAYS[start.getDay()]]).map(d => DAYS.indexOf(d)).filter(d => d >= 0).sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7));
            // неделя с понедельника, в которой начало события
            const monday = start.getDate() - ((start.getDay() + 6) % 7) + i * 7 * interval;
            batch = days.map(d => at(start.getFullYear(), start.getMonth(), monday + ((d + 6) % 7))).filter(s => s >= start);
        } else if (r.freq === "monthly") {
            const y = start.getFullYear(), m = start.getMonth() + i * interval;
            const yy = y + Math.floor(m / 12), mm = ((m % 12) + 12) % 12;
            // 31-го в коротком месяце события нет (как в RFC 5545)
            if (start.getDate() <= daysInMonth(yy, mm))
                batch = [at(yy, mm, start.getDate())];
        } else if (r.freq === "yearly") {
            const yy = start.getFullYear() + i * interval;
            if (start.getDate() <= daysInMonth(yy, start.getMonth()))
                batch = [at(yy, start.getMonth(), start.getDate())];
        } else {
            break;
        }
        let stop = false;
        for (const s of batch) {
            if (s >= to || !accept(s)) {
                stop = true;
                break;
            }
        }
        if (stop)
            break;
    }
    return out;
}

// Все вхождения всех событий, по времени
function expand(events, from, to) {
    let out = [];
    for (const ev of events)
        out = out.concat(occurrences(ev, from, to));
    return out.sort((a, b) => a.start - b.start || (b.ev.allDay ? 1 : 0) - (a.ev.allDay ? 1 : 0));
}

// --- .ics ---------------------------------------------------------------------
function unescapeText(s) {
    return s.replace(/\\n/gi, "\n").replace(/\\([,;\\])/g, "$1");
}
function escapeText(s) {
    return String(s || "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/([,;])/g, "\\$1");
}
// Значение даты .ics → { local: "YYYY-MM-DDTHH:MM" | "YYYY-MM-DD", allDay }
// UTC (…Z) переводится в местное время; TZID пока считается местным.
function icsDate(params, value) {
    const v = value.trim();
    if (/VALUE=DATE(?!-)/i.test(params) || /^\d{8}$/.test(v))
        return {
            local: v.slice(0, 4) + "-" + v.slice(4, 6) + "-" + v.slice(6, 8),
            allDay: true
        };
    const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/.exec(v);
    if (!m)
        return null;
    const d = m[7] ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6])) : new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]);
    return {
        local: formatLocal(d, false),
        allDay: false
    };
}
function parseIcs(text) {
    // развернуть перенесённые строки
    const lines = text.replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "").split("\n");
    const events = [];
    let cur = null;
    for (const line of lines) {
        if (line === "BEGIN:VEVENT") {
            cur = {
                exdates: []
            };
            continue;
        }
        if (line === "END:VEVENT") {
            if (cur && cur.start)
                events.push({
                    id: cur.uid || "ics-" + Math.random().toString(36).slice(2),
                    title: cur.title || "Без названия",
                    start: cur.start,
                    end: cur.end || "",
                    allDay: !!cur.allDay,
                    rrule: cur.rrule || null,
                    exdates: cur.exdates,
                    location: cur.location || "",
                    notes: cur.notes || "",
                    remind: cur.remind !== undefined ? cur.remind : null
                });
            cur = null;
            continue;
        }
        if (!cur)
            continue;
        const colon = line.indexOf(":");
        if (colon < 0)
            continue;
        const head = line.slice(0, colon);
        const value = line.slice(colon + 1);
        const name = head.split(";")[0].toUpperCase();
        const params = head.slice(name.length);
        if (name === "UID")
            cur.uid = value;
        else if (name === "SUMMARY")
            cur.title = unescapeText(value);
        else if (name === "LOCATION")
            cur.location = unescapeText(value);
        else if (name === "DESCRIPTION")
            cur.notes = unescapeText(value);
        else if (name === "DTSTART") {
            const d = icsDate(params, value);
            if (d) {
                cur.start = d.local;
                cur.allDay = d.allDay;
            }
        } else if (name === "DTEND") {
            const d = icsDate(params, value);
            if (d)
                cur.end = d.local;
        } else if (name === "EXDATE") {
            for (const v of value.split(",")) {
                const d = icsDate(params, v);
                if (d)
                    cur.exdates.push(d.local.slice(0, 10));
            }
        } else if (name === "RRULE") {
            const kv = {};
            for (const part of value.split(";")) {
                const [k, v] = part.split("=");
                kv[(k || "").toUpperCase()] = v || "";
            }
            const freq = (kv.FREQ || "").toLowerCase();
            if (["daily", "weekly", "monthly", "yearly"].includes(freq)) {
                const u = kv.UNTIL ? icsDate("", kv.UNTIL) : null;
                cur.rrule = {
                    freq,
                    interval: parseInt(kv.INTERVAL) || 1,
                    count: parseInt(kv.COUNT) || 0,
                    until: u ? u.local : "",
                    byday: kv.BYDAY ? kv.BYDAY.split(",").map(d => d.replace(/^[+-]?\d+/, "")).filter(d => DAYS.includes(d)) : []
                };
            }
        } else if (name === "TRIGGER" && cur.remind === undefined) {
            // -PT15M / -PT1H / -P1D → минуты до начала
            const m = /^-P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?$/.exec(value.trim());
            if (m)
                cur.remind = (+(m[1] || 0)) * 1440 + (+(m[2] || 0)) * 60 + (+(m[3] || 0));
        }
    }
    return events;
}
function icsStamp(local, allDay) {
    return allDay ? "VALUE=DATE:" + local.slice(0, 10).replace(/-/g, "") : ":" + local.replace(/[-:]/g, "") + (local.length === 16 ? "00" : "");
}
function toIcs(events) {
    const out = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Pixel Shell//Календарь//RU"];
    for (const ev of events) {
        out.push("BEGIN:VEVENT", "UID:" + ev.id, "SUMMARY:" + escapeText(ev.title));
        out.push("DTSTART" + (ev.allDay ? ";" : "") + icsStamp(ev.start, ev.allDay));
        if (ev.end)
            out.push("DTEND" + (ev.allDay ? ";" : "") + icsStamp(ev.end, ev.allDay));
        if (ev.location)
            out.push("LOCATION:" + escapeText(ev.location));
        if (ev.notes)
            out.push("DESCRIPTION:" + escapeText(ev.notes));
        const r = ev.rrule;
        if (r && r.freq) {
            const parts = ["FREQ=" + r.freq.toUpperCase()];
            if (r.interval > 1)
                parts.push("INTERVAL=" + r.interval);
            if (r.count)
                parts.push("COUNT=" + r.count);
            if (r.until)
                parts.push("UNTIL=" + r.until.replace(/[-:]/g, "") + (r.until.length === 10 ? "" : "00"));
            if (r.byday && r.byday.length)
                parts.push("BYDAY=" + r.byday.join(","));
            out.push("RRULE:" + parts.join(";"));
        }
        for (const x of ev.exdates || [])
            out.push(ev.allDay ? "EXDATE;VALUE=DATE:" + x.replace(/-/g, "") : "EXDATE:" + x.replace(/-/g, "") + "T" + ev.start.slice(11, 16).replace(":", "") + "00");
        if (ev.remind !== null && ev.remind !== undefined)
            out.push("BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:" + escapeText(ev.title), "TRIGGER:-PT" + ev.remind + "M", "END:VALARM");
        out.push("END:VEVENT");
    }
    out.push("END:VCALENDAR");
    return out.join("\r\n") + "\r\n";
}

// Напоминания на ближайшие дни для службы pixel-reminders:
// [{ id, at (секунды Unix), title, when }]
function reminders(events, now, days) {
    const to = new Date(now.getTime() + days * 86400000);
    const out = [];
    for (const o of expand(events.filter(e => e.remind !== null && e.remind !== undefined), new Date(now.getTime() - 86400000), to)) {
        const at = new Date(o.start.getTime() - o.ev.remind * 60000);
        out.push({
            id: o.ev.id + "@" + formatLocal(o.start, o.ev.allDay),
            at: Math.floor(at.getTime() / 1000),
            title: o.ev.title,
            when: o.ev.allDay ? dateKey(o.start) : formatLocal(o.start, false).replace("T", " ")
        });
    }
    return out;
}
