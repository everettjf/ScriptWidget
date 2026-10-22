// Opt-in capacity study. Real preferences, printable deterministic values,
// separate writer/reader processes, and only a disposable named suite.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
import { randomUUID } from "node:crypto";
const exec = promisify(execFile);
const root = await mkdtemp(join(tmpdir(), "scriptwidget-capacity-"));
const binary = join(root, "probe");
const domain = `app.scriptwidget.capacity.probe.${randomUUID()}`;
const output = resolve(process.argv[2] ?? "__Release/capabilities/storage-capacity/macos-processes.json");
const results = [];
try {
  await exec("xcrun", ["swiftc", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageLock.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageNamespaces.swift", "Tools/StorageAtomicProbe/main.swift", "-o", binary], { timeout: 60000 });
  for (const mode of ["capacity-write", "capacity-read"]) {
    const { stdout } = await exec(binary, [mode, root, domain, "4"], { timeout: 60000, maxBuffer: 1024 * 1024 });
    results.push(JSON.parse(stdout));
  }
  await mkdir(resolve(output, ".."), { recursive: true });
  await writeFile(output, JSON.stringify({ independentProcesses: true, signedAppGroup: false, results }, null, 2) + "\n");
  for (const result of results) console.log(`${result.mode}: ${result.valuesVerified}/32 values; p95 ${result.p95Milliseconds.toFixed(2)} ms; passed=${result.passed}`);
  if (results.some((value) => !value.passed)) throw new Error(`Capacity study detected a failure; evidence saved to ${output}`);
} finally {
  try { await exec(binary, ["reset", root, domain, "0"]); } finally { await rm(root, { recursive: true, force: true }); }
}
