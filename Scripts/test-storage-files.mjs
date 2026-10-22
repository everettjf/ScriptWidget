// Real files; independent processes and abrupt exits; disposable root only.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
const exec = promisify(execFile);
const root = await mkdtemp(join(tmpdir(), "scriptwidget-storage-files-"));
const binary = join(root, "probe");
const output = resolve(process.argv[2] ?? "__Release/capabilities/storage-files/macos-processes.json");
async function run(mode, value = 0) {
  return exec(binary, [mode, root, String(value)], { timeout: 60000, maxBuffer: 1024 * 1024 });
}
const results = [];
try {
  await exec("xcrun", ["swiftc", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageLock.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageNamespaces.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageFiles.swift", "Tools/StorageFileProbe/main.swift", "-o", binary], { timeout: 60000 });
  for (const mode of ["capacity-write", "capacity-read"]) {
    const { stdout } = await run(mode);
    results.push(JSON.parse(stdout));
  }
  await run("reset-counter");
  await Promise.all(Array.from({ length: 4 }, () => run("increment", 100)));
  results.push(JSON.parse((await run("read-counter", 400)).stdout));
  for (const [mode, expected] of [["crash-before", 400], ["crash-after", 999]]) {
    let crashed = false;
    try { await run(mode, 999); } catch (error) {
      if (error.code !== 86) throw error;
      crashed = true;
    }
    if (!crashed) throw new Error("Expected abrupt exit was not observed");
    const reader = JSON.parse((await run("read-counter", expected)).stdout);
    results.push({ ...reader, mode, exitCode: 86 });
  }
  if (results.some((value) => !value.passed)) throw new Error("Storage file probe detected a failure");
  await mkdir(resolve(output, ".."), { recursive: true });
  await writeFile(output, JSON.stringify({ independentProcesses: true, signedAppGroup: false, widgetExtension: false, results }, null, 2) + "\n");
  for (const result of results) console.log(`${result.mode}: passed=${result.passed}${result.valuesVerified ? `; ${result.valuesVerified}/32 values; p95 ${result.p95Milliseconds.toFixed(2)} ms` : ""}`);
} finally {
  await rm(root, { recursive: true, force: true });
}
