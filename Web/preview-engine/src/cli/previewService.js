// Shared by bin/scriptwidget-preview.mjs and bin/scriptwidget-mcp.mjs.
// User code runs in headless Chrome's sandboxed runtime frame, the same
// isolation as the web Studio, never in this Node process.
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "../../scripts/lib/chrome.mjs";
import { buildSandboxSources } from "../../scripts/build-browser.mjs";
import { compilerFingerprint } from "./fingerprint.js";
import { engineVersion, runtimeContract } from "../contract.js";
import { decodeManifest, validateManifest } from "../package/index.js";
import { widgetSize } from "../render/profiles.js";

const engineRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const supportBundle = path.resolve(engineRoot, "../../Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle");
const textExtensions = /\.(jsx?|mjs|json|txt|md|csv|svg|xml)$/i;
const imageTypes = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp", gif: "image/gif", heic: "image/heic" };

/// Reads a package directory: text files, image resources, and a hash of
/// every file so callers can detect stale previews.
export function readPackage(directory) {
  const files = {}; const resources = {};
  const hash = crypto.createHash("sha256");
  const visit = (relative) => {
    for (const entry of fs.readdirSync(path.join(directory, relative), { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (entry.name.startsWith(".") || entry.name === "__Build" || entry.name === "node_modules") continue;
      const child = relative ? `${relative}/${entry.name}` : entry.name;
      const full = path.join(directory, child);
      if (entry.isSymbolicLink()) continue;
      if (entry.isDirectory()) { visit(child); continue; }
      const bytes = fs.readFileSync(full);
      hash.update(child).update("\0").update(bytes).update("\0");
      const type = imageTypes[path.extname(entry.name).slice(1).toLowerCase()];
      if (textExtensions.test(entry.name)) files[child] = bytes.toString("utf8");
      else if (type) resources[child] = `data:${type};base64,${bytes.toString("base64")}`;
    }
  };
  visit("");
  return { files, resources, sourceHash: hash.digest("hex") };
}

export function packageReport(files) {
  if (typeof files["widget.json"] !== "string") {
    if (typeof files["main.jsx"] === "string") return { manifest: null, entry: "main.jsx", issues: [{ severity: "warning", code: "legacy_package", message: "No widget.json: treated as a legacy package with main.jsx." }], valid: true };
    return { manifest: null, entry: null, issues: [{ severity: "error", code: "missing_manifest", message: "widget.json and main.jsx are both missing." }], valid: false };
  }
  const decoded = decodeManifest(files["widget.json"]);
  if (decoded.error) return { manifest: null, entry: null, issues: [{ severity: "error", code: "invalid_manifest", message: decoded.error }], valid: false };
  const report = validateManifest(decoded.manifest, Object.keys(files));
  return { manifest: decoded.manifest, entry: decoded.manifest.entry, ...report };
}

export class PreviewService {
  async start() {
    if (this.page) return;
    const sources = buildSandboxSources();
    const routes = { "/__sandbox-sources.js": { type: "text/javascript", body: `export const sandboxDocument = ${JSON.stringify(sources.sandboxDocument)};` } };
    for (const name of ["core.js", "util.js", "moment.min.js"]) routes[`/__runtime/${name}`] = { type: "text/javascript", body: fs.readFileSync(path.join(supportBundle, name), "utf8") };
    this.server = await serveDirectory(engineRoot, routes);
    this.chrome = await launchChrome({ width: 900, height: 900, scale: 2 });
    this.page = await this.chrome.newPage();
    await this.page.goto(`${this.server.origin}/src/cli/render.html`);
    await this.page.waitFor("window.__ready === true", 30000);
  }

  /// Renders a package directory. Returns {png, result} where result is the
  /// JSON-serializable diagnostics document.
  async render(directory, { family = "medium", profile = "iphone-393", appearance = "light", renderingMode = "fullColor", parameter = "", fixtures = {}, fixturePath = null } = {}) {
    await this.start();
    const packageDirectory = path.resolve(directory);
    const { files, resources, sourceHash } = readPackage(packageDirectory);
    const report = packageReport(files);
    const base = {
      package: packageDirectory, sourceHash, family, profile, appearance, renderingMode, parameter,
      size: widgetSize(profile, family), fixture: fixturePath ? { path: fixturePath, sha256: crypto.createHash("sha256").update(JSON.stringify(fixtures)).digest("hex") } : null,
      engineVersion, runtimeAPIVersion: runtimeContract.apiVersion, compilerFingerprint, renderedAt: new Date().toISOString(),
      authority: "web fast preview; verify on iPhone for the final WidgetKit appearance",
      validation: report.issues,
    };
    if (!report.entry) return { png: null, result: { ...base, status: "error", error: { kind: "invalidPackage", message: report.issues.map((issue) => issue.message).join("\n") } } };
    const job = {
      execute: { files, entry: report.entry, manifest: report.manifest, environments: { "widget-size": family, "widget-param": parameter, "widget-rendering-mode": renderingMode }, preview: { appearance }, fixtures },
      render: { family, profile, appearance, renderingMode, resources },
    };
    const output = await this.page.evaluate(`window.__render(${JSON.stringify(job)})`);
    const result = {
      ...base,
      status: output.error ? "error" : "ok",
      error: output.error ?? null,
      logs: output.logs,
      diagnostics: [...output.diagnostics, ...(output.renderDiagnostics ?? [])],
      timing: output.timing,
      tree: output.tree ? JSON.parse(output.tree) : null,
    };
    if (output.error) return { png: null, result };
    const png = await this.page.screenshot(output.box);
    result.pngSha256 = crypto.createHash("sha256").update(png).digest("hex");
    return { png, result };
  }

  async close() {
    await this.chrome?.close();
    this.server?.close();
    this.page = null;
  }
}
