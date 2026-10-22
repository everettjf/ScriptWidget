#!/usr/bin/env node
// Creates/removes its own simulator. Seeds only original public fixture artwork.
import {execFileSync} from "node:child_process";
import {mkdtempSync,writeFileSync,existsSync} from "node:fs";
import {tmpdir} from "node:os";
import path from "node:path";
import {fileURLToPath} from "node:url";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"..");
const output=mkdtempSync(path.join(tmpdir(),"scriptwidget-photos-probe-"));
const derived=path.join(process.env.SCRIPTWIDGET_DERIVED_DATA??"/tmp/scriptwidget-release-readiness","ios-tests");
const app=path.join(derived,"Build/Products/Debug-iphonesimulator/ScriptWidget.app");
const cleanEnv={...process.env};for(const key of ["APPLE_ID","APPLE_SPECIFIC_PASSWORD","APPLE_TEAM_ID"])delete cleanEnv[key];
const run=(command,args,timeout=120000,env=cleanEnv)=>execFileSync(command,args,{cwd:root,env,timeout,encoding:"utf8",maxBuffer:8*1024*1024,stdio:["ignore","pipe","pipe"]});
if(!existsSync(app))throw new Error("Build the iOS simulator test host first");
let device;
try{
 const runtimes=JSON.parse(run("xcrun",["simctl","list","runtimes","-j"])).runtimes;
 const runtime=runtimes.find(r=>r.isAvailable&&r.identifier==="com.apple.CoreSimulator.SimRuntime.iOS-27-0");
 if(!runtime)throw new Error("iOS 27.0 simulator runtime is required");
 device=run("xcrun",["simctl","create",`ScriptWidget Photos Probe ${Date.now()}`,"com.apple.CoreSimulator.SimDeviceType.iPhone-17",runtime.identifier]).trim();
 if(!/^[0-9a-f-]{36}$/i.test(device))throw new Error("Invalid simulator identity");
 run("xcrun",["simctl","boot",device]);run("xcrun",["simctl","bootstatus",device,"-b"]);
 run("xcrun",["simctl","install",device,app]);
 run("xcrun",["simctl","addmedia",device,path.join(root,"Web/preview-engine/test/fixtures/photo-landscape.jpg")]);
 run("xcrun",["simctl","privacy",device,"grant","photos","com.everettjf.scriptwidget"]);
 const resultPath=path.join(output,"photos.xcresult");
 try{
  const log=run("xcodebuild",["-quiet","-project","iOS/ScriptWidget.xcodeproj","-scheme","ScriptWidgetRuntimeTests","-destination",`platform=iOS Simulator,id=${device}`,"-derivedDataPath",derived,"-resultBundlePath",resultPath,"test","-only-testing:ScriptWidgetRuntimeTests/LibrarySessionExecutionTests/testPhotoKitBridgeWithDisposableSeededSimulator"],240000,{...cleanEnv,TEST_RUNNER_SCRIPTWIDGET_PHOTOS_SIMULATOR_PROBE:"1",TEST_RUNNER_SCRIPTWIDGET_PHOTOS_PROBE_DEVICE:device});
  writeFileSync(path.join(output,"xcodebuild.log"),log);
 }catch(error){writeFileSync(path.join(output,"xcodebuild.log"),String(error.stdout??"")+String(error.stderr??""));throw new Error(`Photos probe failed; inspect ${output}`);}
 const summary=JSON.parse(run("xcrun",["xcresulttool","get","test-results","summary","--path",resultPath]));
 writeFileSync(path.join(output,"verification.json"),JSON.stringify({scope:"Actual PhotoKit -> bounded JPEG -> JavaScriptCore in a disposable simulator with one original sample; not physical device or system widget acceptance",device,resultPath,summary},null,2)+"\n");
 if(summary.result!=="Passed"||summary.passedTests!==1||summary.failedTests!==0||summary.skippedTests!==0)throw new Error(`Photos probe did not pass; inspect ${output}`);
 process.stdout.write(`✓ Actual PhotoKit bridge read the seeded JPEG\nEvidence: ${output}\n`);
}finally{
 if(device){try{run("xcrun",["simctl","shutdown",device]);}catch{}run("xcrun",["simctl","delete",device]);}
}
