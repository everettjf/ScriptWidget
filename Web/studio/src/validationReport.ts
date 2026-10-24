import { engineVersion, runtimeContract } from "../../preview-engine/src/contract.js";
import { dataAPICatalog } from "../../../Editor/editorfe/src/dataAPICatalog.js";
import type { Project } from "./project.ts";
import { packageReport } from "./project.ts";
import type { PreviewSettings, PreviewState } from "./hooks/usePreview.ts";

const encoder = new TextEncoder();
const bytes = (value: string | Uint8Array) => typeof value === "string" ? encoder.encode(value) : value;
function field(value: Uint8Array): Uint8Array {
  const result = new Uint8Array(8 + value.length);
  new DataView(result.buffer).setBigUint64(0, BigInt(value.length));
  result.set(value, 8);
  return result;
}
function join(values: Uint8Array[]): Uint8Array {
  const result = new Uint8Array(values.reduce((sum, value) => sum + value.length, 0));
  let offset = 0;
  for (const value of values) { result.set(value, offset); offset += value.length; }
  return result;
}
const digest = async (value: Uint8Array) => Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", value.slice().buffer))).map(value => value.toString(16).padStart(2, "0")).join("");
export async function packageSourceHash(files: Project["files"]): Promise<string> {
  const names = Object.keys(files).filter(name => !name.split("/").some(part => ["__Build", ".git", ".scriptwidget-artifacts"].includes(part)));
  names.sort((left, right) => {
    const a = encoder.encode(left), b = encoder.encode(right);
    for (let index = 0; index < Math.min(a.length, b.length); index++) if (a[index] !== b[index]) return a[index]! - b[index]!;
    return a.length - b.length;
  });
  const count = new Uint8Array(8);
  new DataView(count.buffer).setBigUint64(0, BigInt(names.length));
  return digest(join([encoder.encode("ScriptWidgetSource/v1\n"), count, ...names.flatMap(name => [field(encoder.encode(name)), field(bytes(files[name]!))])]));
}
export function previewIsCurrent(project: Project, settings: PreviewSettings, preview: PreviewState): boolean {
  return preview.input?.files === project.files && preview.input.fixtures === project.fixtures && (Object.keys(settings) as Array<keyof PreviewSettings>).every(key => preview.input!.settings[key] === settings[key]);
}
export async function validationReport(project: Project, settings: PreviewSettings, preview: PreviewState) {
  if (!previewIsCurrent(project, settings, preview)) throw new Error("The preview is updating. Wait for the latest result before exporting its report.");
  const output = preview.output, report = packageReport(project);
  const completed = output.kind === "widget" || output.kind === "error";
  const failed = !report.valid || output.kind === "error" || preview.problems.some(item => item.severity === "error");
  const fixturesHash = await digest(join([encoder.encode("ScriptWidgetFixtures/v1\n"), field(encoder.encode(JSON.stringify(dataAPICatalog))), field(encoder.encode(project.fixtures)), field(encoder.encode("1"))]));
  return {
    reportVersion: 1, command: "render", status: !completed ? "error" : failed ? "failed" : "passed", backend: "web",
    tool: { version: engineVersion, runtimeAPIVersion: runtimeContract.nativeAPIVersion, engineAPIVersion: runtimeContract.apiVersion, compilerFingerprint: runtimeContract.compilerFingerprint },
    sourceHash: await packageSourceHash(project.files), sourceHashAlgorithm: "ScriptWidgetSource/v1", fixturesHash,
    target: settings, checks: { package: report.valid ? "passed" : "failed", compile: completed && report.valid ? (output.kind === "error" ? "notRun" : "passed") : "notRun", execute: output.kind === "widget" ? "passed" : "notRun", render: output.kind === "widget" ? "passed" : "notRun", native: "notRun", export: "notRun" },
    diagnostics: preview.problems.map(item => ({ severity: item.severity, code: item.code ?? "web.preview", message: item.text, ...(item.detail ? { detail: item.detail } : {}) })), logs: preview.logs, artifacts: [],
    limitations: ["Browser approximation with mock data; native validation was not run.", "System permissions, real accounts and WidgetKit installation are not tested."],
    generatedAt: new Date().toISOString(),
  };
}
