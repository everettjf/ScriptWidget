import type { Appearance, ExecutionResult, WidgetManifest } from "../types.js";

export interface ExecuteJob {
  files: Record<string, string>;
  entry?: string;
  manifest?: WidgetManifest | null;
  environments?: Record<string, string>;
  preview?: { appearance: Appearance };
  fixtures?: unknown;
  prelude?: string;
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
}): PreviewSandbox;
