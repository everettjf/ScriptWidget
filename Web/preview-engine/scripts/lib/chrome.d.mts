// Types for chrome.mjs, the headless Chrome helper used by TypeScript scripts.
export interface ChromePage {
  call(method: string, params?: Record<string, unknown>): Promise<any>;
  evaluate<T = unknown>(expression: string): Promise<T>;
  consoleMessages: string[];
  onEvent<T = unknown>(method: string, handler: (params: T) => void): void;
  goto(url: string): Promise<void>;
  waitFor(expression: string, timeout?: number): Promise<true>;
  screenshot(clip?: { x: number; y: number; width: number; height: number }): Promise<Buffer>;
}

export interface Chrome {
  newPage(): Promise<ChromePage>;
  close(): Promise<void>;
}

export function findChrome(): string | null;
export function serveDirectory(directory: string, routes?: Record<string, { type: string; body: string | Uint8Array }>): Promise<{ origin: string; close(): void }>;
export function launchChrome(options?: { width?: number; height?: number; scale?: number; startupTimeoutMilliseconds?: number; callTimeoutMilliseconds?: number }): Promise<Chrome>;
