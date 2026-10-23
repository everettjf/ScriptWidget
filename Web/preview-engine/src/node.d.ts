import type { ExecuteJob } from "./browser/client.js";
import type { ExecutionResult, PackageFiles } from "./types.js";
export interface NodeExecuteJob extends ExecuteJob {
  device?: Record<string, unknown>;
  system?: Record<string, unknown>;
  storage?: Record<string, unknown>;
  timeZone?: string;
}
export function executePackageInNode(job: NodeExecuteJob): Promise<ExecutionResult>;

export function readPackageDirectory(directory: string): PackageFiles;
export function readPackageResources(directory: string): Record<string, string>;
