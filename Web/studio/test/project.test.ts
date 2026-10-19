import assert from "node:assert/strict";
import test from "node:test";
import { exportPackage } from "../../preview-engine/src/package/index.js";
import {
  createProject, familyEnvironment, initialPath, packageReport, previewFamilies, projectFromTemplate, resourceURLs, sortedPaths, textFiles, validNewPath,
  type Template,
} from "../src/project.ts";

test("new projects are valid Package 2.0 packages", () => {
  const project = createProject("Hello");
  const report = packageReport(project);
  assert.equal(report.valid, true);
  assert.equal(report.manifest?.name, "Hello");
  const exported = exportPackage(project.files);
  assert.equal(exported.error, undefined);
  assert.equal(exported.fileName, "Hello.swt");
});

test("legacy templates gain a manifest", () => {
  const template: Template = {
    id: "template/Clock", source: "template", name: "Clock", description: "", category: "starter",
    files: { "main.jsx": "$render(<text/>)", "meta.json": "{\"description\":\"A clock\"}", "image/a.png": { base64: "iVBORw0K" } },
  };
  const project = projectFromTemplate(template);
  const report = packageReport(project);
  assert.equal(report.valid, true);
  assert.match(report.manifest?.id ?? "", /^local\./);
  assert.equal(report.manifest?.description, "A clock");
  assert.ok(project.files["image/a.png"] instanceof Uint8Array);
  assert.match(resourceURLs(project.files)["image/a.png"] ?? "", /^data:image\/png;base64,iVBORw0K/);
  assert.deepEqual(Object.keys(textFiles(project.files)).sort(), ["main.jsx", "meta.json", "widget.json"]);
});

test("template copies declare the sizes their script handles", () => {
  const source = 'const size = $getenv("widget-size"); if (size === "accessoryCircular") $render(<text/>); else if (size === "extraLarge") $render(<text/>); else $render(<text/>);';
  const adaptive = projectFromTemplate({ id: "template/A", source: "template", name: "A", description: "", category: "time", files: { "main.jsx": source } });
  assert.deepEqual(packageReport(adaptive).manifest?.supportedFamilies, ["systemSmall", "systemMedium", "systemLarge", "systemExtraLarge", "accessoryCircular"]);
  const plain = projectFromTemplate({ id: "template/B", source: "template", name: "B", description: "", category: "time", files: { "main.jsx": "$render(<text/>)" } });
  assert.deepEqual(packageReport(plain).manifest?.supportedFamilies, ["systemSmall", "systemMedium", "systemLarge"]);
});

test("preview families follow the manifest and the device", () => {
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemSmall", "accessoryCircular"] }, "iphone-393"), ["small", "accessoryCircular"]);
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemExtraLarge"] }, "iphone-393"), ["small", "medium", "large"]);
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemExtraLarge"] }, "ipad-1024"), ["extraLarge"]);
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemSmall", "systemExtraLarge"] }, "macos"), ["small", "extraLarge"]);
  assert.equal(familyEnvironment.systemMedium, "medium");
});

test("new file names stay inside safe package paths", () => {
  assert.equal(validNewPath("lib/util.js", {}), null);
  assert.match(validNewPath("../x.js", {}) ?? "", /letters/);
  assert.match(validNewPath("notes.exe", {}) ?? "", /must end/);
  assert.match(validNewPath("Main.jsx", { "main.jsx": "" }) ?? "", /already exists/);
});

test("the entry opens first and widget.json leads the file list", () => {
  assert.equal(initialPath(createProject("Order")), "main.jsx");
  assert.deepEqual(sortedPaths({ "b.js": "", "widget.json": "", "a.js": "" }), ["widget.json", "a.js", "b.js"]);
});
