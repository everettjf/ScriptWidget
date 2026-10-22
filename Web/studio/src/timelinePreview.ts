import type { TimelinePlan } from "../../preview-engine/src/timeline.js";
import { buildTimelinePlan } from "../../preview-engine/src/timeline.js";
import type { WidgetManifest } from "../../preview-engine/src/types.js";

export function timelinePreview(manifest: WidgetManifest | null | undefined, fixedDate = "", now = new Date()): { plan: TimelinePlan; environments: Record<string, string> } {
  const date = fixedDate ? new Date(fixedDate) : now;
  if (!Number.isFinite(date.getTime())) throw new Error("Choose a valid timeline date.");
  const plan = buildTimelinePlan(manifest?.timeline, date);
  return { plan, environments: { ...plan.entries[0]!.environments, "timeline-is-projection": fixedDate ? "true" : "false" } };
}

export function timelineInputValue(date: string) {
  if (!date) return "";
  const value = new Date(date);
  if (!Number.isFinite(value.getTime())) return "";
  const pad = (number: number) => String(number).padStart(2, "0");
  return `${value.getFullYear()}-${pad(value.getMonth()+1)}-${pad(value.getDate())}T${pad(value.getHours())}:${pad(value.getMinutes())}`;
}
