import type { Appearance, ExecutionResult, WidgetManifest, PackageFiles } from "../types.js";

export interface ExecuteJob {
  files: PackageFiles;
  entry?: string;
  manifest?: WidgetManifest | null;
  environments?: Record<string, string>;
  preview?: { appearance: Appearance };
  fixtures?: unknown;
  prelude?: string;
  /// Run a declared action against preview data only.
  actionID?: string | null;
  timeoutMilliseconds?: number;
}

export interface PreviewSandbox {
  ready: Promise<void>;
  execute(job: ExecuteJob): Promise<ExecutionResult>;
  destroy(): void;
}

export function createPreviewSandbox(options: {
  sandboxDocument?: string;
  sandboxURL?: string;
  assetBaseURL: URL | string;
  container?: HTMLElement;
  onLog?: (level: string, message: string) => void;
  startupTimeoutMilliseconds?: number;
  /// How long a loaded frame may stay silent before it counts as blocked.
  blockedFrameMilliseconds?: number;
}): PreviewSandbox;
