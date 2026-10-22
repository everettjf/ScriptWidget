import { javascriptLanguage } from "@codemirror/lang-javascript";
import { scriptWidgetAPI } from "./scriptWidgetAPI.js";
import { parseVisualLayout } from "./visualLayout.js";

const parser = javascriptLanguage.parser.configure({ dialect: "jsx" });
const children = node => { const result = []; for (let child = node.firstChild; child; child = child.nextSibling) result.push(child); return result; };
const fail = message => { throw new Error(message); };
export const widgetThemeFields = Object.freeze({
  background: { type: "color" }, surface: { type: "color" }, foreground: { type: "color" }, muted: { type: "color" }, accent: { type: "color" },
  titleFont: { values: scriptWidgetAPI.globalProperties.font.values }, bodyFont: { values: scriptWidgetAPI.globalProperties.font.values },
  fontDesign: { values: scriptWidgetAPI.globalProperties.fontDesign.values },
  corner: { type: "number", maximum: 48 }, padding: { type: "number", maximum: 48 }, spacing: { type: "number", maximum: 32 },
});
const base = { titleFont: "headline", bodyFont: "caption", fontDesign: "rounded", corner: 20, padding: 16, spacing: 10 };
export const widgetThemePresets = Object.freeze({
  Meadow: Object.freeze({ ...base, background: "#F2FAF5", surface: "#FFFFFF", foreground: "#193F31", muted: "#607C70", accent: "#328963" }),
  Paper: Object.freeze({ ...base, background: "#F4F7FD", surface: "#FFFFFF", foreground: "#243454", muted: "#687795", accent: "#4777D6" }),
  Peach: Object.freeze({ ...base, background: "#FFF5EE", surface: "#FFFFFF", foreground: "#56392C", muted: "#967461", accent: "#C86B43" }),
  Midnight: Object.freeze({ ...base, background: "#192332", surface: "#283548", foreground: "#F1F5FC", muted: "#AABAD0", accent: "#8EB7FF" }),
});
function validateToken(name, value) {
  if (!Object.hasOwn(widgetThemeFields, name)) fail("Unknown theme token.");
  const field = widgetThemeFields[name];
  if (field.type === "color" && !(typeof value === "string" && /^#[0-9a-f]{6}(?:[0-9a-f]{2})?$/i.test(value))) fail(`${name} needs a six or eight digit hex color.`);
  if (field.values && !field.values.includes(value)) fail(`${name} needs a supported font value.`);
  if (field.type === "number" && !(typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= field.maximum)) fail(`${name} needs a number from zero to ${field.maximum}.`);
}
function validateTokens(tokens) {
  if (!tokens || typeof tokens !== "object" || Array.isArray(tokens) || Object.keys(tokens).length !== Object.keys(widgetThemeFields).length) fail("A theme needs exactly the documented tokens.");
  for (const key of Object.keys(tokens)) validateToken(key, tokens[key]);
  return tokens;
}
export function importWidgetTheme(json) {
  if (typeof json !== "string" || new TextEncoder().encode(json).length > 4096) fail("Theme JSON is limited to 4 KiB.");
  const value = JSON.parse(json);
  if (!value || Array.isArray(value) || Object.keys(value).sort().join() !== "formatVersion,name,tokens" || value.formatVersion !== 1 || typeof value.name !== "string" || !value.name.trim() || /[\u0000-\u001f]/.test(value.name) || new TextEncoder().encode(value.name).length > 64) fail("Use a version 1 theme with a name of at most 64 bytes.");
  validateTokens(value.tokens); return value;
}
export function exportWidgetTheme(tokens, name = "My theme") {
  const json = JSON.stringify({ formatVersion: 1, name, tokens }, null, 2);
  importWidgetTheme(json); return json;
}

// This recognizes an authoring convention, not a new runtime global. Never eval source.
export function parseWidgetTheme(source) {
  const model = { source, tokens: null, ranges: {}, issue: "", canInitialize: false };
  try {
    if (typeof source !== "string" || new TextEncoder().encode(source).length > 512 * 1024) fail("Theme editing supports files up to 512 KiB.");
    const tree = parser.parse(source), definitions = [], references = [];
    tree.iterate({ enter(node) {
      if (node.type.isError) fail("Fix JavaScript syntax before editing the theme.");
      if (["VariableDefinition", "VariableName"].includes(node.name) && source.slice(node.from, node.to).includes("\\")) fail("Escaped identifiers stay in Code.");
      if (source.slice(node.from, node.to) === "widgetTheme" && ["VariableDefinition", "VariableName"].includes(node.name)) {
        (node.name === "VariableDefinition" ? definitions : references).push(node.node);
      }
    } });
    if (!definitions.length && !references.length) {
      const layout = parseVisualLayout(source);
      model.canInitialize = !layout.issue && layout.roots.length === 1 && !layout.nodes[0].locked;
      // Bind only an unconditional top-level render; don't capture function/block locals.
      let direct = false;
      for (const statement of children(tree.topNode)) {
        const call = statement.firstChild;
        if (statement.name === "ExpressionStatement" && call?.name === "CallExpression" && source.slice(call.firstChild.from, call.firstChild.to) === "$render" && call.from < layout.nodes[0].from && call.to > layout.nodes[0].to) direct = true;
      }
      model.canInitialize &&= direct;
      return model;
    }
    if (definitions.length !== 1) fail("Keep one top-level const widgetTheme object. Other bindings stay in Code.");
    const declaration = definitions[0].parent, parts = children(declaration);
    if (declaration.name !== "VariableDeclaration" || declaration.parent?.name !== "Script" || parts[0]?.name !== "const" || parts[1]?.from !== definitions[0].from || parts[2]?.name !== "Equals" || parts[3]?.name !== "ObjectExpression" || parts.slice(4).some(node => node.name !== ";")) fail("Theme editing needs a single top-level const widgetTheme = { … } declaration.");
    const tokens = {};
    for (const property of children(parts[3])) {
      if (["{", "}", ","].includes(property.name)) continue;
      const fields = children(property), rawKey = fields[0] ? source.slice(fields[0].from, fields[0].to) : "";
      const key = fields[0]?.name === "String" && rawKey.startsWith('"') ? JSON.parse(rawKey) : rawKey;
      if (property.name !== "Property" || fields.length !== 3 || !["PropertyDefinition", "String"].includes(fields[0].name) || fields[1].name !== ":" || !["String", "Number"].includes(fields[2].name) || Object.hasOwn(tokens, key)) fail("Theme tokens must be unique literal properties. Computed or dynamic values stay in Code.");
      let value;
      try { value = JSON.parse(source.slice(fields[2].from, fields[2].to)); } catch { fail("Theme values use JSON strings or numbers. Edit this declaration in Code."); }
      validateToken(key, value); tokens[key] = value; model.ranges[key] = { from: fields[2].from, to: fields[2].to };
    }
    validateTokens(tokens);
    for (const reference of references) {
      const member = reference.parent, parts = children(member), name = parts[2] ? source.slice(parts[2].from, parts[2].to) : "";
      if (member.name !== "MemberExpression" || parts[0].from !== reference.from || parts[1]?.name !== "." || parts[2]?.name !== "PropertyName" || !Object.hasOwn(widgetThemeFields, name)) fail("Theme references must read widgetTheme.token. Other uses stay in Code.");
      if (member.parent?.name === "MemberExpression") fail("Mutable theme references stay in Code.");
      for (let ancestor = member.parent; ancestor; ancestor = ancestor.parent) {
        if (["UpdateExpression", "PostfixExpression"].includes(ancestor.name) || (ancestor.name === "UnaryExpression" && /^(?:delete|\+\+|--)/.test(source.slice(ancestor.from, member.from).trim())) || (ancestor.name === "AssignmentExpression" && ancestor.firstChild.from <= member.from && ancestor.firstChild.to >= member.to) || ancestor.name === "ForOfSpec" || ancestor.name === "ForInSpec") fail("Mutable theme references stay in Code.");
      }
    }
    model.tokens = tokens;
  } catch (error) { model.issue = error.message; }
  return model;
}

export function editWidgetTheme(model, source, tokens) {
  if (model.source !== source || model.issue || !model.tokens) fail("Theme changed or is unsupported. Reopen Theme before editing.");
  validateTokens(tokens);
  const changes = Object.keys(widgetThemeFields).filter(key => tokens[key] !== model.tokens[key]).map(key => ({ ...model.ranges[key], insert: JSON.stringify(tokens[key]) })).sort((a, b) => a.from - b.from);
  return { changes };
}
export function initializeWidgetTheme(source, preset = "Meadow") {
  const model = parseWidgetTheme(source);
  if (!model.canInitialize || !Object.hasOwn(widgetThemePresets, preset)) fail("Start with a literal top-level layout without an existing widgetTheme binding.");
  const layout = parseVisualLayout(source), root = layout.nodes[0], changes = [];
  function bind(node, name, token, add = false) {
    const property = node.properties.find(value => value.name === name);
    if (node.locked || (property && !property.editable) || (!property && !add)) return;
    const insert = `${name}={widgetTheme.${token}}`;
    changes.push(property ? { from: property.from, to: property.to, insert } : { from: node.insertAt, to: node.insertAt, insert: ` ${insert}` });
  }
  for (const name of ["background", "corner", "padding"]) bind(root, name, name, true);
  if (root.structure) bind(root, "spacing", "spacing", true);
  for (const node of layout.nodes) {
    if (node.component === "Text") {
      const font = node.properties.find(value => value.name === "font")?.value;
      const title = ["headline", "largeTitle", "title", "title2", "title3"].includes(font);
      bind(node, "font", title ? "titleFont" : "bodyFont", true); bind(node, "color", title ? "foreground" : "muted", true);
      bind(node, "fontDesign", "fontDesign", true);
    } else if (node.component === "Icon") bind(node, "color", "accent", true);
  }
  // Keep the directive prologue intact (notably "use strict").
  let position = 0;
  for (const statement of children(parser.parse(source).topNode)) {
    if (statement.name === "LineComment" || statement.name === "BlockComment") continue;
    if (statement.name === "ExpressionStatement" && statement.firstChild?.name === "String") position = statement.to;
    else break;
  }
  changes.push({ from: position, to: position, insert: `\nconst widgetTheme = ${JSON.stringify(widgetThemePresets[preset], null, 2)};\n` });
  changes.sort((a, b) => a.from - b.from);
  let next = source;
  for (const change of [...changes].reverse()) next = next.slice(0, change.from) + change.insert + next.slice(change.to);
  if (!parseWidgetTheme(next).tokens || parseVisualLayout(next).issue) fail("This layout cannot be themed automatically. Your source was preserved.");
  return { changes };
}
