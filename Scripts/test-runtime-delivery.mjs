// Exercise the actual runtime delivery implementation and XCTest methods without
// launching an application or claiming UI/device coverage.
import {execFile} from "node:child_process";
import {promisify} from "node:util";
import {mkdtemp, mkdir, readFile, rm, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join, dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import {createHash} from "node:crypto";
const exec = promisify(execFile);
const repository = fileURLToPath(new URL("../", import.meta.url));
const temporary = await mkdtemp(join(tmpdir(), "scriptwidget-delivery-"));
const implementation = join(repository, "Shared/ScriptWidgetRuntime/Widget/Runtime/ScriptWidgetRuntimeDelivery.swift");
const tests = join(repository, "Tests/ScriptWidgetRuntimeTests/RuntimeDeliveryTests.swift");
const output = resolve(process.argv[2] ?? join(repository, "__Release/capabilities/runtime-delivery/verification.json"));
const environment = {...process.env, SCRIPTWIDGET_DELIVERY_STRESS_ITERATIONS: "100000"};
for (const key of ["APPLE_ID", "APPLE_SPECIFIC_PASSWORD", "APPLE_TEAM_ID"]) delete environment[key];
try {
  const platform = (await exec("xcrun", ["--sdk", "macosx", "--show-sdk-platform-path"])).stdout.trim();
  const frameworks = join(platform, "Developer/Library/Frameworks"), libraries = join(platform, "Developer/usr/lib");
  // Standalone XCTest executables do not receive Xcode's test-runner search paths.
  // Xcode 26.6's Swift support library also needs XCTestCore from this directory.
  // These paths belong only to the disposable test probe, never to shipped apps.
  const privateFrameworks = join(platform, "Developer/Library/PrivateFrameworks");
  const main = join(temporary, "main.swift"), binary = join(temporary, "probe");
  await writeFile(main, `import Foundation
import XCTest
let suite = XCTestSuite(forTestCaseClass: RuntimeDeliveryReferenceTests.self)
guard suite.testCaseCount == 4 else { fatalError("Expected four runtime delivery tests") }
suite.run()
guard let run = suite.testRun else { fatalError("Missing XCTest run") }
let result: [String: Any] = ["passed": run.hasSucceeded, "testCount": run.executionCount, "failureCount": run.totalFailureCount, "referencePayloads": 100000, "applicationHost": false, "physicalDevice": false]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
guard run.hasSucceeded, run.executionCount == 4 else { exit(1) }
`);
  const flags = ["-D", "SCRIPTWIDGET_DELIVERY_STANDALONE_TESTS", "-F", frameworks, "-I", libraries, "-L", libraries,
    "-Xlinker", "-rpath", "-Xlinker", frameworks, "-Xlinker", "-rpath", "-Xlinker", libraries,
    "-Xlinker", "-rpath", "-Xlinker", privateFrameworks];
  const compile = await exec("xcrun", ["swiftc", ...flags, implementation, tests, main, "-o", binary], {timeout: 60000, env: environment});
  const run = await exec(binary, [], {timeout: 60000, env: environment, maxBuffer: 1024 * 1024});
  const result = JSON.parse(run.stdout.trim().split("\n").at(-1));
  // The previous waiting-thread cancellation must fail the lane/lifetime test.
  // Mutate only a disposable copy; production sources remain unchanged.
  const delivery = await readFile(implementation, "utf8");
  const cancellation = "publisherLane.queue.async { subscription.cancel() }";
  if (delivery.split(cancellation).length !== 2) throw new Error("Update the explicit cancellation control after changing the delivery implementation");
  const legacy = join(temporary, "LegacyDelivery.swift"), control = join(temporary, "control");
  await writeFile(legacy, delivery.replace(cancellation, "subscription.cancel()"));
  await writeFile(main, `import Foundation
import XCTest
let all = XCTestSuite(forTestCaseClass: RuntimeDeliveryReferenceTests.self)
let selected = XCTestSuite(name: "Unsafe waiting-thread cancellation control")
for test in all.tests where test.name.contains("testCancellationRunsOnPublisherLaneAfterCompletionReturns") { selected.addTest(test) }
guard selected.testCaseCount == 1 else { fatalError("Missing cancellation control") }
selected.run()
guard let run = selected.testRun else { fatalError("Missing control run") }
let result: [String: Any] = ["testCount": run.executionCount, "failureCount": run.totalFailureCount, "passed": run.hasSucceeded]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
exit(run.executionCount == 1 && !run.hasSucceeded ? 1 : 2)
`);
  await exec("xcrun", ["swiftc", ...flags, legacy, tests, main, "-o", control], {timeout: 60000, env: environment});
  let unsafeRun;
  try { await exec(control, [], {timeout: 10000, env: environment}); throw new Error("Unsafe cancellation unexpectedly passed"); }
  catch (error) {
    if (error.code !== 1 || error.signal) throw error;
    unsafeRun = JSON.parse(error.stdout.trim().split("\n").at(-1));
    if (unsafeRun.passed || unsafeRun.testCount !== 1 || unsafeRun.failureCount < 1) throw new Error("The unsafe cancellation control did not fail its assertions");
    await mkdir(dirname(output), {recursive: true});
    await writeFile(output.replace(/\.json$/, "") + "-unsafe-control.log", error.stdout + error.stderr);
  }
  const sourceSHA256 = Object.fromEntries(await Promise.all([implementation, tests].map(async path => [path.slice(repository.length), createHash("sha256").update(await readFile(path)).digest("hex")])));
  await mkdir(dirname(output), {recursive: true});
  await writeFile(output, JSON.stringify({...result, unsafeCancellationControl: unsafeRun, sourceSHA256}, null, 2) + "\n");
  await writeFile(output.replace(/\.json$/, "") + ".log", compile.stdout + compile.stderr + run.stdout + run.stderr);
  console.log(`✓ runtime delivery: ${result.testCount} tests, ${result.referencePayloads} reference results, ${result.failureCount} failures`);
} finally {
  await rm(temporary, {recursive: true, force: true});
}
