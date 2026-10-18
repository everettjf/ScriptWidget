// Node host for the preview engine: tests, parity reports, and the future
// local CLI. node:vm is NOT a security boundary; this host is for trusted,
// local packages only. The public website uses the sandboxed Worker host.

import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { Worker } from "node:worker_threads";
import { fileURLToPath } from "node:url";
import { scriptWidgetKernel } from "./kernel.js";
import { createCompiler } from "./compiler.js";
import { runtimeContract } from "./contract.js";
import { preparePackage } from "./prepare.js";

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..");
export const supportBundleDirectory = path.join(repositoryRoot, "Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle");
const workerURL = new URL("./nodeWorker.js", import.meta.url);

let sharedCompiler = null;
let supportScripts = null;

/// The Babel bundle lives in its own context, like the separate JSContext in
/// ScriptWidgetCompiler.compile, so user code never sees a `Babel` global.
export function nodeCompiler() {
  if (sharedCompiler) return sharedCompiler;
  const babelSource = fs.readFileSync(path.join(supportBundleDirectory, "core.js"), "utf8");
  const context = vm.createContext({});
  vm.runInContext(babelSource, context, { filename: "core.js" });
  vm.runInContext("function ScriptWidgetTransform(input) { return Babel.transform(input, { presets: ['scriptwidget'] }).code }", context);
  const transform = context.ScriptWidgetTransform;
  sharedCompiler = createCompiler((source) => transform(source));
  return sharedCompiler;
}

function loadSupportScripts() {
  if (supportScripts) return supportScripts;
  supportScripts = {};
  for (const name of ["util.js", "moment.min.js"]) {
    supportScripts[name] = fs.readFileSync(path.join(supportBundleDirectory, name), "utf8");
  }
  return supportScripts;
}

const emptyResult = (error) => ({ tree: null, error, logs: [], diagnostics: [] });

/// Executes a package entry and resolves with {tree, error, logs, diagnostics}.
/// `files` maps package-relative paths to UTF-8 text.
export async function executePackageInNode({
  files,
  entry = "main.jsx",
  manifest = null,
  environments = { "widget-size": "medium", "widget-param": "" },
  preview = { appearance: "light" },
  fixtures = {},
  device,
  system,
  storage,
  prelude = "",
  timeoutMilliseconds = runtimeContract.executionTimeoutMilliseconds,
  timeZone,
}) {
  const prepared = preparePackage(nodeCompiler(), { files, entry, prelude });
  if (!prepared.ok) return emptyResult(prepared.error);

  const config = JSON.stringify({
    contract: runtimeContract,
    environments, preview, fixtures, device, system, storage,
    manifest: manifest ?? null,
    hasManifest: manifest !== null && manifest !== undefined,
  });
  // ICU reads the time zone per process; Node re-reads it when the main
  // thread assigns process.env.TZ, and workers inherit it.
  const previousTimeZone = process.env.TZ;
  if (timeZone) process.env.TZ = timeZone;

  const resultJSON = await new Promise((resolve) => {
    const worker = new Worker(workerURL, {
      workerData: {
        kernelSource: scriptWidgetKernel.toString(),
        config,
        code: prepared.code,
        imports: prepared.imports,
        files: prepared.files,
        supportScripts: loadSupportScripts(),
        timeoutMilliseconds,
      },
      resourceLimits: { maxOldGenerationSizeMb: 256 },
    });
    let settled = false;
    const settle = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(deadline);
      worker.terminate();
      resolve(value);
    };
    const deadline = setTimeout(() => settle(JSON.stringify(emptyResult({
      kind: "resourceLimit", message: "Script exceeded the 5-second execution limit",
    }))), timeoutMilliseconds + 50);
    worker.once("message", settle);
    worker.once("error", (error) => settle(JSON.stringify(emptyResult({
      kind: error?.code === "ERR_WORKER_OUT_OF_MEMORY" ? "resourceLimit" : "internalError",
      message: String(error?.message ?? error),
    }))));
    worker.once("exit", () => settle(JSON.stringify(emptyResult({ kind: "internalError", message: "Execution worker exited" }))));
  });
  if (timeZone) {
    if (previousTimeZone === undefined) delete process.env.TZ;
    else process.env.TZ = previousTimeZone;
  }
  return { ...JSON.parse(resultJSON), compiled: prepared.code };
}

export function readPackageDirectory(directory) {
  const files = {};
  const visit = (relative) => {
    for (const entry of fs.readdirSync(path.join(directory, relative), { withFileTypes: true })) {
      if (entry.name.startsWith(".") || entry.name === "__Build") continue;
      const childRelative = relative ? `${relative}/${entry.name}` : entry.name;
      if (entry.isDirectory()) visit(childRelative);
      else if (/\.(jsx?|json|txt|md|csv|svg)$/i.test(entry.name)) files[childRelative] = fs.readFileSync(path.join(directory, childRelative), "utf8");
    }
  };
  visit("");
  return files;
}
