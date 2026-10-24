import test from 'node:test';
import assert from 'node:assert/strict';
import { writeArchive } from '../../preview-engine/src/package/archive.js';
import { newProjectFiles } from '../../preview-engine/src/package/index.js';
import { consumePreviewFragment, importPreviewFragment } from '../src/previewHandoff.ts';
const link = (bytes: Uint8Array) => '#sw-preview=v1.' + Buffer.from(bytes).toString('base64url');

test('handoff preserves Unicode, nested source and binary resources without executing scripts', async () => {
  const files = {...newProjectFiles('阅读 ✓', 'throw new Error("must not run on import");'), 'lib/helper.js':'const label="你好";', 'image/sample.bin':new Uint8Array([0,255,37])};
  const imported = await importPreviewFragment(link(writeArchive('Widget', files)));
  assert.deepEqual(imported.files, files);
  assert.equal(imported.manifest.name,'阅读 ✓');
});
test('fragment is consumed before asynchronous import and unrelated hashes stay intact', () => {
  const writes: unknown[][]=[];
  const history={state:{keep:1},replaceState:(...args: unknown[])=>{writes.push(args);}};
  assert.equal(consumePreviewFragment({hash:'#section',pathname:'/studio/',search:'?x=1'},history),null);
  assert.equal(writes.length,0);
  assert.equal(consumePreviewFragment({hash:'#sw-preview=v9.bad',pathname:'/studio/',search:'?x=1'},history),'#sw-preview=v9.bad');
  assert.deepEqual(writes,[[{keep:1},'', '/studio/?x=1']]);
});
test('malformed, unknown, oversized or unsafe links fail closed', async () => {
  for(const fragment of ['#sw-preview=v2.a','#sw-preview=v1.','#sw-preview=v1.%%%','#sw-preview=v1.a','#sw-preview=v1.AB','#sw-preview=v1.'+'a'.repeat(60001),link(new Uint8Array([1,2,3]))])await assert.rejects(importPreviewFragment(fragment));
  await assert.rejects(importPreviewFragment(link(writeArchive('Widget',{'widget.json':'{"formatVersion":99}','main.jsx':'$render(<text>Bad</text>);'}))));
  const archive=Buffer.from(writeArchive('Widget',newProjectFiles('Safe')));
  // Same byte length: corrupt both ZIP path records without changing file CRCs.
  const unsafe=Buffer.from(archive.toString('latin1').replaceAll('Widget/main.jsx','Widget/../a.jsx'),'latin1');
  await assert.rejects(importPreviewFragment(link(unsafe)),/unsafe|path/i);
});
