// Actual native credential/PKCE types and XCTest methods. No real Keychain
// items, service accounts or authorization dialogs are used. URLSession tests
// use a private URLProtocol fixture and never reach an external network.
import {execFile} from "node:child_process";
import {promisify} from "node:util";
import {mkdtemp, mkdir, readFile, rm, writeFile} from "node:fs/promises";
import {tmpdir} from "node:os";
import {join, dirname, resolve} from "node:path";
import {fileURLToPath} from "node:url";
import {createHash} from "node:crypto";
const exec = promisify(execFile);
const repository = fileURLToPath(new URL("../", import.meta.url));
const temporary = await mkdtemp(join(tmpdir(), "scriptwidget-services-"));
const relativeSources = ["Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetServiceAuthorization.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetServiceCredentialVault.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetServiceAccessPolicy.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetServiceTransport.swift", "Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetServiceConnections.swift", "Tests/ScriptWidgetRuntimeTests/ServiceAuthorizationTests.swift", "Tests/ScriptWidgetRuntimeTests/ServiceAccessPolicyTests.swift", "Tests/ScriptWidgetRuntimeTests/ServiceTransportTests.swift"];
const sources = relativeSources.map(path => join(repository, path));
const output = resolve(process.argv[2] ?? join(repository, "__Release/capabilities/services/authorization-verification.json"));
const environment = {...process.env};
for (const key of ["APPLE_ID", "APPLE_SPECIFIC_PASSWORD", "APPLE_TEAM_ID"]) delete environment[key];
try {
  const platform = (await exec("xcrun", ["--sdk", "macosx", "--show-sdk-platform-path"])).stdout.trim();
  const frameworks = join(platform, "Developer/Library/Frameworks"), libraries = join(platform, "Developer/usr/lib");
  const main = join(temporary, "main.swift"), binary = join(temporary, "probe");
  await writeFile(main, `import Foundation
import XCTest
let suite = XCTestSuite(name: "Service authorization and native access policy")
suite.addTest(XCTestSuite(forTestCaseClass: ServiceAuthorizationTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ServiceAccessPolicyTests.self))
suite.addTest(XCTestSuite(forTestCaseClass: ServiceTransportTests.self))
guard suite.testCaseCount == 44 else { fatalError("Expected forty-four native service tests") }
suite.run()
guard let run = suite.testRun else { fatalError("Missing XCTest run") }
let result: [String: Any] = ["passed": run.hasSucceeded, "testCount": run.executionCount, "failureCount": run.totalFailureCount, "realKeychain": false, "realServiceAuthorization": false, "externalNetworkRequests": 0, "applicationHost": false]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
guard run.hasSucceeded, run.executionCount == 44 else { exit(1) }
`);
  const flags = ["-D", "SCRIPTWIDGET_SERVICE_STANDALONE_TESTS", "-F", frameworks, "-I", libraries, "-L", libraries,
    "-Xlinker", "-rpath", "-Xlinker", frameworks, "-Xlinker", "-rpath", "-Xlinker", libraries];
  const compiled = await exec("xcrun", ["swiftc", ...flags, ...sources, main, "-o", binary], {timeout: 60000, env: environment});
  const run = await exec(binary, [], {timeout: 10000, env: environment, maxBuffer: 1024 * 1024});
  const result = JSON.parse(run.stdout.trim().split("\n").at(-1));
  const sourceSHA256 = Object.fromEntries(await Promise.all(sources.map(async (path, index) => [relativeSources[index], createHash("sha256").update(await readFile(path)).digest("hex")])));
  await mkdir(dirname(output), {recursive: true});
  await writeFile(output, JSON.stringify({...result, sourceSHA256}, null, 2) + "\n");
  await writeFile(output.replace(/\.json$/, "") + ".log", compiled.stdout + compiled.stderr + run.stdout + run.stderr);
  console.log(`✓ service authorization: ${result.testCount} tests, ${result.failureCount} failures; real accounts/Keychain not accessed`);
} finally {
  await rm(temporary, {recursive: true, force: true});
}
