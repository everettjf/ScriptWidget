import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";
import { buildSandboxSources, sandboxPolicy } from "../preview-engine/scripts/build-browser.mjs";

const root = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(root, "../..");
const supportBundle = path.join(repository, "Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle");
const templateRoots = [
  ["template", path.join(repository, "Shared/ScriptWidgetRuntime/Resource/Script.bundle/template")],
  ["gallery", path.join(repository, "Gallery/widgets")],
];
const binaryTypes = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp", gif: "image/gif" };

/// Template catalog: every bundled template and Gallery widget as files.
function templateCatalog() {
  const templates = [];
  for (const [source, directory] of templateRoots) {
    for (const name of fs.readdirSync(directory).filter((item) => !item.startsWith(".")).sort()) {
      const folder = path.join(directory, name);
      if (!fs.existsSync(path.join(folder, "main.jsx"))) continue;
      const files = {};
      const visit = (relative) => {
        for (const entry of fs.readdirSync(path.join(folder, relative), { withFileTypes: true })) {
          if (entry.name.startsWith(".") || entry.name === "__Build") continue;
          const child = relative ? `${relative}/${entry.name}` : entry.name;
          const full = path.join(folder, child);
          if (entry.isDirectory()) { visit(child); continue; }
          const extension = path.extname(entry.name).slice(1).toLowerCase();
          if (binaryTypes[extension]) files[child] = { base64: fs.readFileSync(full).toString("base64") };
          else if (/^(jsx?|json|txt|md|csv|svg)$/.test(extension)) files[child] = fs.readFileSync(full, "utf8");
        }
      };
      visit("");
      let meta = {};
      try { meta = JSON.parse(files["meta.json"] ?? files["widget.json"] ?? "{}"); } catch { meta = {}; }
      templates.push({ id: `${source}/${name}`, source, name: meta.name ?? name, description: meta.description ?? "", category: meta.category ?? (source === "gallery" ? "gallery" : "starter"), files });
    }
  }
  return JSON.stringify({ templates });
}

function sandboxHTML() {
  return buildSandboxSources().sandboxDocument;
}

/// Serves and emits the runtime sandbox, support scripts, and templates.
function scriptWidgetRuntime() {
  const generated = () => ({
    "sandbox.html": { type: "text/html", body: sandboxHTML() },
    "templates.json": { type: "application/json", body: templateCatalog() },
    ...Object.fromEntries(["core.js", "util.js", "moment.min.js"].map((name) => [`runtime/${name}`, { type: "text/javascript", body: fs.readFileSync(path.join(supportBundle, name), "utf8") }])),
    // Third-party assets bundled into the site: Inter (OFL 1.1) and the
    // generated Lucide icon subset (ISC).
    "licenses/inter-OFL.txt": { type: "text/plain", body: fs.readFileSync(path.join(root, "node_modules/@fontsource-variable/inter/LICENSE"), "utf8") },
    "licenses/lucide-ISC.txt": { type: "text/plain", body: /\/\*\n([\s\S]*?)\n\*\//.exec(fs.readFileSync(path.join(root, "../preview-engine/src/render/icons.generated.js"), "utf8"))[1] },
  });
  return {
    name: "scriptwidget-runtime",
    configureServer(server) {
      server.middlewares.use((request, response, next) => {
        const url = new URL(request.url, "http://localhost");
        const file = generated()[url.pathname.replace(/^\//, "")];
        if (!file) { next(); return; }
        response.setHeader("Content-Type", file.type);
        response.end(file.body);
      });
    },
    generateBundle() {
      for (const [fileName, file] of Object.entries(generated())) this.emitFile({ type: "asset", fileName, source: file.body });
    },
  };
}

export { sandboxPolicy };

export default defineConfig({
  base: "./",
  plugins: [scriptWidgetRuntime()],
  server: { fs: { allow: [repository] } },
  build: { target: "es2022", outDir: "dist", emptyOutDir: true },
  resolve: {
    dedupe: ["@codemirror/language", "@codemirror/state", "@codemirror/view", "@lezer/common", "@lezer/highlight"],
  },
  optimizeDeps: {
    exclude: ["@codemirror/autocomplete", "@codemirror/commands", "@codemirror/lang-javascript", "@codemirror/language", "@codemirror/lint", "@codemirror/search", "@codemirror/state", "@codemirror/view", "@lezer/common", "@lezer/highlight", "@lezer/javascript", "@lezer/lr"],
  },
});
