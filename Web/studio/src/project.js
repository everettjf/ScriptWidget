// Project helpers shared by the Studio UI and its tests. No DOM access.
import { decodeManifest, legacyManifest, newProjectFiles, validateManifest } from "../../preview-engine/src/package/index.js";
import { deviceProfiles } from "../../preview-engine/src/render/profiles.js";

/// WidgetKit family -> `$getenv("widget-size")` value (ScriptWidgetDataObject).
export const familyEnvironment = {
  systemSmall: "small", systemMedium: "medium", systemLarge: "large", systemExtraLarge: "extraLarge",
  systemExtraLargePortrait: "extraLargePortrait", accessoryCircular: "accessoryCircular",
  accessoryRectangular: "accessoryRectangular", accessoryInline: "accessoryInline",
};

export const familyLabels = {
  small: "Small", medium: "Medium", large: "Large", extraLarge: "Extra Large", extraLargePortrait: "Extra Large Portrait",
  accessoryCircular: "Lock Screen Circular", accessoryRectangular: "Lock Screen Rectangular", accessoryInline: "Lock Screen Inline",
};

/// Families the manifest declares that the selected device can show.
export function previewFamilies(manifest, profile) {
  const declared = (manifest?.supportedFamilies ?? ["systemSmall", "systemMedium", "systemLarge"]).map((family) => familyEnvironment[family]).filter(Boolean);
  const available = declared.filter((family) => deviceProfiles[profile]?.[family]);
  return available.length ? available : ["small", "medium", "large"].filter((family) => deviceProfiles[profile]?.[family]);
}

export const defaultFixtures = `{
  "fetch": [
    { "url": "https://api.example.com/data", "body": "{\\"value\\": 42}" }
  ],
  "location": { "latitude": 37.3349, "longitude": -122.009, "altitude": 0, "timestamp": "2026-01-01T12:00:00Z" }
}
`;

const base64ToBytes = (value) => {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
};

export function bytesToBase64(bytes) {
  let binary = "";
  for (let index = 0; index < bytes.length; index += 0x8000) binary += String.fromCharCode(...bytes.subarray(index, index + 0x8000));
  return btoa(binary);
}

const projectID = () => (globalThis.crypto?.randomUUID ? globalThis.crypto.randomUUID() : `p-${Date.now()}-${Math.random().toString(16).slice(2)}`);

export function createProject(name = "My Widget", files = newProjectFiles(name)) {
  return { id: projectID(), name, files, fixtures: defaultFixtures, createdAt: Date.now(), updatedAt: Date.now() };
}

/// A bundled template or Gallery widget as a Package 2.0 project.
export function projectFromTemplate(template) {
  const files = {};
  for (const [path, value] of Object.entries(template.files)) files[path] = typeof value === "string" ? value : base64ToBytes(value.base64);
  if (typeof files["widget.json"] !== "string") {
    let metadata = {};
    try { metadata = JSON.parse(files["meta.json"] ?? "{}"); } catch { metadata = {}; }
    const manifest = legacyManifest(template.name, metadata);
    manifest.id = `local.${projectID().toLowerCase()}`;
    files["widget.json"] = `${JSON.stringify(manifest, null, 2)}\n`;
  }
  return createProject(template.name, files);
}

export function manifestOf(project) {
  const text = project.files["widget.json"];
  if (typeof text !== "string") return { error: "widget.json is missing." };
  return decodeManifest(text);
}

export function packageReport(project) {
  const decoded = manifestOf(project);
  if (decoded.error) return { manifest: null, issues: [{ severity: "error", code: "manifest", message: decoded.error }], valid: false };
  const report = validateManifest(decoded.manifest, Object.keys(project.files));
  return { manifest: decoded.manifest, ...report };
}

export const textFiles = (files) => Object.fromEntries(Object.entries(files).filter(([, value]) => typeof value === "string"));

const imageTypes = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", webp: "image/webp", gif: "image/gif", heic: "image/heic" };

/// Package images as data URLs for the renderer.
export function resourceURLs(files) {
  const result = {};
  for (const [path, value] of Object.entries(files)) {
    const type = imageTypes[path.split(".").pop().toLowerCase()];
    if (type && value instanceof Uint8Array) result[path] = `data:${type};base64,${bytesToBase64(value)}`;
  }
  return result;
}

/// Package-relative file names a user may create in the Studio.
export function validNewPath(path, existing) {
  if (!/^[A-Za-z0-9][A-Za-z0-9._ -]*(\/[A-Za-z0-9][A-Za-z0-9._ -]*)*$/.test(path)) return "Use letters, numbers, dots, dashes, spaces, and / for folders.";
  if (path.split("/").length > 16) return "Folders can be at most 16 levels deep.";
  if (!/\.(jsx?|json|txt|md|csv)$/i.test(path) && !path.startsWith("image/")) return "Text files must end in .js, .jsx, .json, .txt, .md, or .csv.";
  if (Object.keys(existing).some((name) => name.toLowerCase() === path.toLowerCase())) return "A file with this name already exists.";
  return null;
}
