import type { WidgetSize } from "../types.js";

export type DeviceProfile = { label: string; platform?: "ios" | "macos" } & Partial<Record<WidgetSize, [number, number]>>;

export const deviceProfiles: Readonly<Record<string, DeviceProfile>>;
export const widgetFamilies: readonly WidgetSize[];
export function familiesFor(profile: string): WidgetSize[];
export function widgetSize(profile: string, family: WidgetSize): { width: number; height: number };
