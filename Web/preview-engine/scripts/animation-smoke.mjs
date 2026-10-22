import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory } from "./lib/chrome.mjs";
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),"../../..");
const server=await serveDirectory(root,{"/animation-smoke.html":{type:"text/html",body:'<!doctype html><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src &apos;self&apos;; script-src &apos;self&apos;; style-src &apos;self&apos; &apos;unsafe-inline&apos;; img-src &apos;self&apos; data: blob:; connect-src &apos;self&apos;; object-src &apos;none&apos;"><title>Public animation verification</title><body></body>'},"/favicon.ico":{type:"image/png",body:Buffer.alloc(0)}});
const chrome=await launchChrome({width:800,height:600,scale:1});
try {
 const page=await chrome.newPage();await page.goto(`${server.origin}/animation-smoke.html`);
 await page.evaluate(`(async()=>{
  const {renderWidget}=await import('/Web/preview-engine/src/render/renderer.js');
  window.pose=async(animation,options={})=>{
   const result=await renderWidget(JSON.stringify({tag:'rect',props:{color:'#ff0000',frame:'4,40',animation},children:[]}),options);
   document.body.replaceChildren(result.element);
   window.poseElement=[...result.element.querySelectorAll('*')].find(element=>element.style.getPropertyValue('--sw-start-angle')||element.style.getPropertyValue('--sw-swing'));
   window.measurePose=()=>{const element=window.poseElement;if(!element)return null;const style=getComputedStyle(element),matrix=new DOMMatrixReadOnly(style.transform);return{angle:Math.atan2(matrix.b,matrix.a)*180/Math.PI,x:matrix.e,y:matrix.f,duration:style.animationDuration,name:style.animationName,direction:style.animationDirection,origin:style.transformOrigin}};
   return{pose:window.measurePose(),text:result.element.textContent,diagnostics:result.diagnostics};
  };
 })()`);
 const fixed={now:978307215000,animations:"firstFrame"};
 let value=await page.evaluate(`window.pose('clockSecond',${JSON.stringify(fixed)})`);
 assert.ok(Math.abs(value.pose.angle-90)<0.001);assert.equal(value.pose.name,"none");
 value=await page.evaluate("window.pose('animation:{\"type\":\"clockHour\",\"timezone\":\"Asia/Kathmandu\",\"anchor\":\"topLeading\"}',{now:978307200000,animations:'firstFrame'})");
 assert.ok(Math.abs(value.pose.angle-172.5)<0.001);assert.equal(value.pose.origin,"0px 0px");
 value=await page.evaluate(`window.pose('clockCustom,-10',{now:978307205000,animations:'firstFrame'})`);
 assert.ok(Math.abs(value.pose.angle+90)<0.001);
 for(const direction of ["horizontal","vertical"]){
  const animation="animation:"+JSON.stringify({type:"swing",duration:1,distance:10,direction});
  value=await page.evaluate(`window.pose(${JSON.stringify(animation)},{animations:'firstFrame',animationElapsed:0.5})`);
  assert.ok(Math.abs(value.pose[direction==="horizontal"?"x":"y"]-10)<0.001);
 }
 value=await page.evaluate("window.pose('clockCustom,-10')");assert.equal(value.pose.direction,"reverse");assert.equal(value.pose.duration,"20s");
 // A CSS declaration does not mean its animation has started. Sample real
 // rendered frames after the browser has resolved the animation's ready state.
 const playback=await page.evaluate(`(async()=>{
  const deadline=performance.now()+5000;
  const frame=()=>new Promise((resolve,reject)=>{
   const timer=setTimeout(()=>reject(new Error('Animation frame did not arrive')),5000);
   requestAnimationFrame(()=>{clearTimeout(timer);resolve();});
  });
  const animation=window.poseElement.getAnimations().find(value=>value.animationName==='sw-clock');
  if(!animation)throw new Error('Clock CSS animation was not created');
  await Promise.race([animation.ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('Clock animation did not become ready')),5000))]);
  await frame();
  const first={angle:window.measurePose().angle,time:animation.currentTime};
  while(animation.currentTime-first.time<160){
   if(performance.now()>deadline)throw new Error('Clock animation did not advance');
   await frame();
  }
  return {first,second:{angle:window.measurePose().angle,time:animation.currentTime},state:animation.playState};
 })()`);
 const delta=((playback.second.angle-playback.first.angle+540)%360)-180;
 const elapsed=playback.second.time-playback.first.time;
 assert.equal(playback.state,'running');
 assert.ok(delta< -0.5,`negative clock moves backwards: ${delta}`);
 assert.ok(Math.abs(delta+elapsed*360/20000)<0.2,`negative clock follows actual animation time: ${JSON.stringify(playback)}`);
 value=await page.evaluate("window.pose('clockCustom,0.1')");assert.equal(value.pose.duration,"0.5s");
 value=await page.evaluate("window.pose('animation:{\"type\":\"clock\",\"interval\":1e308}',{now:978307205000})");
 assert.equal(value.pose.name,"none");assert.ok(Number.isFinite(value.pose.angle));
 value=await page.evaluate("window.pose('animation:{\"type\":\"clock\",\"interval\":1e309}')");assert.match(value.text,/animation json error/);
 value=await page.evaluate("window.pose('clockSecond',{reduceMotion:true,now:978307215000})");assert.ok(Math.abs(value.pose.angle-90)<0.001);assert.equal(value.pose.name,'none');
 value=await page.evaluate("window.pose('clockSecond',{profile:'macos',now:978307215000})");assert.ok(Math.abs(value.pose.angle-90)<0.001);assert.equal(value.pose.name,'none');
 await page.evaluate(`window.pose('clockSecond',${JSON.stringify(fixed)})`);
 if(process.env.SCRIPTWIDGET_ANIMATION_WEB)fs.writeFileSync(process.env.SCRIPTWIDGET_ANIMATION_WEB,await page.screenshot());
 assert.deepEqual(page.consoleMessages.filter(value=>value.startsWith("exception")||value.startsWith("error")),[]);
 console.log("✓ Public animation: fixed clock poses, signed half-turn intervals, actual backwards playback, swing axes, period bounds, malformed numbers, Reduce Motion and Mac static fallback passed");
} finally {await chrome.close();server.close();}
