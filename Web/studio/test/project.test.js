import assert from "node:assert/strict";
import test from "node:test";
import { exportPackage } from "../../preview-engine/src/package/index.js";
import { createProject, familyEnvironment, packageReport, previewFamilies, projectFromTemplate, resourceURLs, textFiles, validNewPath } from "../src/project.js";

test("new projects are valid Package 2.0 packages", () => {
  const project = createProject("Hello");
  const report = packageReport(project);
  assert.equal(report.valid, true);
  assert.equal(report.manifest.name, "Hello");
  assert.equal(exportPackage(project.files).fileName, "Hello.swt");
});

test("legacy templates gain a manifest", () => {
  const project = projectFromTemplate({ name: "Clock", files: { "main.jsx": "$render(<text/>)", "meta.json": "{\"description\":\"A clock\"}", "image/a.png": { base64: "iVBORw0K" } } });
  const report = packageReport(project);
  assert.equal(report.valid, true);
  assert.match(report.manifest.id, /^local\./);
  assert.equal(report.manifest.description, "A clock");
  assert.ok(project.files["image/a.png"] instanceof Uint8Array);
  assert.match(resourceURLs(project.files)["image/a.png"], /^data:image\/png;base64,iVBORw0K/);
  assert.deepEqual(Object.keys(textFiles(project.files)).sort(), ["main.jsx", "meta.json", "widget.json"]);
});

test("preview families follow the manifest and the device", () => {
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemSmall", "accessoryCircular"] }, "iphone-393"), ["small", "accessoryCircular"]);
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemExtraLarge"] }, "iphone-393"), ["small", "medium", "large"]);
  assert.deepEqual(previewFamilies({ supportedFamilies: ["systemExtraLarge"] }, "ipad-1024"), ["extraLarge"]);
  assert.equal(familyEnvironment.systemMedium, "medium");
});

test("new file names stay inside safe package paths", () => {
  assert.equal(validNewPath("lib/util.js", {}), null);
  assert.match(validNewPath("../x.js", {}), /letters/);
  assert.match(validNewPath("notes.exe", {}), /must end/);
  assert.match(validNewPath("Main.jsx", { "main.jsx": "" }), /already exists/);
});
