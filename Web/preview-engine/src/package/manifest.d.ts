import type { Permission, ValidationReport, WidgetFamilyName, WidgetManifest } from "../types.js";

export const runtimeAPIVersion: string;
export const families: WidgetFamilyName[];
export const permissions: Permission[];
export function decodeManifest(text: string): { manifest: WidgetManifest; error?: undefined } | { manifest?: undefined; error: string };
export function newManifest(name: string, metadata?: Record<string, unknown>): WidgetManifest;
export function legacyManifest(name: string, metadata?: Record<string, unknown>): WidgetManifest;
export function validateManifest(manifest: WidgetManifest, paths: string[], options?: { checkEntryExists?: boolean }): ValidationReport;

export function supportsMinimumRuntime(minimum: string, current?: string): boolean;

export function validPackageName(name: unknown): boolean;
