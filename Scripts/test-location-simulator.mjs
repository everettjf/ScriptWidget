#!/usr/bin/env node
// Dedicated simulator only: fixed public sample coordinates, no personal GPS data.
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const output = mkdtempSync(path.join(tmpdir(), "scriptwidget-location-probe-"));
const derived = process.env.SCRIPTWIDGET_DERIVED_DATA ?? "/tmp/scriptwidget-release-readiness";
const iosDerived = path.join(derived, "ios-tests");
const app = path.join(iosDerived, "Build/Products/Debug-iphonesimulator/ScriptWidget.app");
const run = (command, args, timeout = 120_000, env = process.env) => execFileSync(command, args, {
  cwd: root, env, timeout, encoding: "utf8", maxBuffer: 8 * 1024 * 1024,
});
if (!existsSync(app)) throw new Error("Build the iOS simulator test host before running this probe");
let device;
try {
  const runtimes = JSON.parse(run("xcrun", ["simctl", "list", "runtimes", "-j"])).runtimes;
  const runtime = runtimes.find((item) => item.isAvailable && item.identifier === "com.apple.CoreSimulator.SimRuntime.iOS-27-0");
  if (!runtime) throw new Error("The iOS 27.0 simulator runtime is required");
  const created = run("xcrun", ["simctl", "create", `ScriptWidget Location Probe ${Date.now()}`, "com.apple.CoreSimulator.SimDeviceType.iPhone-17", runtime.identifier]).trim();
  if (!/^[0-9A-F-]{36}$/i.test(created)) throw new Error("Simulator creation returned an invalid identity");
  device = created;
  process.stdout.write(`Created dedicated simulator ${device}\n`);
  run("xcrun", ["simctl", "boot", device]);
  run("xcrun", ["simctl", "bootstatus", device, "-b"]);
  run("xcrun", ["simctl", "install", device, app]);
  run("xcrun", ["simctl", "privacy", device, "grant", "location", "com.everettjf.scriptwidget"]);
  run("xcrun", ["simctl", "location", device, "set", "37.3349,-122.009"]);
  const resultPath = path.join(output, "location.xcresult");
  let buildLog;
  try {
    buildLog = run("xcodebuild", ["-quiet", "-project", "iOS/ScriptWidget.xcodeproj", "-scheme", "ScriptWidgetRuntimeTests", "-destination", `platform=iOS Simulator,id=${device}`, "-derivedDataPath", iosDerived, "-resultBundlePath", resultPath, "test", "-only-testing:ScriptWidgetRuntimeTests/RuntimeExecutionTests/testLocationCoreLocationBridgeWithExplicitSimulatorFixture"], 180_000, { ...process.env, TEST_RUNNER_SCRIPTWIDGET_LOCATION_SIMULATOR_PROBE: "1" });
  } catch (error) {
    writeFileSync(path.join(output, "xcodebuild.log"), String(error.stdout ?? "") + String(error.stderr ?? ""));
    throw error;
  }
  writeFileSync(path.join(output, "xcodebuild.log"), buildLog);
  const summary = JSON.parse(run("xcrun", ["xcresulttool", "get", "test-results", "summary", "--path", resultPath, "--format", "json"]));
  writeFileSync(path.join(output, "verification.json"), JSON.stringify({
    scope: "App JavaScriptCore -> CLLocationManager -> fixed simulator coordinates; not physical GPS or WidgetKit authorization acceptance",
    device, coordinates: "37.3349,-122.009", resultPath, summary,
  }, null, 2) + "\n");
  if (summary.result !== "Passed" || summary.passedTests !== 1 || summary.skippedTests !== 0 || summary.failedTests !== 0) throw new Error("The simulator location bridge probe did not pass exactly once");
  if (summary.runtimeWarnings?.length) throw new Error("The location probe produced runtime warnings; inspect the xcresult before accepting it");
  process.stdout.write(`✓ Actual Core Location bridge returned the configured simulator fix\nEvidence: ${output}\n`);
} finally {
  if (device) {
    try { run("xcrun", ["simctl", "shutdown", device]); } catch { /* May already be stopped. */ }
    run("xcrun", ["simctl", "delete", device]);
    process.stdout.write(`Removed dedicated simulator ${device}\n`);
  }
}
