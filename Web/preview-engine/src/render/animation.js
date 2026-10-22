// Matches ScriptWidgetAnimationPhase. These are display-only calculations.
export const clockPeriods = Object.freeze({ clockSecond: 60, clockMinute: 3600, clockMiniute: 3600, clockHour: 43200 });
export const clockPeriod = value => Number.isFinite(value) ? (Math.abs(value) < 0.25 ? (value < 0 ? -0.25 : 0.25) : value) : 10;
export const swingDuration = value => Number.isFinite(value) && value > 0 ? Math.min(86400, Math.max(0.1, value)) : 1;
export const swingDistance = value => Number.isFinite(value) ? Math.min(10000, Math.max(-10000, value)) : 10;
export function swingPhase(elapsed, duration, distance) {
  if (!Number.isFinite(elapsed)) return 0;
  const period = swingDuration(duration);
  return Math.sin(elapsed % (2 * period) / period * Math.PI) * swingDistance(distance);
}
export function clockPhase({ type, interval = 10, date, timezone = "current" }) {
  if (!Number.isFinite(date) || date < -62135596800000 || date > 253402300799000) return 0;
  const moment = new Date(date), options = { year: "numeric", month: "numeric", day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", hourCycle: "h23", calendar: "gregory", numberingSystem: "latn" };
  let parts;
  try { parts = new Intl.DateTimeFormat("en-US", timezone === "current" ? options : { ...options, timeZone: timezone }).formatToParts(moment); }
  catch { parts = new Intl.DateTimeFormat("en-US", options).formatToParts(moment); }
  const get = key => Number(parts.find(part => part.type === key)?.value ?? 0);
  if (type === "clock") {
    const local = new Date(0); local.setUTCFullYear(get("year"), get("month") - 1, get("day"));
    local.setUTCHours(get("hour"), get("minute"), get("second"), moment.getUTCMilliseconds());
    return ((local.getTime() / 1000 - 978307200) / clockPeriod(interval)) % 2 * 180;
  }
  const cycle = clockPeriods[type]; if (!cycle) return 0;
  const seconds = get("hour") * 3600 + get("minute") * 60 + get("second") + moment.getUTCMilliseconds() / 1000;
  return seconds % cycle / cycle * 360;
}
