import { timelineZoneIdentifiers } from "./timeZones.js";
const timelineZones = new Set(timelineZoneIdentifiers);
// Pure host-side planning. Never executes package code or changes Date globals.
export function validTimelineSchedule(schedule) {
  if (!schedule || typeof schedule !== "object" || Array.isArray(schedule) || Object.keys(schedule).some((key) => !["dailyTimes", "timeZone"].includes(key))) return false;
  const times = schedule.dailyTimes;
  if (!Array.isArray(times) || times.length < 1 || times.length > 4 || new Set(times).size !== times.length ||
      times.some((time, index) => typeof time !== "string" || !/^(?:[01][0-9]|2[0-3]):[0-5][0-9]$/.test(time) || (index > 0 && times[index - 1] >= time))) return false;
  if (schedule.timeZone !== undefined && schedule.timeZone !== null) {
    if (typeof schedule.timeZone !== "string" || !timelineZones.has(schedule.timeZone)) return false;
    try { new Intl.DateTimeFormat("en", { timeZone: schedule.timeZone }); } catch { return false; }
  }
  return true;
}

const timelineCache = new Map();
export function buildTimelinePlan(schedule, now = new Date(), fallbackReload = new Date(now.getTime() + 3_600_000), systemTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone) {
  if (!(now instanceof Date) || !Number.isFinite(now.getTime()) || !Number.isFinite(fallbackReload.getTime())) throw new Error("Invalid timeline date");
  const active = schedule != null && validTimelineSchedule(schedule);
  if (schedule != null && !active) throw new Error("Invalid timeline schedule");
  const timeZone = schedule?.timeZone ?? systemTimeZone;
  const format = new Intl.DateTimeFormat("en-GB-u-ca-gregory-nu-latn", { timeZone, year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" });
  const parts = (date) => Object.fromEntries(format.formatToParts(date).filter((part) => ["year", "month", "day", "hour", "minute"].includes(part.type)).map((part) => [part.type, Number(part.value)]));
  const local = parts(now);
  const dateKey = (value) => `${value.year}-${value.month}-${value.day}`;
  let ordered = [];
  if (active) {
    const cacheKey = JSON.stringify([timeZone, dateKey(local), schedule.dailyTimes]);
    ordered = timelineCache.get(cacheKey);
    if (!ordered) {
      const localDayUTC = new Date(0);
      localDayUTC.setUTCFullYear(local.year, local.month - 1, local.day);
      localDayUTC.setUTCHours(0, 0, 0, 0);
      const dates = new Set(Array.from({ length: 4 }, (_, index) => {
        const value = new Date(localDayUTC.getTime() + (index - 1) * 86_400_000);
        return dateKey({ year: value.getUTCFullYear(), month: value.getUTCMonth() + 1, day: value.getUTCDate() });
      }));
      const minutes = schedule.dailyTimes.map((time) => Number(time.slice(0, 2)) * 60 + Number(time.slice(3)));
      const selected = new Map();
      // UTC stepping handles repeated hours and non-hour offsets. Pick the
      // first local occurrence; gaps advance to the next valid wall minute.
      for (let stamp = localDayUTC.getTime() - 2 * 86_400_000; stamp <= localDayUTC.getTime() + 4 * 86_400_000; stamp += 60_000) {
        const value = parts(new Date(stamp));
        const day = dateKey(value);
        if (!dates.has(day)) continue;
        const minute = value.hour * 60 + value.minute;
        for (let slot = 0; slot < minutes.length; slot++) {
          const key = `${day}:${slot}`;
          if (minute >= minutes[slot] && !selected.has(key)) selected.set(key, { stamp, slot });
        }
      }
      const collapsed = new Map();
      for (const entry of selected.values()) collapsed.set(entry.stamp, Math.max(collapsed.get(entry.stamp) ?? -1, entry.slot));
      ordered = [...collapsed].sort((a, b) => a[0] - b[0]);
      if (timelineCache.size >= 16) timelineCache.delete(timelineCache.keys().next().value);
      timelineCache.set(cacheKey, ordered);
    }
  }
  const horizon = now.getTime() + 86_400_000;
  const slot = ordered.filter(([stamp]) => stamp <= now.getTime()).at(-1)?.[1] ?? (active ? schedule.dailyTimes.length - 1 : -1);
  const future = ordered.filter(([stamp]) => stamp > now.getTime() && stamp <= horizon);
  const projected = future.slice(0, 4);
  const entry = (date, index, projection) => ({ date: date.toISOString(), slot: index, environments: {
    "timeline-date": date.toISOString(), "timeline-time-zone": timeZone, "timeline-slot": String(index), "timeline-is-projection": String(projection),
  } });
  return {
    timeZone,
    entries: [entry(now, slot, false), ...projected.map(([stamp, index]) => entry(new Date(stamp), index, true))],
    reloadAfter: new Date(Math.max(now.getTime() + 60_000, Math.min(fallbackReload.getTime(), active ? horizon : Infinity, future.length > projected.length ? projected.at(-1)[0] : horizon))).toISOString(),
  };
}
