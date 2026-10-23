export interface TimelineSchedule { dailyTimes: string[]; timeZone?: string | null }
export interface TimelinePlan { timeZone: string; entries: Array<{ date: string; slot: number; environments: Record<string, string> }>; reloadAfter: string }
export function validTimelineSchedule(schedule: unknown): boolean;
export function buildTimelinePlan(schedule?: TimelineSchedule | null, now?: Date, fallbackReload?: Date, systemTimeZone?: string): TimelinePlan;
