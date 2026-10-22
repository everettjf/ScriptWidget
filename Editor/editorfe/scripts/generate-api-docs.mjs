import { writeFile } from "node:fs/promises";
import { scriptWidgetAPI as api } from "../src/scriptWidgetAPI.js";
import { dataAPICatalog } from "../src/dataAPICatalog.js";

const outputURL = new URL("../../../docs/scriptwidget-runtime-api.md", import.meta.url);

const lines = [
  "# ScriptWidget Runtime API",
  "",
  `> Generated from Studio's static API metadata (schema v${api.schemaVersion}, runtime ${api.runtimeVersion}). The native runtime switch is authoritative. Do not edit by hand.`,
  "",
  "## Components",
  "",
];

for (const [name, component] of Object.entries(api.components)) {
  lines.push(`### \`<${name}>\``, "", component.documentation, "");
  const properties = { ...api.globalProperties, ...(component.properties ?? {}) };
  lines.push("| Property | Type | Required | Notes |", "| --- | --- | --- | --- |");
  for (const [propertyName, property] of Object.entries(properties)) {
    const notes = [property.documentation, property.values?.length ? `Values: ${property.values.map((value) => `\`${value}\``).join(", ")}` : "", property.deprecated ? `Deprecated: ${property.deprecated}` : ""].filter(Boolean).join(" ");
    lines.push(`| \`${propertyName}\` | \`${property.type}\` | ${property.required ? "Yes" : "No"} | ${notes} |`);
  }
  lines.push("");
}

lines.push("## Runtime functions", "");
for (const [name, definition] of Object.entries(api.functions)) {
  lines.push(`- \`${name}\`: ${definition.documentation}`);
}
lines.push("", "## Environment values", "", ...api.environmentValues.map((name) => `- \`${name}\``), "");

await writeFile(outputURL, `${lines.join("\n")}\n`);

const dataLines = [
  "# Data API capability catalog", "",
  "> Generated from `Editor/editorfe/src/dataAPICatalog.js`. Native JSExport protocols remain authoritative. This catalog is descriptive and grants no permissions.", "",
  "This covers device, system, health, location, calendar, reminders and photos data methods. Files, network, storage, rendering and runtime configuration retain their own contracts. Platforms list intended real-data support, not mocked browser execution; hardware and OS authorization still determine availability.", "",
  "Existing data-method return formats are unchanged. Present manifests now undergo package and minimum-version validation before execution. In particular, HealthKit does not expose individual read-denial status, and location cache presence is not proof that permission is still granted. Default mock values are illustrative, never measurements from the current device.", "",
  "| API | Minimum native API | Native platforms | Execution | Authorization | Operation |", "| --- | --- | --- | --- | --- | --- |",
  ...dataAPICatalog.map((item) => `| \`${item.id}(${item.arguments.join(", ")})\` | ${item.minimumRuntimeVersion} | ${item.platforms.join(", ")} | ${item.asynchronous ? "Promise" : "Synchronous"} | ${item.authorization} | ${item.operation} |`), "",
];
for (const group of [...new Set(dataAPICatalog.map((item) => item.group))]) {
  const entries = dataAPICatalog.filter((item) => item.group === group);
  dataLines.push(`## ${group}`, "", entries[0].notes, "");
  for (const entry of entries) {
    dataLines.push(`### \`${entry.id}\``, "", "Default editable preview sample:", "", "```json", JSON.stringify(entry.value, null, 2), "```", "");
  }
}
await writeFile(new URL("../../../docs/data-api-catalog.md", import.meta.url), `${dataLines.join("\n").trimEnd()}\n`);
