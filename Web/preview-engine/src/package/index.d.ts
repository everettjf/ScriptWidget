import type { PackageFiles, ValidationReport, WidgetManifest } from "../types.js";

export * from "./manifest.js";
export * from "./archive.js";

export function classifyFiles(files: Record<string, Uint8Array>): PackageFiles;
export function importPackage(bytes: Uint8Array, options?: { inflate?: (bytes: Uint8Array) => Promise<Uint8Array> }): Promise<
  | { error: string; report?: ValidationReport; manifest?: undefined; files?: undefined }
  | { manifest: WidgetManifest; files: PackageFiles; report: ValidationReport; error?: undefined }
>;
export function exportPackage(files: PackageFiles): 
  | { error: string; report?: ValidationReport; bytes?: undefined }
  | { bytes: Uint8Array; fileName: string; manifest: WidgetManifest; report: ValidationReport; error?: undefined };
export function newProjectFiles(name: string, source?: string): Record<string, string>;
