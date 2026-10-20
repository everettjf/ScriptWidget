import type { ExecuteJob } from "./browser/client.js";
import type { ExecutionResult } from "./types.js";
export interface NodeExecuteJob extends ExecuteJob {
  device?: Record<string, unknown>;
  system?: Record<string, unknown>;
  storage?: Record<string, unknown>;
  timeZone?: string;
}
export function executePackageInNode(job: NodeExecuteJob): Promise<ExecutionResult>;
