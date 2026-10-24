import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {packageSourceHash} from '../../../Web/studio/src/validationReport.ts';
const root=fs.mkdtempSync(path.join(os.tmpdir(),'scriptwidget-hash-'));
try{
 const files={'main.jsx':'$render(<text>跨语言 ✓</text>);','image/色.png':new Uint8Array([0,255,42]),'widget.json':JSON.stringify({formatVersion:2,id:'com.example.hash',name:'Hash',version:'1.0.0',runtimeVersion:'1.0',entry:'main.jsx',supportedFamilies:['systemMedium'],permissions:[],networkDomains:[]})};
 for(const [name,value]of Object.entries(files)){fs.mkdirSync(path.dirname(path.join(root,name)),{recursive:true});fs.writeFileSync(path.join(root,name),value);}
 const report=JSON.parse(execFileSync(process.argv[2],['check',root,'--format','json'],{encoding:'utf8'}));
 assert.equal(report.sourceHash,await packageSourceHash(files));
 console.log('Native Swift and browser/Node source fingerprints agree, including Unicode paths and binary resources.');
}finally{fs.rmSync(root,{recursive:true,force:true});}
