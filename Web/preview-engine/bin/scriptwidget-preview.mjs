#!/usr/bin/env node
// scriptwidget-preview <package-dir> [options]
// Renders a ScriptWidget package to PNG and writes a diagnostics JSON with
// the source hash, size, fixtures, engine version, and compiler fingerprint.
import fs from "node:fs";
import path from "node:path";
import { parseArgs } from "node:util";
import { PreviewService, packageReport, readPackage } from "../src/cli/previewService.js";
import { DeviceSession } from "../src/cli/deviceSync.js";
import { widgetFamilies, deviceProfiles } from "../src/render/profiles.js";

const usage = `Usage: scriptwidget-preview <package-dir> [options]

Options:
  --family <name>        ${widgetFamilies.join(", ")} (default medium)
  --profile <name>       ${Object.keys(deviceProfiles).join(", ")} (default iphone-393)
  --appearance <mode>    light or dark (default light)
  --mode <mode>          fullColor, accented, or vibrant (default fullColor)
  --param <text>         value for $getenv("widget-param")
  --fixture <file>       JSON fixtures: {"fetch":[{"url","body"}], "location":{...}}
  --output <file>        PNG path (default <package>/preview.png)
  --diagnostics <file>   diagnostics JSON path (default stdout)
  --watch                re-render when package files change
  --device <url>         also push to a paired iPhone/iPad running Web Studio
                         (for example http://192.168.1.20:8123) and save its
                         native preview as <output>.native.png
  --pair-code <code>     the six-digit code shown by Web Studio on the device
  --device-package <id>  device package id (default: match widget.json name)
  --help`;

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    family: { type: "string", default: "medium" }, profile: { type: "string", default: "iphone-393" },
    appearance: { type: "string", default: "light" }, mode: { type: "string", default: "fullColor" },
    param: { type: "string", default: "" }, fixture: { type: "string" }, output: { type: "string" },
    diagnostics: { type: "string" }, watch: { type: "boolean", default: false }, help: { type: "boolean", default: false },
    device: { type: "string" }, "pair-code": { type: "string" }, "device-package": { type: "string" },
  },
});
if (values.help || positionals.length !== 1) { console.log(usage); process.exit(values.help ? 0 : 2); }
const directory = path.resolve(positionals[0]);
if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) { console.error(`Not a package directory: ${directory}`); process.exit(2); }
if (!widgetFamilies.includes(values.family)) { console.error(`Unknown family ${values.family}`); process.exit(2); }

const service = new PreviewService();
const output = path.resolve(values.output ?? path.join(directory, "preview.png"));
let fixtures = {};
if (values.fixture) fixtures = JSON.parse(fs.readFileSync(values.fixture, "utf8"));

let device = null;
if (values.device) {
  if (!values["pair-code"]) { console.error("--device requires --pair-code"); process.exit(2); }
  device = new DeviceSession(values.device);
  const session = await device.pair(values["pair-code"]);
  console.error(`Paired with ${session.device?.name ?? "device"} (${session.device?.system ?? ""})`);
}

async function syncDevice(result) {
  const { files } = readPackage(directory);
  const report = packageReport(files);
  const nativeOutput = output.replace(/\.png$/i, "") + ".native.png";
  try {
    const synced = await device.pushAndCapture({ files, manifestName: report.manifest?.name ?? path.basename(directory), entry: report.entry ?? "main.jsx", packageID: values["device-package"] });
    fs.writeFileSync(nativeOutput, synced.snapshot);
    result.native = { status: "ok", output: nativeOutput, package: synced.package, uploaded: synced.uploaded, skipped: synced.skipped, snapshotSequence: synced.snapshotSequence, sourceHash: result.sourceHash };
  } catch (error) {
    if (fs.existsSync(nativeOutput)) fs.rmSync(nativeOutput);
    result.native = { status: "error", message: error.message };
  }
}

async function once() {
  const { png, result } = await service.render(directory, {
    family: values.family, profile: values.profile, appearance: values.appearance, renderingMode: values.mode,
    parameter: values.param, fixtures, fixturePath: values.fixture ? path.resolve(values.fixture) : null,
  });
  if (png) { fs.writeFileSync(output, png); result.output = output; }
  else if (fs.existsSync(output)) fs.rmSync(output); // never leave a stale image next to a failed render
  if (device) await syncDevice(result);
  const json = `${JSON.stringify(result, null, 2)}\n`;
  if (values.diagnostics) fs.writeFileSync(values.diagnostics, json); else process.stdout.write(json);
  return result;
}

try {
  const result = await once();
  if (!values.watch) { await device?.disconnect(); await service.close(); process.exit(result.status === "ok" ? 0 : 1); }
  console.error(`Watching ${directory} (Ctrl-C to stop)`);
  let timer = 0;
  fs.watch(directory, { recursive: true }, (event, name) => {
    if (!name || name.startsWith(".") || path.resolve(directory, name) === output || (values.diagnostics && path.resolve(name) === path.resolve(values.diagnostics))) return;
    clearTimeout(timer);
    timer = setTimeout(() => once().then((next) => console.error(`${new Date().toLocaleTimeString()} ${next.status} ${next.sourceHash.slice(0, 12)}`)).catch((error) => console.error(error.message)), 150);
  });
  process.on("SIGINT", async () => { await device?.disconnect(); await service.close(); process.exit(0); });
} catch (error) {
  console.error(error.message);
  await service.close();
  process.exit(1);
}
