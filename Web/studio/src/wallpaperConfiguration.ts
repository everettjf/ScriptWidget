import type { PackageFiles } from "../../preview-engine/src/types.js";
import type { WallpaperFamily } from "./wallpaperCrop.ts";

export const wallpaperConfigurationPath = "wallpaper.json";
export const wallpaperFamilies: WallpaperFamily[] = ["small", "medium", "large", "extraLarge", "extraLargePortrait"];
export interface WallpaperAsset { family: WallpaperFamily; appearance: "light" | "dark"; image: string; label: string }
export interface WallpaperConfiguration {
  title: string; caption: string; content: "none" | "text" | "date"; ink: "adaptive" | "light" | "dark"; backgrounds: WallpaperAsset[];
}
export const wallpaperImagePattern = /^image\/background-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.png$/;
export const defaultWallpaperConfiguration = (): WallpaperConfiguration => ({ title: "My space", caption: "", content: "none", ink: "adaptive", backgrounds: [] });
const object = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value);
const keys = (value: Record<string, unknown>, expected: string) => Object.keys(value).sort().join(",") === expected;
const text = (value: unknown, limit: number): value is string => typeof value === "string" && value.length <= limit;

export function isWallpaperTemplate(files: PackageFiles): boolean {
  try {
    const raw = files["record-template.json"];
    if (typeof raw !== "string") return false;
    const descriptor: unknown = JSON.parse(raw);
    return object(descriptor) && keys(descriptor, "formatVersion,kind") && descriptor.formatVersion === 1 && descriptor.kind === "wallpaper";
  } catch { return false; }
}

export function validateWallpaperConfiguration(value: unknown): asserts value is WallpaperConfiguration {
  if (!object(value) || !keys(value, "backgrounds,caption,content,ink,title")
    || !text(value.title, 40) || !text(value.caption, 80)
    || !["none", "text", "date"].includes(value.content as string) || !["adaptive", "light", "dark"].includes(value.ink as string)
    || !Array.isArray(value.backgrounds) || value.backgrounds.length > 10) throw new Error("Invalid wallpaper title, caption, styles or selections.");
  const seen = new Set<string>();
  for (const item of value.backgrounds) {
    if (!object(item) || !keys(item, "appearance,family,image,label") || !wallpaperFamilies.includes(item.family as WallpaperFamily)
      || !["light", "dark"].includes(item.appearance as string) || typeof item.image !== "string"
      || !wallpaperImagePattern.test(`image/${item.image}.png`) || !text(item.label, 30) || !item.label.trim() || /[\p{Cc}\p{Cf}]/u.test(item.label)) {
      throw new Error("Choose a valid local crop, position label, size and appearance.");
    }
    const slot = `${item.family}.${item.appearance}`;
    if (seen.has(slot)) throw new Error("Each size and appearance can have only one crop.");
    seen.add(slot);
  }
}

export function readWallpaperConfiguration(files: PackageFiles): WallpaperConfiguration {
  const raw = files[wallpaperConfigurationPath];
  if (raw === undefined) return defaultWallpaperConfiguration();
  const encoded = typeof raw === "string" ? new TextEncoder().encode(raw) : raw;
  if (encoded.byteLength > 4096) throw new Error("wallpaper.json must be at most 4096 UTF-8 bytes.");
  const parsed: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(encoded));
  if (!object(parsed) || !keys(parsed, "kind,values,version") || parsed.version !== 1 || parsed.kind !== "wallpaper") throw new Error("Invalid wallpaper.json envelope.");
  validateWallpaperConfiguration(parsed.values);
  return parsed.values;
}

export function serializeWallpaperConfiguration(values: WallpaperConfiguration): string {
  validateWallpaperConfiguration(values);
  const raw = `${JSON.stringify({ version: 1, kind: "wallpaper", values })}\n`;
  if (new TextEncoder().encode(raw).length > 4096) throw new Error("Wallpaper settings exceed 4096 UTF-8 bytes. Shorten the labels or caption.");
  return raw;
}
