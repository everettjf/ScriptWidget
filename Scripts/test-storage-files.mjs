// Real files; independent processes and abrupt exits; disposable root only.
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { access, mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { setTimeout as delay } from "node:timers/promises";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";
const exec = promisify(execFile);
const root = await mkdtemp(join(tmpdir(), "scriptwidget-storage-files-"));
const binary = join(root, "probe");
const output = resolve(process.argv[2] ?? "__Release/capabilities/storage-files/macos-processes.json");
const running = new Set();
function run(mode, value = 0) {
  const child = exec(binary, [mode, root, String(value)], { timeout: 60000, maxBuffer: 1024 * 1024 });
  running.add(child);
  child.then(() => running.delete(child), () => running.delete(child));
  return child;
}
async function waitForMarker(name) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    try { await access(join(root, name)); return; }
    catch (error) { if (error.code !== "ENOENT") throw error; }
    await delay(10);
  }
  throw new Error(`Storage probe marker timed out: ${name}`);
}
async function expectIntegrityFailure(operationStarted) {
  let rejected = false;
  try { await run("increment", 1); }
  catch (error) {
    const diagnostic = JSON.parse(error.stderr);
    if (error.code !== 3 || diagnostic.reason !== "transaction-failed" || diagnostic.committed !== 0 ||
        diagnostic.lockRejections !== 0 || diagnostic.operationStarted !== operationStarted) throw error;
    rejected = true;
  }
  if (!rejected) throw new Error("Corrupt state must fail without retrying");
}
const results = [];
try {
  await exec("xcrun", ["swiftc", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageLock.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageNamespaces.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageFiles.swift", "Tools/StorageFileProbe/main.swift", "-o", binary], { timeout: 60000 });
  for (const mode of ["capacity-write", "capacity-read"]) {
    const { stdout } = await run(mode);
    results.push(JSON.parse(stdout));
  }
  await run("reset-counter");
  const holder = run("hold-counter-lock", 10000);
  await waitForMarker("counter-lock-held");
  results.push(JSON.parse((await run("expect-lock-rejection")).stdout));
  const workers = Promise.allSettled(Array.from({ length: 4 }, () => run("increment", 100)));
  await Promise.race([
    waitForMarker("contention-observed"),
    workers.then(() => { throw new Error("Workers ended before the held-lock rejection was observed"); }),
  ]);
  await writeFile(join(root, "release-counter-lock"), "");
  const completed = await workers;
  await holder;
  const failed = completed.filter((result) => result.status === "rejected");
  if (failed.length) throw new AggregateError(failed.map((result) => result.reason), "Storage increment workers failed");
  const reports = completed.map((result) => JSON.parse(result.value.stdout));
  if (reports.some((report) => report.committed !== 100) || !reports.some((report) => report.lockRejections > 0)) {
    throw new Error("The counter probe must commit every increment and observe real lock rejection");
  }
  results.push({ mode: "concurrent-increment", passed: true, workers: reports.length, committed: 400,
    lockRejections: reports.reduce((total, report) => total + report.lockRejections, 0) });
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
  await run("break-counter-mirror");
  await expectIntegrityFailure(true);
  results.push({ ...JSON.parse((await run("read-broken-counter")).stdout), mode: "corruption-rejected", retries: 0 });
  await run("break-record-file");
  await expectIntegrityFailure(false);
  results.push({ ...JSON.parse((await run("read-broken-record-file")).stdout), mode: "corrupt-file-rejected", retries: 0 });
  if (results.some((value) => !value.passed)) throw new Error("Storage file probe detected a failure");
  await mkdir(resolve(output, ".."), { recursive: true });
  await writeFile(output, JSON.stringify({ independentProcesses: true, signedAppGroup: false, widgetExtension: false, results }, null, 2) + "\n");
  for (const result of results) console.log(`${result.mode}: passed=${result.passed}${result.valuesVerified ? `; ${result.valuesVerified}/32 values; p95 ${result.p95Milliseconds.toFixed(2)} ms` : ""}`);
} finally {
  // A rejected worker must not remove files underneath its still-live peers.
  await writeFile(join(root, "release-counter-lock"), "").catch(() => {});
  await Promise.allSettled([...running]);
  await rm(root, { recursive: true, force: true });
}
