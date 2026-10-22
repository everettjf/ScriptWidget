import { EditorView, showPanel } from "@codemirror/view";
import { undo, redo, undoDepth, redoDepth, isolateHistory } from "@codemirror/commands";
import { parseVisualLayout, editVisualLayout, visualPropertyDefinitions } from "./visualLayout.js";
import { parseWidgetTheme, initializeWidgetTheme, editWidgetTheme, widgetThemeFields, widgetThemePresets, importWidgetTheme, exportWidgetTheme } from "./widgetTheme.js";
import { visualResources, visualResourcesChanged, setVisualLayoutResources, visualAssetCatalog, insertVisualAsset } from "./visualAssets.js";

const supportedProperty = definition => ["string", "number", "number|string", "date|number", "boolean", "enum", "color", "url", "action-id", "storage-key"].includes(definition.type);
function element(tag, className, text) {
  const dom = document.createElement(tag); if (className) dom.className = className; if (text !== undefined) dom.textContent = text; return dom;
}
function layoutPanel(view, options) {
  const dom = element("section", "sw-layout"), header = element("div", "sw-layout-header"), body = element("div", "sw-layout-body");
  dom.setAttribute("aria-label", "Visual layout editor");
  let open = false, mode = "layout", model = null, selectedID = null, propertyName = "", dragging = null, destroyed = false;
  const token = String(Math.random());
  const button = (label, action, disabled = false) => {
    const value = element("button", "sw-layout-button", label); value.type = "button"; value.disabled = disabled;
    value.addEventListener("click", action); return value;
  };
  const toggle = button("Layout", () => { open = mode === "layout" ? !open : true; mode = "layout"; render(); view.requestMeasure(); });
  toggle.classList.add("sw-layout-toggle"); toggle.setAttribute("aria-expanded", "false");
  const hint = element("span", "sw-layout-hint", "Select layers and edit literal JSX"), undoButton = button("Undo", () => undo(view)), redoButton = button("Redo", () => redo(view));
  const themeToggle = button("Theme", () => { open = mode === "theme" ? !open : true; mode = "theme"; render(); view.requestMeasure(); });
  themeToggle.setAttribute("aria-expanded", "false");
  const assetsToggle = button("Assets", () => { open = mode === "assets" ? !open : true; mode = "assets"; render(); view.requestMeasure(); });
  assetsToggle.setAttribute("aria-expanded", "false");
  header.append(toggle, themeToggle, assetsToggle, hint, undoButton, redoButton); dom.append(header, body);
  body.hidden = undoButton.hidden = redoButton.hidden = true;
  const error = element("p", "sw-layout-error"); error.setAttribute("role", "alert"); error.hidden = true; dom.append(error);
  function renderAssets() {
    model = parseVisualLayout(view.state.doc.toString());
    const panel = element("div", "sw-layout-inspector sw-theme-inspector"); body.replaceChildren(panel);
    panel.append(element("div", "sw-layout-title", "Widget assets"));
    panel.append(element("p", "sw-layout-notice", "Insert editable original JSX or a package image. Originals follow connected theme colors; pet artwork is static. Import photos with the app's existing image tools or Web Studio's Add image."));
    if (model.issue) { panel.append(element("p", "sw-layout-notice", model.issue)); return; }
    const containers = model.nodes.filter(node => node.structure), destination = element("select"); destination.setAttribute("aria-label", "Asset destination");
    for (const node of containers) { const option = element("option", "", `${node.tag} · line ${view.state.doc.lineAt(node.from).number}`); option.value = node.id; destination.append(option); }
    if (containers.some(node => node.id === selectedID)) destination.value = selectedID;
    else selectedID = destination.value;
    destination.addEventListener("change", () => { selectedID = destination.value; }); panel.append(destination);
    const disabled = view.state.readOnly || !containers.length;
    if (!containers.length) panel.append(element("p", "sw-layout-notice", "Add a stack/grid with literal JSX children in Code to insert assets."));
    function insert(kind, path) {
      try {
        if (view.state.readOnly) throw new Error("This document is read only.");
        const edit = insertVisualAsset(model, view.state.doc.toString(), { id: destination.value, kind, path }, view.state.field(visualResources));
        selectedID = destination.value; error.hidden = true;
        view.dispatch({ changes: edit.changes, selection: {anchor:edit.selectedFrom}, annotations:isolateHistory.of("full"), userEvent:"input.asset", scrollIntoView:true });
      } catch (reason) { error.textContent = reason.message; error.hidden = false; }
    }
    for (const [kind, asset] of Object.entries(visualAssetCatalog)) {
      const row = element("div", "sw-layout-actions"); row.append(button(`Insert ${asset.name}`, () => insert(kind), disabled), element("span", "", asset.description)); panel.append(row);
    }
    panel.append(element("div", "sw-layout-title", "Package images"));
    const resources = view.state.field(visualResources);
    const images = element("select"); images.setAttribute("aria-label", "Package image");
    for (const path of resources) { const option = element("option", "", path); option.value = path; images.append(option); }
    images.disabled = !resources.length;
    panel.append(images, button("Insert package image", () => insert("photo", images.value), disabled || !resources.length));
    if (!resources.length) panel.append(element("p", "sw-layout-notice", "No supported images in image/. Add a PNG, JPEG or WebP to the package, then refresh or reopen the editor."));
    if (options.refreshResources) panel.append(button("Refresh images", async () => {
      try {
        const paths = await options.refreshResources();
        if (!destroyed) { error.hidden = true; setVisualLayoutResources(view, paths); }
      } catch { if (!destroyed) { error.textContent = "Images could not be refreshed. Reopen this document and try again."; error.hidden = false; } }
    }));
    panel.append(element("p", "sw-layout-notice", "Bloom mark, Leaf mark and Pebble friend: original ScriptWidget geometry, MIT licensed. Package photos retain their own rights. See the Studio assets documentation."));
  }
  function themeEdit(action, expected) {
    try {
      if (view.state.readOnly) throw new Error("This document is read only.");
      const source = view.state.doc.toString();
      if (source !== expected) throw new Error("Source changed. Reopen Theme before editing.");
      const edit = action(source); error.hidden = true;
      if (edit.changes.length) view.dispatch({ changes: edit.changes, annotations: isolateHistory.of("full"), userEvent: "input.theme" });
    } catch (reason) { error.textContent = reason.message; error.hidden = false; }
  }
  function renderTheme() {
    const source = view.state.doc.toString(), theme = parseWidgetTheme(source), locked = view.state.readOnly;
    const panel = element("div", "sw-layout-inspector sw-theme-inspector"); body.replaceChildren(panel);
    panel.append(element("div", "sw-layout-title", "Widget theme"));
    panel.append(element("p", "sw-layout-notice", "Saved as ordinary JavaScript with your widget. Dynamic values stay in Code. Applying a theme changes the connected colors, fonts and spacing."));
    if (theme.issue) { panel.append(element("p", "sw-layout-notice", theme.issue)); return; }
    if (!theme.tokens) {
      panel.append(button("Connect layout to Meadow theme", () => themeEdit(value => initializeWidgetTheme(value), source), locked || !theme.canInitialize));
      if (!theme.canInitialize) panel.append(element("p", "sw-layout-notice", "Use a literal top-level $render layout, or define the documented widgetTheme object in Code."));
      return;
    }
    const presets = element("div", "sw-layout-actions");
    for (const [name, tokens] of Object.entries(widgetThemePresets)) presets.append(button(name, () => themeEdit(value => editWidgetTheme(theme, value, tokens), source), locked));
    panel.append(presets);
    for (const [name, field] of Object.entries(widgetThemeFields)) {
      const form = element("form", "sw-layout-form"), label = element("label", "", name), input = element(field.values ? "select" : "input");
      if (field.values) for (const value of field.values) { const option = element("option", "", value); option.value = value; input.append(option); }
      if (field.type === "number") { input.type = "number"; input.min = "0"; input.max = String(field.maximum); input.step = "any"; }
      input.value = String(theme.tokens[name]); input.setAttribute("aria-label", `Theme ${name}`); input.disabled = locked;
      const submit = button(`Apply ${name}`, () => {}, locked); submit.type = "submit";
      form.append(label, input, submit); form.addEventListener("submit", event => {
        event.preventDefault();
        const token = field.type === "number" ? (input.value.trim() ? Number(input.value) : NaN) : input.value;
        themeEdit(value => editWidgetTheme(theme, value, { ...theme.tokens, [name]: token }), source);
      }); panel.append(form);
    }
    const json = element("textarea"); json.rows = 5; json.setAttribute("aria-label", "Reusable theme JSON"); json.value = exportWidgetTheme(theme.tokens);
    panel.append(element("label", "", "Copy this JSON to reuse a theme, or paste a version 1 theme and import it."), json,
      button("Import theme JSON", () => themeEdit(value => editWidgetTheme(theme, value, importWidgetTheme(json.value).tokens), source), locked));
  }
  function apply(operation, expected = model?.source) {
    try {
      if (view.state.readOnly) throw new Error("This document is read only.");
      if (expected !== view.state.doc.toString()) throw new Error("Source changed during this operation. Select the layer again.");
      const edit = editVisualLayout(model, view.state.doc.toString(), operation);
      error.hidden = true;
      if (!edit.changes.length) return;
      view.dispatch({ changes: edit.changes, selection: { anchor: edit.selectedFrom }, annotations: isolateHistory.of("full"), userEvent: "input.layout", scrollIntoView: true });
    } catch (reason) { error.textContent = reason.message; error.hidden = false; }
  }
  function select(node) {
    selectedID = node.id; propertyName = "";
    view.dispatch({ selection: { anchor: node.from, head: node.to }, scrollIntoView: true, userEvent: "select.layout" });
    render();
  }
  function render() {
    toggle.setAttribute("aria-expanded", String(open && mode === "layout")); themeToggle.setAttribute("aria-expanded", String(open && mode === "theme"));
    assetsToggle.setAttribute("aria-expanded", String(open && mode === "assets"));
    body.hidden = !open; undoButton.hidden = redoButton.hidden = !open; hint.hidden = open;
    undoButton.disabled = view.state.readOnly || undoDepth(view.state) === 0; redoButton.disabled = view.state.readOnly || redoDepth(view.state) === 0;
    if (!open) return;
    if (mode === "assets") { renderAssets(); return; }
    if (mode === "theme") { renderTheme(); return; }
    model = parseVisualLayout(view.state.doc.toString()); body.replaceChildren();
    if (model.issue) { body.append(element("p", "sw-layout-notice", model.issue)); return; }
    const position = view.state.selection.main.from;
    const atCursor = model.nodes.filter(node => node.from <= position && position < node.to).at(-1);
    const selected = model.nodes.find(node => node.id === selectedID && node.from <= position && position <= node.to) ?? atCursor ?? model.nodes[0];
    selectedID = selected.id;
    const list = element("div", "sw-layout-layers"); list.setAttribute("role", "tree"); list.setAttribute("aria-label", "Layout layers");
    const locked = view.state.readOnly;
    const titleOf = node => {
      const label = node.text ?? node.properties.find(property => property.name === "text" && property.editable && typeof property.value === "string")?.value;
      return `<${node.tag}>${label ? ` · ${label.slice(0, 32)}` : ""}${node.locked ? " · locked" : ""}`;
    };
    for (const [index, node] of model.nodes.entries()) {
      const parent = model.nodes.find(row => row.id === node.parentID), movable = !locked && !node.locked && parent?.structure;
      const row = button(titleOf(node), () => select(node)); row.classList.add("sw-layout-layer"); row.dataset.layerId = node.id;
      row.style.paddingInlineStart = `${8 + node.depth * 14}px`;
      row.setAttribute("role", "treeitem"); row.setAttribute("aria-level", String(node.depth + 1)); row.setAttribute("aria-selected", String(node.id === selected.id));
      row.tabIndex = node.id === selected.id ? 0 : -1; row.draggable = Boolean(movable);
      row.addEventListener("keydown", event => {
        let next;
        if (event.key === "ArrowUp") next = model.nodes[Math.max(0, index - 1)];
        if (event.key === "ArrowDown") next = model.nodes[Math.min(model.nodes.length - 1, index + 1)];
        if (event.key === "ArrowLeft") next = parent;
        if (event.key === "ArrowRight") next = model.nodes.find(value => value.id === node.children[0]);
        if (event.key === "Home") next = model.nodes[0]; if (event.key === "End") next = model.nodes.at(-1);
        if (next) { event.preventDefault(); event.stopPropagation(); select(next); listOfLayers().find(value => value.dataset.layerId === next.id)?.focus(); }
      });
      row.addEventListener("dragstart", event => {
        if (!movable) { event.preventDefault(); return; }
        dragging = { id: node.id, source: model.source }; event.dataTransfer.setData("application/x-scriptwidget-layer", token); event.dataTransfer.effectAllowed = "move";
      });
      row.addEventListener("dragover", event => { if (dragging && parent?.structure && node.id !== dragging.id) { event.preventDefault(); event.dataTransfer.dropEffect = "move"; } });
      row.addEventListener("drop", event => {
        if (!dragging || event.dataTransfer.getData("application/x-scriptwidget-layer") !== token || !parent?.structure) return;
        event.preventDefault(); const held = dragging; dragging = null;
        apply({ type: "move", id: held.id, parentID: parent.id, index: parent.children.filter(id => id !== held.id).indexOf(node.id) }, held.source);
      });
      row.addEventListener("dragend", () => { dragging = null; }); list.append(row);
    }
    function listOfLayers() { return [...dom.querySelectorAll(".sw-layout-layer")]; }
    const inspector = element("div", "sw-layout-inspector"), heading = element("div", "sw-layout-title", `<${selected.tag}>`);
    inspector.append(heading);
    if (locked || selected.locked) inspector.append(element("p", "sw-layout-notice", locked ? "This document is read only." : selected.reason));
    if (!locked && !selected.locked) {
      if (selected.textEditable) {
        const form = element("form", "sw-layout-form"), label = element("label", "", "Text"), input = element("input"); input.value = selected.text; input.setAttribute("aria-label", "Layer text");
        const submit = button("Apply text", () => {}); submit.type = "submit"; form.append(label, input, submit);
        form.addEventListener("submit", event => { event.preventDefault(); apply({type: "text",id:selected.id,value:input.value}); }); inspector.append(form);
      }
      const definitions = Object.entries(visualPropertyDefinitions(selected)).filter(([, definition]) => supportedProperty(definition));
      const propertyForm = element("form", "sw-layout-form"), choose = element("select"); choose.setAttribute("aria-label", "Layout property");
      for (const [name] of definitions) { const option = element("option", "", name); option.value = name; choose.append(option); }
      if (!definitions.some(([name]) => name === propertyName)) propertyName = selected.structure ? "alignment" : "color";
      choose.value = propertyName; if (!choose.value) { choose.selectedIndex = 0; propertyName = choose.value; }
      const controls = element("div", "sw-layout-property"); propertyForm.append(choose, controls);
      function renderProperty() {
        propertyName = choose.value;
        const definition = visualPropertyDefinitions(selected)[propertyName], existing = selected.properties.find(value => value.name === propertyName);
        controls.replaceChildren();
        propertyForm.onsubmit = event => event.preventDefault();
        if (existing && !existing.editable) { controls.append(element("span", "sw-layout-notice", "Dynamic value: edit it in Code. Connected widgetTheme tokens can be changed in Theme.")); return; }
        const input = element(definition.values || definition.type === "boolean" ? "select" : "input"); input.setAttribute("aria-label", "Layout property value");
        for (const value of definition.values ?? (definition.type === "boolean" ? [true, false] : [])) { const option = element("option", "", String(value)); option.value = String(value); input.append(option); }
        input.value = existing ? String(existing.value) : definition.values?.[0] ?? (definition.type === "boolean" ? "true" : "");
        const submit = button("Apply", () => {}); submit.type = "submit";
        controls.append(input, submit, button("Remove", () => apply({type:"property",id:selected.id,name:propertyName,remove:true}), !existing || definition.required));
        propertyForm.onsubmit = event => {
          event.preventDefault();
          const value = definition.type === "boolean" ? input.value === "true" : definition.type === "number" ? (input.value.trim() ? Number(input.value) : NaN) : input.value;
          apply({type:"property",id:selected.id,name:propertyName,value});
        };
      }
      choose.addEventListener("change", renderProperty); renderProperty(); inspector.append(propertyForm);
      const parent = model.nodes.find(node => node.id === selected.parentID), index = parent?.children.indexOf(selected.id) ?? -1;
      const actions = element("div", "sw-layout-actions");
      actions.append(button("Move up", () => apply({type:"move",id:selected.id,parentID:parent.id,index:index-1}), !parent?.structure || index <= 0),
        button("Move down", () => apply({type:"move",id:selected.id,parentID:parent.id,index:index+1}), !parent?.structure || index >= parent.children.length-1),
        button("Delete layer", () => apply({type:"remove",id:selected.id}), !parent?.structure));
      inspector.append(actions);
      if (parent?.structure) {
        const destinations = model.nodes.filter(node => node.structure && !(node.from >= selected.from && node.to <= selected.to));
        const selectParent = element("select"); selectParent.setAttribute("aria-label", "Move layer into container");
        for (const node of destinations) { const option = element("option", "", `${node.tag} · line ${view.state.doc.lineAt(node.from).number}`); option.value = node.id; selectParent.append(option); }
        inspector.append(selectParent, button("Move inside", () => { const target = model.nodes.find(node => node.id === selectParent.value); apply({type:"move",id:selected.id,parentID:target.id,index:target.children.filter(id=>id!==selected.id).length}); }, !destinations.length));
      }
      if (selected.structure) {
        const add = element("div", "sw-layout-actions");
        for (const [kind, title] of [["text", "Add text"], ["stack", "Add stack"], ["spacer", "Add spacer"], ["icon", "Add icon"]]) add.append(button(title, () => apply({type:"add",id:selected.id,kind})));
        inspector.append(add);
      }
    }
    const preserved = selected.properties.filter(property => !property.editable).map(property => property.name);
    if (preserved.length) inspector.append(element("p", "sw-layout-notice", `Preserved in Code: ${preserved.join(", ")}`));
    if (!selected.structure && selected.children.length) inspector.append(element("p", "sw-layout-notice", "This child structure stays in Code. Reordering is available on literal stack/grid children."));
    body.append(list, inspector);
  }
  return {dom,top:true,update(update) {
    if (!open) return;
    const position = view.state.selection.main.from;
    const next = model?.nodes.filter(node => node.from <= position && position < node.to).at(-1)?.id;
    const resourcesChanged = update.transactions.some(transaction => transaction.effects.some(effect => effect.is(visualResourcesChanged)));
    if (update.docChanged || resourcesChanged || update.startState.readOnly !== view.state.readOnly || (update.selectionSet && next !== selectedID)) { if (update.docChanged && mode !== "assets") selectedID = null; render(); }
    undoButton.disabled = view.state.readOnly || undoDepth(view.state) === 0; redoButton.disabled = view.state.readOnly || redoDepth(view.state) === 0;
  },destroy() { destroyed = true; }};
}

const theme = EditorView.baseTheme({
  ".sw-layout": {fontFamily:"system-ui, sans-serif",fontSize:"12px",backgroundColor:"#f6f7fa",color:"#272a34",borderBottom:"1px solid #dce0e9"},
  "&dark .sw-layout": {backgroundColor:"#252830",color:"#eceef5",borderColor:"#414552"},
  ".sw-layout-header": {display:"flex",alignItems:"center",flexWrap:"wrap",gap:"8px",padding:"6px 10px"},
  ".sw-layout-toggle": {fontWeight:"600"}, ".sw-layout-hint": {opacity:"0.65",fontSize:"11px"},
  ".sw-layout-button": {fontFamily:"inherit",fontSize:"11px",color:"inherit",backgroundColor:"transparent",border:"1px solid #a0a5b655",borderRadius:"6px",padding:"4px 8px",cursor:"pointer",whiteSpace:"nowrap"},
  ".sw-layout-button:disabled": {opacity:"0.4",cursor:"default"},
  ".sw-layout-body": {display:"grid",gridTemplateColumns:"minmax(120px, 1fr) minmax(180px, 1.6fr)",maxHeight:"280px",overflow:"auto",borderTop:"1px solid #a0a5b633"},
  ".sw-layout-body[hidden]": {display:"none"},
  ".sw-layout-layers": {padding:"6px 2px",overflow:"auto",borderRight:"1px solid #a0a5b633"},
  ".sw-layout-layer": {display:"block",border:0,borderRadius:"4px",width:"100%",textAlign:"left",overflow:"hidden",textOverflow:"ellipsis",margin:"1px 0",paddingBlock:"6px"},
  '.sw-layout-layer[aria-selected="true"]': {backgroundColor:"#4085f52b",color:"inherit"},
  ".sw-layout-inspector": {padding:"8px 10px",display:"flex",alignItems:"start",flexDirection:"column",gap:"8px",minWidth:0},
  ".sw-theme-inspector": {gridColumn:"1 / -1"},
  ".sw-theme-inspector textarea": {boxSizing:"border-box",width:"100%",fontFamily:"monospace",backgroundColor:"transparent",color:"inherit",border:"1px solid #a0a5b666",borderRadius:"5px"},
  ".sw-layout-title": {fontWeight:"600"},
  ".sw-layout-form": {display:"flex",flexWrap:"wrap",alignItems:"center",gap:"5px",width:"100%"},
  ".sw-layout-property,.sw-layout-actions": {display:"flex",flexWrap:"wrap",gap:"5px",alignItems:"center"},
  ".sw-layout input,.sw-layout select": {fontFamily:"inherit",fontSize:"12px",minWidth:0,maxWidth:"100%",padding:"4px 6px",border:"1px solid #a0a5b666",borderRadius:"5px",backgroundColor:"transparent",color:"inherit"},
  ".sw-layout-notice": {margin:"8px",lineHeight:"1.5",fontSize:"11px",opacity:"0.7"},
  ".sw-layout-body > .sw-layout-notice": {gridColumn:"1 / -1"},
  ".sw-layout-error": {margin:"0 10px 6px",color:"#b32636",fontSize:"12px"},
  "&dark .sw-layout-error": {color:"#ff99a4"},
  ".sw-layout button:focus-visible,.sw-layout input:focus-visible,.sw-layout select:focus-visible": {outline:"2px solid #4085f5",outlineOffset:"1px"},
  "@media (max-width: 480px)": {".sw-layout-body":{gridTemplateColumns:"minmax(90px, 1fr) minmax(150px, 1.6fr)"},".sw-layout-hint":{display:"none"}},
});
export function visualLayoutEditor(options = {}) { return [theme, visualResources, showPanel.of(view => layoutPanel(view, options))]; }
