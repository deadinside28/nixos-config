// Проверка календаря (modules/shell/qml/services/calendar.js): повторения,
// исключения, переход на летнее время, .ics туда и обратно, напоминания.
//   TZ=Europe/Berlin node modules/shell/calendar-test.js modules/shell/qml/services/calendar.js
"use strict";
const fs = require("fs");
const src = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*$/m, "");
const Cal = new Function(src + "\nreturn { parseLocal, dateKey, formatLocal, occurrences, expand, parseIcs, toIcs, reminders };")();

let passed = 0, failed = 0;
function check(name, ok) {
    if (ok)
        passed++;
    else {
        failed++;
        console.error("FAIL: " + name);
    }
}
const D = s => Cal.parseLocal(s);
const keys = list => list.map(o => Cal.formatLocal(o.start, o.ev.allDay));

// Ежедневно через переход на зимнее время (Берлин, 25.10.2026): 10:00 остаётся 10:00
const daily = { id: "d", title: "Утро", start: "2026-10-24T10:00", end: "2026-10-24T10:30", rrule: { freq: "daily" } };
let o = Cal.occurrences(daily, D("2026-10-24"), D("2026-10-27"));
check("ежедневно: три дня", o.length === 3);
check("ежедневно: настенное время после перехода не съехало", keys(o).join() === "2026-10-24T10:00,2026-10-25T10:00,2026-10-26T10:00");
check("длительность сохраняется", o.every(x => x.end - x.start === 30 * 60000));

// Исключение даты и COUNT
const counted = Object.assign({}, daily, { rrule: { freq: "daily", count: 3 }, exdates: ["2026-10-25"] });
o = Cal.occurrences(counted, D("2026-10-01"), D("2026-12-01"));
check("COUNT считает и исключённые, EXDATE пропускает", keys(o).join() === "2026-10-24T10:00,2026-10-26T10:00");

// Еженедельно по пн и ср, каждые 2 недели, до даты
const weekly = { id: "w", title: "Спорт", start: "2026-10-19T19:00", rrule: { freq: "weekly", interval: 2, byday: ["MO", "WE"], until: "2026-11-05" } };
o = Cal.occurrences(weekly, D("2026-10-01"), D("2026-12-31"));
check("еженедельно по дням с интервалом и UNTIL", keys(o).join() === "2026-10-19T19:00,2026-10-21T19:00,2026-11-02T19:00,2026-11-04T19:00");

// Ежемесячно 31-го: в коротких месяцах нет
const monthly = { id: "m", title: "Отчёт", start: "2026-01-31", allDay: true, rrule: { freq: "monthly" } };
o = Cal.occurrences(monthly, D("2026-01-01"), D("2026-06-01"));
check("31-е число только в длинных месяцах", keys(o).join() === "2026-01-31,2026-03-31,2026-05-31");

// Ежегодно 29 февраля
const leap = { id: "y", title: "ДР", start: "2024-02-29", allDay: true, rrule: { freq: "yearly" } };
o = Cal.occurrences(leap, D("2024-01-01"), D("2029-01-01"));
check("29 февраля только в високосные", keys(o).join() === "2024-02-29,2028-02-29");

// Давнее ежедневное событие без COUNT не упирается в лимит шагов
const old = { id: "o", title: "Давно", start: "2000-01-01T08:00", rrule: { freq: "daily" } };
o = Cal.occurrences(old, D("2026-10-18"), D("2026-10-19"));
check("давнее ежедневное событие находится", keys(o).join() === "2026-10-18T08:00");

// Однократное, пересекающее начало диапазона
o = Cal.occurrences({ id: "s", title: "Ночь", start: "2026-10-17T23:00", end: "2026-10-18T01:00" }, D("2026-10-18"), D("2026-10-19"));
check("событие через полночь попадает в следующий день", o.length === 1);

// .ics: разбор
const ics = [
    "BEGIN:VCALENDAR", "BEGIN:VEVENT", "UID:abc", "SUMMARY:Встреча\\, важная", "DTSTART:20261020T090000",
    "DTEND:20261020T100000", "RRULE:FREQ=WEEKLY;COUNT=2;BYDAY=TU", "EXDATE:20261027T090000",
    "DESCRIPTION:строка1\\nстрока2", "BEGIN:VALARM", "TRIGGER:-PT15M", "END:VALARM", "END:VEVENT",
    "BEGIN:VEVENT", "UID:all", "SUMMARY:Отпуск", "DTSTART;VALUE=DATE:20261101", "DTEND;VALUE=DATE:20261103", "END:VEVENT",
    "BEGIN:VEVENT", "UID:utc", "SUMMARY:По UTC", "DTSTART:20261020T120000Z", "END:VEVENT",
    "END:VCALENDAR"
].join("\r\n");
const parsed = Cal.parseIcs(ics);
check(".ics: три события", parsed.length === 3);
check(".ics: экранирование и перевод строки", parsed[0].title === "Встреча, важная" && parsed[0].notes === "строка1\nстрока2");
check(".ics: повтор, исключение, напоминание", parsed[0].rrule.freq === "weekly" && parsed[0].rrule.count === 2 && parsed[0].exdates[0] === "2026-10-27" && parsed[0].remind === 15);
check(".ics: событие на весь день", parsed[1].allDay && parsed[1].start === "2026-11-01" && parsed[1].end === "2026-11-03");
check(".ics: UTC переведено в местное (Берлин, летнее +2)", parsed[2].start === "2026-10-20T14:00");

// .ics: туда и обратно
const back = Cal.parseIcs(Cal.toIcs([parsed[0], parsed[1], weekly]));
check(".ics туда-обратно: поля", back[0].title === parsed[0].title && back[0].start === parsed[0].start && back[0].rrule.byday.join() === "TU" && back[0].exdates[0] === "2026-10-27" && back[0].remind === 15);
check(".ics туда-обратно: весь день", back[1].allDay && back[1].start === "2026-11-01");
check(".ics туда-обратно: UNTIL и интервал", back[2].rrule.interval === 2 && back[2].rrule.until.startsWith("2026-11-05"));

// Напоминания
const rem = Cal.reminders([Object.assign({}, daily, { remind: 10 })], D("2026-10-24T09:00"), 2);
check("напоминания: за 10 минут, по вхождениям", rem.length >= 2 && rem[0].at === Math.floor(D("2026-10-24T09:50") / 1000) && rem[0].id === "d@2026-10-24T10:00");
check("без напоминания — ничего", Cal.reminders([daily], D("2026-10-24T09:00"), 2).length === 0);

console.log("calendar: " + passed + " проверок пройдено, " + failed + " провалено");
process.exit(failed ? 1 : 0);
