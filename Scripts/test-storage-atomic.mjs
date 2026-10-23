// Actual independent processes, a simultaneous start barrier, and a negative
// control. Compiles the same coordinator linked into the app and extensions.
import { execFile, spawn } from "node:child_process";
import { promisify } from "node:util";
import { mkdtemp, mkdir, rm, readdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";
const exec = promisify(execFile);
const root = await mkdtemp(join(tmpdir(), "scriptwidget-atomic-"));
const binary = join(root, "probe");
const source = fileURLToPath(new URL("../Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageLock.swift", import.meta.url));
const namespaces = fileURLToPath(new URL("../Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetStorageNamespaces.swift", import.meta.url));
const probe = fileURLToPath(new URL("../Tools/StorageAtomicProbe/main.swift", import.meta.url));
const domain = `app.scriptwidget.atomic.probe.${randomUUID()}`;
const activeWorkers = new Set();
let failed = false;
try {
  await exec("xcrun", ["swiftc", source, namespaces, probe, "-o", binary], { timeout: 60000 });
  for (const mode of ["increment", "increment-unsafe", "increment-namespaced", "publication-race"]) {
    const runRoot = join(root, mode);
    await mkdir(runRoot);
    const reset = mode === "publication-race" ? "publication-race-reset" : mode === "increment-namespaced" ? "reset-namespaced" : "reset";
    await exec(binary, [reset, runRoot, domain, "0"]);
    const workers = Array.from({ length: 8 }, () => spawn(binary, [mode, runRoot, domain, "50"], { stdio: "inherit", signal: AbortSignal.timeout(30000) }));
    const completion = Promise.all(workers.map((worker) => new Promise((resolve, reject) => {
      activeWorkers.add(worker);
      worker.once("exit", () => activeWorkers.delete(worker));
      worker.on("error", reject);
      worker.on("exit", (code) => code === 0 ? resolve() : reject(new Error(`Probe exited ${code}`)));
    })));
    // Observe early failures while the parent is still awaiting the barrier.
    completion.catch(() => {});
    const deadline = Date.now() + 10000;
    while ((await readdir(runRoot)).filter((name) => name.startsWith("ready-")).length < workers.length) {
      if (Date.now() > deadline) throw new Error("Workers did not reach the start barrier");
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    await writeFile(join(runRoot, "start"), "");
    await completion;
    if (mode === "publication-race") {
      const outcomes = await Promise.all((await readdir(runRoot)).filter((name) => name.startsWith("publication-")).map((name) => readFile(join(runRoot, name), "utf8")));
      const isolation = (await exec(binary, ["read-publication-race", runRoot, domain, "0"])).stdout.trim();
      if (outcomes.length !== 8 || outcomes.filter((value) => value.startsWith("committed:")).length !== 1 || isolation !== "isolated") {
        throw new Error(`Publication race created duplicate owners or inherited old records: ${JSON.stringify(outcomes)}`);
      }
      console.log("✓ publication race: one of eight publishers committed, no overwrite or old-record inheritance");
      continue;
    }
    if (mode === "increment-namespaced") {
      const result = JSON.parse((await exec(binary, ["read-namespaced", runRoot, domain, "0"])).stdout);
      const owners = await Promise.all((await readdir(runRoot)).filter((name) => name.startsWith("owner-")).map((name) => readFile(join(runRoot, name), "utf8")));
      if (result.count !== 400 || result.owners !== 10 || result.workerValues !== 8 || result.legacy !== "0" || owners.length !== 8 || new Set(owners).size !== 1) {
        throw new Error(`Namespace migration lost identity, data, or isolation: ${JSON.stringify(result)}`);
      }
      console.log("✓ namespaced migration: 400/400 updates, one counter identity, eight private owners, legacy preserved");
      continue;
    }
    const actual = Number((await exec(binary, ["read", runRoot, domain, "0"])).stdout.trim());
    if (mode === "increment" && actual !== 400) throw new Error(`Lost updates: ${actual}/400`);
    if (mode === "increment-unsafe" && actual >= 400) throw new Error("The negative control did not expose lost updates");
    console.log(`✓ ${mode}: ${actual}/400 updates (${mode === "increment" ? "all preserved" : "expected lost-update control"})`);
  }
  for (const when of ["before", "after"]) {
    const runRoot = join(root, `publication-${when}`);
    await mkdir(runRoot);
    await exec(binary, ["reset", runRoot, domain, "0"]);
    let observedCrash = false;
    try {
      await exec(binary, [`publication-crash-${when}`, runRoot, domain, "0"], { timeout: 10000 });
    } catch (error) {
      if (error.code !== 86) throw error;
      observedCrash = true;
    }
    if (!observedCrash) throw new Error("The publication probe did not reach the forced exit");
    const outcome = (await exec(binary, ["publication-recover", runRoot, domain, "0"], { timeout: 10000 })).stdout.trim();
    const expected = when === "before" ? "rolledBack" : "committed";
    if (outcome !== expected) throw new Error(`Unexpected publication recovery: ${outcome}`);
    console.log(`✓ publication crash ${when} rename: ${outcome}, exact identity and old records preserved`);
  }
  for (const operation of ["rename", "delete"]) {
    for (const when of ["before", "after"]) {
      const runRoot = join(root, `relocation-${operation}-${when}`);
      await mkdir(runRoot);
      await exec(binary, ["reset-namespaced", runRoot, domain, "0"]);
      let crashed = false;
      try {
        await exec(binary, [`relocation-crash-${operation}-${when}`, runRoot, domain, "0"], { timeout: 10000 });
      } catch (error) {
        if (error.code !== 86) throw error;
        crashed = true;
      }
      if (!crashed) throw new Error("The relocation probe did not reach its forced exit");
      const outcome = (await exec(binary, ["relocation-recover", runRoot, domain, "0"], { timeout: 10000 })).stdout.trim();
      if (outcome !== (when === "before" ? "rolledBack" : "committed")) throw new Error(`Unexpected relocation recovery: ${outcome}`);
      console.log(`✓ ${operation} crash ${when} move: ${outcome}, receipt-verified outcome and original data retained`);
    }
  }
  for (const when of ["before", "after"]) {
    const runRoot = join(root, `replacement-${when}`);
    await mkdir(runRoot);
    await exec(binary, ["reset", runRoot, domain, "0"]);
    let crashed = false;
    try {
      await exec(binary, [`replacement-crash-${when}`, runRoot, domain, "0"], { timeout: 10000 });
    } catch (error) {
      if (error.code !== 86) throw error;
      crashed = true;
    }
    if (!crashed) throw new Error("The replacement probe did not reach its forced exit");
    const outcome = (await exec(binary, ["replacement-recover", runRoot, domain, "0"], { timeout: 10000 })).stdout.trim();
    if (outcome !== (when === "before" ? "rolledBack" : "committed")) throw new Error(`Unexpected replacement recovery: ${outcome}`);
    console.log(`✓ Gallery replacement crash ${when} swap: ${outcome}, exact owner/records retained and cleanup receipt verified`);
  }
} catch (error) {
  failed = true;
  throw error;
} finally {
  // Never remove a live worker's lock directory, or mask its original error
  // with a cleanup race. Worker failure does not imply peers have stopped.
  await Promise.all([...activeWorkers].map((worker) => new Promise((resolve) => {
    worker.once("exit", resolve);
    worker.kill("SIGTERM");
  })));
  try { await exec(binary, ["reset", root, domain, "0"]); } catch { /* Preserve the original test error. */ }
  try { await rm(root, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 }); }
  catch (error) { if (!failed) throw error; }
}
