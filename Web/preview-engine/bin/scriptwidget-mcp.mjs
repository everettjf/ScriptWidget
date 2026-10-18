#!/usr/bin/env node
// Minimal MCP server (stdio, JSON-RPC 2.0, newline-delimited) exposing the
// ScriptWidget preview service to coding agents such as Claude Code or Codex.
//   claude mcp add scriptwidget -- node Web/preview-engine/bin/scriptwidget-mcp.mjs
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import { PreviewService, packageReport, readPackage } from "../src/cli/previewService.js";
import { exportPackage } from "../src/package/index.js";
import { deviceProfiles, widgetFamilies } from "../src/render/profiles.js";
import { engineVersion } from "../src/contract.js";

const service = new PreviewService();
const send = (message) => process.stdout.write(`${JSON.stringify(message)}\n`);
const roots = (process.env.SCRIPTWIDGET_MCP_ROOTS ?? process.cwd()).split(path.delimiter).map((root) => path.resolve(root));

/// Package paths must stay inside the allowed roots (the working directory
/// by default) so a prompt cannot point the tool at arbitrary files.
function packageDirectory(input) {
  if (typeof input !== "string" || input === "") throw new Error("path is required");
  const resolved = fs.realpathSync(path.resolve(roots[0], input));
  if (!roots.some((root) => resolved === root || resolved.startsWith(`${root}${path.sep}`))) throw new Error(`path must be inside ${roots.join(", ")}`);
  if (!fs.statSync(resolved).isDirectory()) throw new Error("path must be a package directory");
  return resolved;
}

const tools = [
  {
    name: "render_widget_preview",
    description: "Render a ScriptWidget package directory to a PNG with the browser preview engine (JavaScriptCore-compatible execution, SwiftUI-calibrated layout). Returns the image and diagnostics with the source hash, so you can tell whether the image matches your latest edit. This is a fast preview; the iPhone WidgetKit result is authoritative.",
    inputSchema: {
      type: "object", additionalProperties: false, required: ["path"],
      properties: {
        path: { type: "string", description: "Package directory containing widget.json or main.jsx" },
        family: { type: "string", enum: widgetFamilies, default: "medium" },
        profile: { type: "string", enum: Object.keys(deviceProfiles), default: "iphone-393" },
        appearance: { type: "string", enum: ["light", "dark"], default: "light" },
        renderingMode: { type: "string", enum: ["fullColor", "accented", "vibrant"], default: "fullColor" },
        parameter: { type: "string", default: "" },
        fixtures: { type: "object", description: "Network/location fixtures: {fetch:[{url, method?, body}], location:{...}}" },
      },
    },
  },
  {
    name: "validate_widget_package",
    description: "Validate a package's widget.json with the Package 2.0 rules iPhone uses on import (permissions, network hosts, entry, actions, controls).",
    inputSchema: { type: "object", additionalProperties: false, required: ["path"], properties: { path: { type: "string" } } },
  },
  {
    name: "export_widget_package",
    description: "Validate and export a package directory as a .swt file that the ScriptWidget iPhone app can import. Writes next to the package unless output is given.",
    inputSchema: { type: "object", additionalProperties: false, required: ["path"], properties: { path: { type: "string" }, output: { type: "string" } } },
  },
];

async function callTool(name, args = {}) {
  if (name === "render_widget_preview") {
    const directory = packageDirectory(args.path);
    const { png, result } = await service.render(directory, {
      family: args.family ?? "medium", profile: args.profile ?? "iphone-393", appearance: args.appearance ?? "light",
      renderingMode: args.renderingMode ?? "fullColor", parameter: args.parameter ?? "", fixtures: args.fixtures ?? {},
    });
    const { tree, ...summary } = result;
    const content = [{ type: "text", text: JSON.stringify(summary, null, 2) }];
    if (png) content.unshift({ type: "image", data: png.toString("base64"), mimeType: "image/png" });
    return { content, isError: result.status !== "ok" };
  }
  if (name === "validate_widget_package") {
    const { files } = readPackage(packageDirectory(args.path));
    const report = packageReport(files);
    return { content: [{ type: "text", text: JSON.stringify({ valid: report.valid, issues: report.issues }, null, 2) }], isError: !report.valid };
  }
  if (name === "export_widget_package") {
    const directory = packageDirectory(args.path);
    const files = {};
    const visit = (relative) => {
      for (const entry of fs.readdirSync(path.join(directory, relative), { withFileTypes: true })) {
        if (entry.name.startsWith(".") || entry.name === "__Build" || entry.isSymbolicLink()) continue;
        const child = relative ? `${relative}/${entry.name}` : entry.name;
        if (entry.isDirectory()) visit(child);
        else if (!/\.swt$|^preview\.png$/.test(child)) files[child] = /\.(jsx?|json|txt|md|csv)$/i.test(child) ? fs.readFileSync(path.join(directory, child), "utf8") : new Uint8Array(fs.readFileSync(path.join(directory, child)));
      }
    };
    visit("");
    const exported = exportPackage(files);
    if (exported.error) return { content: [{ type: "text", text: exported.error }], isError: true };
    const target = args.output ? path.resolve(roots[0], args.output) : path.join(path.dirname(directory), exported.fileName);
    if (!roots.some((root) => target.startsWith(`${root}${path.sep}`))) throw new Error("output must be inside the allowed roots");
    fs.writeFileSync(target, exported.bytes);
    return { content: [{ type: "text", text: `Wrote ${target} (${exported.bytes.length} bytes). On iPhone: open the file, tap Share, choose ScriptWidget.` }] };
  }
  throw new Error(`Unknown tool ${name}`);
}

const lines = readline.createInterface({ input: process.stdin });
lines.on("line", async (line) => {
  if (!line.trim()) return;
  let message;
  try { message = JSON.parse(line); } catch { send({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }); return; }
  const { id, method, params } = message;
  const reply = (result) => { if (id !== undefined) send({ jsonrpc: "2.0", id, result }); };
  const fail = (code, text) => { if (id !== undefined) send({ jsonrpc: "2.0", id, error: { code, message: text } }); };
  try {
    if (method === "initialize") reply({ protocolVersion: params?.protocolVersion ?? "2025-06-18", capabilities: { tools: {} }, serverInfo: { name: "scriptwidget-preview", version: engineVersion } });
    else if (method === "notifications/initialized" || method?.startsWith("notifications/")) { /* no response */ }
    else if (method === "ping") reply({});
    else if (method === "tools/list") reply({ tools });
    else if (method === "tools/call") {
      try { reply(await callTool(params?.name, params?.arguments)); }
      catch (error) { reply({ content: [{ type: "text", text: error.message }], isError: true }); }
    } else fail(-32601, `Method not found: ${method}`);
  } catch (error) { fail(-32603, error.message); }
});
lines.on("close", async () => { await service.close(); process.exit(0); });
