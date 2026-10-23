import test from "node:test";
import assert from "node:assert/strict";
import { EditorState } from "@codemirror/state";
import { history, undo, redo, isolateHistory } from "@codemirror/commands";
import { visualAssetCatalog, visualAssetLicense, visualImageResources, visualResources, visualResourcesChanged, insertVisualAsset } from "../src/visualAssets.js";
import { parseVisualLayout } from "../src/visualLayout.js";
import { initializeWidgetTheme, parseWidgetTheme } from "../src/widgetTheme.js";

const source = '// Keep my logic\nconst value="Dynamic";\n$render(<vstack spacing="8"><text>{value}</text><hstack></hstack></vstack>);\n';
const apply = (source, changes) => EditorState.create({doc:source}).update({changes}).state.doc.toString();
test("original assets insert ordinary editable JSX, preserve source and follow connected themes", () => {
  for (const themed of [false, true]) {
    const original = themed ? apply(source, initializeWidgetTheme(source).changes) : source;
    for (const kind of Object.keys(visualAssetCatalog)) {
      const model = parseVisualLayout(original), edit = insertVisualAsset(model,original,{id:model.roots[0],kind});
      const next = apply(original,edit.changes), parsed = parseVisualLayout(next);
      assert.equal(parsed.issue, ""); assert.ok(parsed.nodes.length > model.nodes.length);
      assert.ok(parsed.nodes.every(node=>!node.locked));
      assert.ok(next.includes('const value="Dynamic";')); assert.ok(next.includes('<text'));
      assert.equal(next.includes("widgetTheme.accent"),themed);
      if (themed) assert.equal(parseWidgetTheme(next).issue, "");
      assert.ok(next.includes(visualAssetLicense));
      const art=edit.changes.find(change=>change.from===model.nodes[0].contentTo).insert;
      assert.equal(next.replace(visualAssetLicense,"").replace(art,""),original);
      const secondModel=parseVisualLayout(next), second=insertVisualAsset(secondModel,next,{id:secondModel.roots[0],kind});
      assert.equal(second.changes.length,1,"license is retained once on repeated insertion");
    }
  }
});
test("package image names are bounded and match the native image/name contract", () => {
  const dangerous = ['image/a.png','image/a.png','image/My photo.JPG','image/雪.png','other/a.png','image/nested/a.png','image/../a.png','image/a..b.png','image/ leading.png','image/a\\b.png','image/a\0.png','image/a\u0080.png','/image/a.png','https://example.test/a.png','image/a.gif','image/a.heic','image/a.svg','image/'+'a'.repeat(256)+'.png','image/Case.png','image/case.png', 'image/e\u0301.png','image/é.png'];
  assert.deepEqual(visualImageResources(dangerous),['image/My photo.JPG','image/a.png','image/雪.png']);
  assert.deepEqual(visualImageResources(null),[]);
  assert.equal(visualImageResources(Array.from({length:300},(_,i)=>`image/${i}.png`)).length,256);
  assert.deepEqual(visualImageResources(Array.from({length:4097},(_,i)=>`image/${i}.png`)),[]);
  const path='image/a"{bad}.png', model=parseVisualLayout(source);
  const edit=insertVisualAsset(model,source,{id:model.roots[0],kind:"photo",path},[path]);
  const next=apply(source,edit.changes), parsed=parseVisualLayout(next);
  assert.equal(parsed.issue,"");
  assert.equal(parsed.nodes.find(node=>node.component==="Image").properties.find(prop=>prop.name==="name").value,'a"{bad}.png');
  for (const missing of ['image/a.png','../a.png','image/no.png']) assert.throws(()=>insertVisualAsset(model,source,{id:model.roots[0],kind:"photo",path:missing},[]),/resource list/);
});
test("assets reject stale source, unsupported structures and unknown kinds", () => {
  const model=parseVisualLayout(source);
  assert.throws(()=>insertVisualAsset(model,source+" ",{id:model.roots[0],kind:"leaf"}),/changed/);
  assert.throws(()=>insertVisualAsset(model,source,{id:model.nodes[1].id,kind:"leaf"}),/literal/);
  for(const kind of ["__proto__","constructor","toString","download"]) assert.throws(()=>insertVisualAsset(model,source,{id:model.roots[0],kind}),/catalog/);
  const dynamic=parseVisualLayout('$render(<vstack>{items.map(x=><text>{x}</text>)}</vstack>);');
  assert.throws(()=>insertVisualAsset(dynamic,dynamic.source,{id:dynamic.roots[0],kind:"pebble"}),/literal/);
  const full=parseVisualLayout('$render(<vstack>'+"<spacer/>".repeat(510)+'</vstack>);');
  assert.throws(()=>insertVisualAsset(full,full.source,{id:full.roots[0],kind:"pebble"}),/limits/);
  assert.equal(parseWidgetTheme('const value=<text>A</text>;$render(value);').canInitialize,false);
});
test("resource list effects never edit source or add undo entries; asset insertion is one undo transaction", () => {
  let state=EditorState.create({doc:source,extensions:[visualResources,history()]});
  const target={state,dispatch(transaction){state=transaction.state;target.state=state;}};
  let transaction=state.update({effects:visualResourcesChanged.of(['image/a.png','/private/a.png'])});
  assert.equal(transaction.docChanged,false); target.dispatch(transaction);
  assert.deepEqual(state.field(visualResources),['image/a.png']); assert.equal(undo(target),false);
  const model=parseVisualLayout(source),edit=insertVisualAsset(model,source,{id:model.roots[0],kind:"pebble"});
  target.dispatch(state.update({changes:edit.changes,annotations:isolateHistory.of("full")}));
  const next=state.doc.toString(); assert.notEqual(next,source);
  assert.equal(undo(target),true); assert.equal(state.doc.toString(),source);
  assert.equal(redo(target),true); assert.equal(state.doc.toString(),next);
  assert.deepEqual(EditorState.create({extensions:[visualResources]}).field(visualResources),[]);
});
