import "./style.css";
import { createPreviewSandbox } from "../../preview-engine/src/browser/client.js";
import { renderWidget } from "../../preview-engine/src/render/renderer.js";
import { deviceProfiles } from "../../preview-engine/src/render/profiles.js";
import { exportPackage, importPackage } from "../../preview-engine/src/package/index.js";
import { createEditor } from "./editor.js";
import {
  createProject, defaultFixtures, familyLabels, packageReport, previewFamilies, projectFromTemplate, resourceURLs, textFiles, validNewPath,
} from "./project.js";
import { preferences, storage } from "./store.js";

const $ = (selector) => document.querySelector(selector);
const element = (tag, properties = {}, children = []) => {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(properties)) {
    if (key === "dataset") Object.assign(node.dataset, value);
    else if (key in node) node[key] = value;
    else node.setAttribute(key, value);
  }
  node.append(...children);
  return node;
};

const state = {
  projects: [], project: null, path: "main.jsx", templates: null,
  profile: preferences.read("profile", "iphone-393"), family: preferences.read("family", "medium"),
  appearance: preferences.read("appearance", globalThis.matchMedia?.("(prefers-color-scheme: dark)").matches ? "dark" : "light"),
  renderingMode: "fullColor", parameter: "",
};

const sandbox = createPreviewSandbox({ sandboxURL: new URL("./sandbox.html", document.baseURI).href, assetBaseURL: new URL("./runtime/", document.baseURI) });
const editor = createEditor($("#editor"), (path, text) => {
  if (!state.project) return;
  state.project.files[path] = text;
  if (path === "widget.json") renderPackagePanel();
  scheduleSave();
  schedulePreview();
});

// MARK: - Persistence

let saveTimer = 0;
function scheduleSave() {
  $("#save-state").textContent = "Editing…";
  clearTimeout(saveTimer);
  saveTimer = setTimeout(async () => {
    await storage.save(state.project);
    $("#save-state").textContent = storage.persistent ? "Saved in this browser" : "Not saved: browser storage is unavailable";
    renderProjects();
  }, 400);
}

async function loadProjects() {
  state.projects = (await storage.list()).sort((a, b) => b.updatedAt - a.updatedAt);
  if (state.projects.length === 0) {
    const starter = createProject("My First Widget");
    await storage.save(starter);
    state.projects = [starter];
  }
  const lastID = preferences.read("project", null);
  await openProject(state.projects.find((project) => project.id === lastID) ?? state.projects[0]);
}

async function openProject(project) {
  state.project = project;
  preferences.write("project", project.id);
  editor.reset();
  const report = packageReport(project);
  state.path = report.manifest && typeof project.files[report.manifest.entry] === "string" ? report.manifest.entry : Object.keys(project.files).find((path) => typeof project.files[path] === "string") ?? "widget.json";
  $("#project-name").value = project.name;
  $("#fixtures").value = project.fixtures ?? defaultFixtures;
  renderProjects();
  renderFiles();
  openFile(state.path);
  renderControls();
  renderPackagePanel();
  schedulePreview(0);
}

function openFile(path) {
  state.path = path;
  const value = state.project.files[path];
  $("#current-file").textContent = path;
  if (typeof value === "string") editor.open(path, value);
  else editor.open(path, `// ${path} is a binary file (${value.length.toLocaleString()} bytes).`);
  renderFiles();
}

// MARK: - Sidebar

function renderProjects() {
  const list = $("#project-list");
  list.replaceChildren(...state.projects.map((project) => {
    const open = element("button", { type: "button", className: "row-button", textContent: project.name, "aria-current": project.id === state.project?.id ? "true" : "false" });
    open.addEventListener("click", () => openProject(project));
    const remove = element("button", { type: "button", className: "icon-button subtle", textContent: "×", "aria-label": `Delete ${project.name}` });
    remove.addEventListener("click", async () => {
      if (!confirm(`Delete "${project.name}" from this browser? Export it first if you want to keep it.`)) return;
      await storage.remove(project.id);
      state.projects = state.projects.filter((item) => item.id !== project.id);
      if (state.project?.id === project.id) {
        if (state.projects.length === 0) { const fresh = createProject(); await storage.save(fresh); state.projects = [fresh]; }
        await openProject(state.projects[0]);
      } else renderProjects();
    });
    return element("li", {}, [open, remove]);
  }));
}

function renderFiles() {
  const report = packageReport(state.project);
  const entry = report.manifest?.entry;
  const paths = Object.keys(state.project.files).sort((a, b) => (a === "widget.json" ? -1 : b === "widget.json" ? 1 : a.localeCompare(b)));
  $("#file-list").replaceChildren(...paths.map((path) => {
    const open = element("button", { type: "button", className: "row-button", textContent: path, "aria-current": path === state.path ? "true" : "false" });
    open.addEventListener("click", () => openFile(path));
    const children = [open];
    if (path !== "widget.json" && path !== entry) {
      const remove = element("button", { type: "button", className: "icon-button subtle", textContent: "×", "aria-label": `Delete ${path}` });
      remove.addEventListener("click", () => {
        if (!confirm(`Delete ${path}?`)) return;
        delete state.project.files[path];
        editor.forget(path);
        if (state.path === path) openFile(entry ?? "widget.json");
        renderFiles(); scheduleSave(); schedulePreview();
      });
      children.push(remove);
    }
    return element("li", {}, children);
  }));
}

$("#add-file").addEventListener("click", () => {
  const path = prompt("New file (for example lib/util.js):", "lib/util.js");
  if (!path) return;
  const problem = validNewPath(path.trim(), state.project.files);
  if (problem) { alert(problem); return; }
  state.project.files[path.trim()] = /\.json$/i.test(path) ? "{}\n" : "";
  openFile(path.trim()); scheduleSave();
});

$("#add-image").addEventListener("click", () => $("#image-input").click());
$("#image-input").addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  event.target.value = "";
  if (!file) return;
  if (file.size > 8 * 1024 * 1024) { alert("Images must be 8 MB or smaller, like on iPhone."); return; }
  const name = file.name.toLowerCase().replace(/[^a-z0-9._-]+/g, "-");
  const path = `image/${name}`;
  if (state.project.files[path] && !confirm(`Replace ${path}?`)) return;
  state.project.files[path] = new Uint8Array(await file.arrayBuffer());
  renderFiles(); scheduleSave(); schedulePreview();
  status(`Added ${path}. Use <image id="${name.replace(/\.[^.]+$/, "")}" /> in your widget.`);
});

$("#project-name").addEventListener("change", (event) => {
  const name = event.target.value.trim() || "My Widget";
  state.project.name = name;
  const report = packageReport(state.project);
  if (report.manifest) {
    report.manifest.name = name.slice(0, 80);
    state.project.files["widget.json"] = `${JSON.stringify(report.manifest, null, 2)}\n`;
    if (state.path === "widget.json") openFile("widget.json");
  }
  scheduleSave(); renderPackagePanel();
});

$("#fixtures").addEventListener("input", (event) => { state.project.fixtures = event.target.value; scheduleSave(); schedulePreview(); });

// MARK: - Preview

function renderControls() {
  const profile = $("#profile");
  profile.replaceChildren(...Object.entries(deviceProfiles).map(([id, item]) => element("option", { value: id, textContent: item.label, selected: id === state.profile })));
  const families = previewFamilies(packageReport(state.project).manifest, state.profile);
  if (!families.includes(state.family)) state.family = families.includes("medium") ? "medium" : families[0];
  $("#family").replaceChildren(...families.map((family) => element("option", { value: family, textContent: familyLabels[family] ?? family, selected: family === state.family })));
  $("#appearance").value = state.appearance;
  $("#rendering-mode").value = state.renderingMode;
}

for (const [selector, key] of [["#profile", "profile"], ["#family", "family"], ["#appearance", "appearance"], ["#rendering-mode", "renderingMode"]]) {
  $(selector).addEventListener("change", (event) => {
    state[key] = event.target.value;
    preferences.write(key, state[key]);
    if (key === "profile") renderControls();
    schedulePreview(0);
  });
}
$("#parameter").addEventListener("input", (event) => { state.parameter = event.target.value; schedulePreview(); });

function status(text) { $("#preview-status").textContent = text; }

let previewTimer = 0;
let generation = 0;
function schedulePreview(delay = 250) {
  clearTimeout(previewTimer);
  previewTimer = setTimeout(refreshPreview, delay);
}

function message(severity, text, detail) {
  const item = element("li", { className: severity }, [element("strong", { textContent: severity === "error" ? "Error" : severity === "warning" ? "Warning" : "Note" }), document.createTextNode(` ${text}`)]);
  if (detail) item.append(element("pre", { textContent: detail }));
  return item;
}

async function refreshPreview() {
  const current = ++generation;
  const started = performance.now();
  const report = packageReport(state.project);
  const problems = report.issues.map((issue) => message(issue.severity, issue.message));
  let fixtures = {};
  try { fixtures = JSON.parse(state.project.fixtures || "{}"); } catch (error) { problems.push(message("warning", `Fixtures are not valid JSON: ${error.message}`)); }
  const manifest = report.manifest;
  const entry = manifest?.entry ?? "main.jsx";
  const result = await sandbox.execute({
    files: textFiles(state.project.files), entry,
    manifest: manifest ?? null,
    environments: { "widget-size": state.family, "widget-param": state.parameter, "widget-rendering-mode": state.renderingMode },
    preview: { appearance: state.appearance }, fixtures,
  });
  if (current !== generation) return;
  $("#console").replaceChildren(...(result.logs.length ? result.logs.map((log) => message(log.level === "error" ? "error" : "info", log.message)) : [element("li", { className: "muted", textContent: "console.log output appears here." })]));
  for (const item of result.diagnostics) problems.push(message(item.severity, item.message));
  if (result.error) {
    $("#stage").replaceChildren(element("div", { className: "error-card" }, [element("strong", { textContent: `${result.error.kind}` }), element("pre", { textContent: result.error.message })]));
    problems.unshift(message("error", `The widget failed to run (${result.error.kind}).`, result.error.message));
    status("Fix the error to see the preview.");
  } else {
    const rendered = await renderWidget(result.tree, { family: state.family, profile: state.profile, appearance: state.appearance, renderingMode: state.renderingMode, resources: resourceURLs(state.project.files) });
    if (current !== generation) return;
    rendered.element.classList.add("widget-frame");
    $("#stage").replaceChildren(rendered.element);
    for (const item of rendered.diagnostics) problems.push(message(item.severity, item.message));
    const elapsed = Math.round(performance.now() - started);
    status(`Web fast preview · ${elapsed} ms · ${rendered.size.width}×${rendered.size.height} pt. Install on iPhone for the final look.`);
  }
  $("#problems").replaceChildren(...(problems.length ? problems : [element("li", { className: "muted", textContent: "No problems found." })]));
  const tab = document.querySelector('[data-tab="problems"]');
  const errors = problems.filter((item) => item.classList.contains("error")).length;
  tab.textContent = errors ? `Problems (${errors})` : "Problems";
}

// MARK: - Package panel

function renderPackagePanel() {
  const report = packageReport(state.project);
  const root = $("#package-summary");
  if (!report.manifest) { root.replaceChildren(message("error", report.issues[0].message)); return; }
  const manifest = report.manifest;
  const rows = [
    ["Identifier", manifest.id], ["Version", manifest.version], ["Entry", manifest.entry],
    ["Sizes", manifest.supportedFamilies.join(", ")],
    ["Permissions", manifest.permissions.length ? manifest.permissions.join(", ") : "None"],
    ["Network hosts", manifest.networkDomains.length ? manifest.networkDomains.join(", ") : "None"],
  ];
  root.replaceChildren(
    element("dl", { className: "facts" }, rows.flatMap(([term, value]) => [element("dt", { textContent: term }), element("dd", { textContent: value })])),
    element("p", { className: report.valid ? "ok" : "bad", textContent: report.valid ? "Ready to export: the manifest passes Package 2.0 validation." : "Fix the manifest errors in Problems before exporting." }),
    element("p", { className: "hint", textContent: "Edit widget.json to change sizes, permissions, or network hosts. iPhone asks the user to review permissions on import." }),
  );
  renderControls();
}

document.querySelectorAll('[role="tab"]').forEach((tab) => tab.addEventListener("click", () => {
  document.querySelectorAll('[role="tab"]').forEach((other) => other.setAttribute("aria-selected", String(other === tab)));
  document.querySelectorAll(".tab-panel").forEach((panel) => { panel.hidden = panel.id !== `tab-${tab.dataset.tab}`; });
}));

// MARK: - Import, export, install

$("#import-package").addEventListener("click", () => $("#import-input").click());
$("#import-input").addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  event.target.value = "";
  if (!file) return;
  const result = await importPackage(new Uint8Array(await file.arrayBuffer()));
  if (result.error) { alert(`This package cannot be imported:\n\n${result.error}`); return; }
  const project = createProject(result.manifest.name, result.files);
  await storage.save(project);
  state.projects.unshift(project);
  await openProject(project);
  status(`Imported ${result.manifest.name}.`);
});

function exportCurrent() {
  const result = exportPackage(state.project.files);
  if (result.error) {
    alert(`Fix these problems before exporting:\n\n${result.error}`);
    document.querySelector('[data-tab="problems"]').click();
    return null;
  }
  return result;
}

function download(result) {
  const url = URL.createObjectURL(new Blob([result.bytes], { type: "application/zip" }));
  const link = element("a", { href: url, download: result.fileName });
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

$("#export-package").addEventListener("click", () => { const result = exportCurrent(); if (result) download(result); });

$("#install-package").addEventListener("click", async () => {
  const result = exportCurrent();
  if (!result) return;
  const file = new File([result.bytes], result.fileName, { type: "application/zip" });
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: result.manifest.name });
      return;
    } catch (error) {
      if (error?.name === "AbortError") return;
    }
  }
  download(result);
  $("#install-body").replaceChildren(
    element("p", { textContent: `${result.fileName} was downloaded. To install it:` }),
    element("ol", {}, [
      element("li", { textContent: "Send the file to your iPhone with AirDrop, iCloud Drive, or email." }),
      element("li", { textContent: "On iPhone, open the file, tap Share, and choose ScriptWidget." }),
      element("li", { textContent: "Review the permissions, then add the widget from the Home Screen." }),
    ]),
    element("p", { className: "hint", textContent: "Opening this page in Safari on iPhone lets you send it to ScriptWidget directly from the share sheet." }),
    element("p", {}, [document.createTextNode("Need the app? "), element("a", { href: "https://apps.apple.com/us/app/scriptwidget/id1555600758", target: "_blank", rel: "noopener noreferrer", textContent: "Get ScriptWidget on the App Store" })]),
  );
  $("#install-dialog").showModal();
});

// MARK: - Templates

async function loadTemplates() {
  if (!state.templates) {
    const response = await fetch(new URL("./templates.json", document.baseURI));
    state.templates = (await response.json()).templates;
  }
  return state.templates;
}

function renderTemplates(query = "") {
  const needle = query.trim().toLowerCase();
  const items = state.templates.filter((template) => !needle || `${template.name} ${template.description} ${template.category}`.toLowerCase().includes(needle));
  $("#template-list").replaceChildren(...items.map((template) => {
    const button = element("button", { type: "button", className: "template-card" }, [
      element("span", { className: "template-name", textContent: template.name }),
      element("span", { className: "template-meta", textContent: template.source === "gallery" ? "Gallery" : template.category }),
      element("span", { className: "template-description", textContent: template.description }),
    ]);
    button.addEventListener("click", async () => {
      const project = projectFromTemplate(template);
      await storage.save(project);
      state.projects.unshift(project);
      $("#templates-dialog").close();
      await openProject(project);
    });
    return element("li", {}, [button]);
  }));
}

$("#open-templates").addEventListener("click", async () => {
  await loadTemplates();
  renderTemplates($("#template-search").value);
  $("#templates-dialog").showModal();
});
$("#template-search").addEventListener("input", (event) => renderTemplates(event.target.value));

$("#new-project").addEventListener("click", async () => {
  const project = createProject(`Widget ${state.projects.length + 1}`);
  await storage.save(project);
  state.projects.unshift(project);
  await openProject(project);
  editor.focus();
});

// MARK: - Start

// Text is measured during layout, so the fallback face must be ready first.
try { await document.fonts.load('17px "ScriptWidget Inter"'); } catch { /* the system fallback still renders */ }

window.addEventListener("beforeunload", () => { if (state.project) storage.save(state.project); });
await loadProjects();
try {
  await sandbox.ready;
  schedulePreview(0);
} catch (error) {
  status(`The preview runtime could not start: ${error.message}`);
}
if (!storage.persistent) $("#save-state").textContent = "Browser storage is unavailable; export to keep your work.";
