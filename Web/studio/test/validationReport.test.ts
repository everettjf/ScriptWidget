import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { packageSourceHash, previewIsCurrent, validationReport } from '../src/validationReport.ts';
import { createProject } from '../src/project.ts';
import type { PreviewSettings, PreviewState } from '../src/hooks/usePreview.ts';

const settings: PreviewSettings = {profile:'macos',family:'medium',appearance:'light',renderingMode:'fullColor',parameter:'',timelineDate:'',reduceTransparency:false,reduceMotion:false};
test('source fingerprints match the native byte protocol and include binary resources',async()=>{
  const files={'main.jsx':'$render(<text>✓</text>);','image/dot.png':new Uint8Array([0,255,42])};
  const header=Buffer.alloc(8);header.writeBigUInt64BE(2n);
  const parts=[Buffer.from('ScriptWidgetSource/v1\n'),header];
  for(const name of ['image/dot.png','main.jsx'])for(const value of [Buffer.from(name),typeof files[name as keyof typeof files]==='string'?Buffer.from(files[name as 'main.jsx']):Buffer.from(files[name as 'image/dot.png'])]){
    const length=Buffer.alloc(8);length.writeBigUInt64BE(BigInt(value.length));parts.push(length,value);
  }
  assert.equal(await packageSourceHash(files),createHash('sha256').update(Buffer.concat(parts)).digest('hex'));
  assert.equal(await packageSourceHash({...files,'__Build/cache':'ignored'}),await packageSourceHash(files));
  assert.notEqual(await packageSourceHash({...files,'image/dot.png':new Uint8Array([1])}),await packageSourceHash(files));
});
test('old preview reports cannot certify a later edit or different mock/settings',async()=>{
  const project=createProject('Test');
  const preview:PreviewState={input:{files:project.files,fixtures:project.fixtures,settings},output:{kind:'error',errorKind:'scriptException',message:'broken'},problems:[{severity:'error',text:'broken'}],logs:[]};
  assert.equal(previewIsCurrent(project,settings,preview),true);
  const report=await validationReport(project,settings,preview);
  assert.equal(report.status,'failed');assert.equal(report.backend,'web');assert.equal(report.checks.native,'notRun');
  await assert.rejects(validationReport({...project,files:{...project.files,'main.jsx':'changed'}},settings,preview),/updating/);
  await assert.rejects(validationReport({...project,fixtures:'{}'},settings,preview),/updating/);
  await assert.rejects(validationReport(project,{...settings,appearance:'dark'},preview),/updating/);
});
