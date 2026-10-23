// Actual React/IndexedDB acceptance with deterministic asynchronous barriers.
import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { launchChrome, serveDirectory, clickReady, type ChromePage } from "../../preview-engine/scripts/lib/chrome.mjs";

const dist = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dist");
const server = await serveDirectory(dist);
const url = `${server.origin}/index.html`;
const first = '$render(<text>First persisted edit</text>);';
const second = '$render(<text>Newer unsaved edit</text>);';
async function edit(page: ChromePage, source: string) {
  await page.evaluate("document.querySelector('.cm-content').focus();document.execCommand('selectAll')");
  await page.call("Input.insertText", { text: source });
  await page.waitFor(`document.querySelector('.cm-content').textContent===${JSON.stringify(source)}`);
}
const stored = `(async()=>{const open=window.__realOpen??indexedDB.open;const db=await new Promise((resolve,reject)=>{const r=open.call(indexedDB,'scriptwidget-studio',1);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});try{return await new Promise((resolve,reject)=>{const r=db.transaction('projects').objectStore('projects').getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)})}finally{db.close()}})()`;

async function lateSaveCompletion() {
  const chrome = await launchChrome({ width: 1400, height: 1000, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(url); await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
    await page.evaluate(`(()=>{
      const complete=Object.getOwnPropertyDescriptor(IDBTransaction.prototype,'oncomplete');
      window.__holdFirstCommit=true;window.__blockedOpens=[];window.__realOpen=indexedDB.open;
      Object.defineProperty(IDBTransaction.prototype,'oncomplete',{configurable:true,get:complete.get,set(handler){complete.set.call(this,event=>{
        if(window.__holdFirstCommit&&this.mode==='readwrite'){window.__holdFirstCommit=false;window.__oldSaveComplete=()=>handler.call(this,event);}
        else handler.call(this,event);
      })}});
      const success=Object.getOwnPropertyDescriptor(IDBRequest.prototype,'onsuccess');
      indexedDB.open=function(...args){const request=window.__realOpen.apply(this,args);Object.defineProperty(request,'onsuccess',{configurable:true,get:success.get,set(handler){success.set.call(this,event=>{
        if(window.__holdNewOpens)window.__blockedOpens.push(()=>handler.call(this,event));else handler.call(this,event);
      })}});return request;};
    })()`);
    await edit(page, first); await page.waitFor("typeof window.__oldSaveComplete==='function'");
    await page.evaluate("window.__holdNewOpens=true");
    await edit(page, second);
    await page.evaluate("window.__oldSaveComplete();new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))");
    const savedProjects = await page.evaluate<Array<{ files: Record<string,string> }>>(stored);
    assert.equal(savedProjects[0]?.files["main.jsx"], first, "the newer write must still be blocked by the real IndexedDB boundary");
    assert.notEqual(await page.evaluate("document.getElementById('save-state').textContent"), "Saved in this browser", "an older completion must not mark a newer unsaved draft as saved");
    await page.evaluate("window.__holdNewOpens=false;for(const resume of window.__blockedOpens.splice(0))resume()");
    await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
    await page.goto(url);
    await page.waitFor(`document.querySelector('.cm-content')?.textContent===${JSON.stringify(second)}`, 20000);
    console.log("persistence: old completion cannot mark a blocked newer draft saved; actual reload retains the new source");
  } finally { await chrome.close(); }
}

async function switchBeforeDebounce() {
  const chrome = await launchChrome({ width: 1400, height: 1000, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(url); await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
    const initial = await page.evaluate<Array<{id:string}>>(stored);
    const initialID = initial[0]!.id;
    // Hold the documented 400 ms debounce. A project switch must explicitly
    // persist the outgoing draft rather than relying on its canceled timer.
    await page.evaluate("window.__timer=setTimeout;window.setTimeout=(fn,delay,...args)=>window.__timer(delay===400?()=>{}:fn,delay===400?60000:delay,...args)");
    await edit(page, second);
    await clickReady(page, "document.getElementById('new-project')");
    await page.waitFor("document.querySelectorAll('#project-list li').length===2");
    await page.waitFor(`(async()=>{const projects=await ${stored};return projects.find(p=>p.id===${JSON.stringify(initialID)})?.files['main.jsx']===${JSON.stringify(second)}})()`);
    await page.goto(url);
    await page.waitFor("document.querySelectorAll('#project-list li').length===2");
    await clickReady(page, "[...document.querySelectorAll('#project-list li button')].find(b=>b.textContent.includes('My First Widget'))");
    await page.waitFor(`document.querySelector('.cm-content')?.textContent===${JSON.stringify(second)}`,20000);
    console.log("persistence: switching projects flushes a pending draft and reopening after reload retains it");
  } finally { await chrome.close(); }
}

async function deleteWhileSaveIsPending() {
  const chrome = await launchChrome({ width: 1400, height: 1000, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(url); await page.waitFor("!!document.querySelector('.sw-widget')",20000);
    const initial = await page.evaluate<Array<{id:string}>>(stored);
    const removedID = initial[0]!.id;
    await page.evaluate(`(()=>{
      const complete=Object.getOwnPropertyDescriptor(IDBTransaction.prototype,'oncomplete');
      window.__holdFirstCommit=true;
      Object.defineProperty(IDBTransaction.prototype,'oncomplete',{configurable:true,get:complete.get,set(handler){complete.set.call(this,event=>{
        if(window.__holdFirstCommit&&this.mode==='readwrite'){window.__holdFirstCommit=false;window.__oldSaveComplete=()=>handler.call(this,event);}
        else handler.call(this,event);
      })}});
    })()`);
    await edit(page, first);await page.waitFor("typeof window.__oldSaveComplete==='function'");
    await clickReady(page, "document.querySelector('#project-list button[aria-label=\"Delete My First Widget\"]')");
    await clickReady(page, "[...document.querySelectorAll('[role=alertdialog] button')].find(b=>b.textContent==='Delete')");
    await page.waitFor("!document.querySelector('[role=alertdialog]')");
    // The pending deletion must fence late edits, not resurrect its owner.
    await edit(page, second);
    await page.evaluate("window.__oldSaveComplete()");
    await page.waitFor("document.getElementById('project-name').value!=='My First Widget'");
    const projects = await page.evaluate<Array<{id:string}>>(stored);
    assert.ok(!projects.some(item=>item.id===removedID));
    assert.equal(projects.length,1);
    await page.goto(url);await page.waitFor("!!document.querySelector('.sw-widget')",20000);
    assert.equal(await page.evaluate("document.querySelectorAll('#project-list li').length"),1);
    console.log("persistence: queued save/delete and late input cannot resurrect the removed project");
  } finally { await chrome.close(); }
}

async function outgoingDraftBlocksSaved() {
  const chrome = await launchChrome({ width: 1400, height: 1000, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(url);await page.waitFor("!!document.querySelector('.sw-widget')",20000);
    await clickReady(page, "document.getElementById('new-project')");
    await page.waitFor("document.getElementById('project-name').value==='Widget 2'");
    await clickReady(page, "[...document.querySelectorAll('#project-list li button')].find(b=>b.textContent.includes('My First Widget'))");
    await page.waitFor("document.getElementById('project-name').value==='My First Widget'");
    await page.evaluate(`(()=>{
      window.__realOpen=indexedDB.open;window.__holdOpens=true;window.__blockedOpens=[];
      const success=Object.getOwnPropertyDescriptor(IDBRequest.prototype,'onsuccess');
      indexedDB.open=function(...args){const request=window.__realOpen.apply(this,args);Object.defineProperty(request,'onsuccess',{configurable:true,get:success.get,set(handler){success.set.call(this,event=>{
        if(window.__holdOpens)window.__blockedOpens.push(()=>handler.call(this,event));else handler.call(this,event);
      })}});return request;};
    })()`);
    await edit(page, second);
    await clickReady(page, "[...document.querySelectorAll('#project-list li button')].find(b=>b.textContent.includes('Widget 2'))");
    await page.waitFor("document.getElementById('project-name').value==='Widget 2' && window.__blockedOpens.length>0");
    assert.notEqual(await page.evaluate("document.getElementById('save-state').textContent"),'Saved in this browser','a clean open project must not hide an outgoing unsaved draft');
    await page.evaluate("window.__holdOpens=false;for(const resume of window.__blockedOpens.splice(0))resume()");
    await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
    await page.goto(url);await page.waitFor("document.querySelectorAll('#project-list li').length===2");
    await clickReady(page, "[...document.querySelectorAll('#project-list li button')].find(b=>b.textContent.includes('My First Widget'))");
    await page.waitFor(`document.querySelector('.cm-content')?.textContent===${JSON.stringify(second)}`,20000);
    console.log("persistence: a clean project cannot hide a pending outgoing draft behind Saved");
  } finally { await chrome.close(); }
}

async function abortedDeletionKeepsProjectAndAllowsRetry(active: boolean, fallback = false) {
  const chrome = await launchChrome({ width: 1400, height: 1000, scale: 1 });
  try {
    const page = await chrome.newPage();
    await page.goto(url); await page.waitFor("!!document.querySelector('.sw-widget')", 20000);
    const initial = await page.evaluate<Array<{ id: string }>>(stored);
    const originalID = initial[0]!.id;
    await clickReady(page, "document.getElementById('new-project')");
    await page.waitFor("document.querySelectorAll('#project-list li').length===2 && document.getElementById('save-state').textContent==='Saved in this browser'");
    if (active) {
      await clickReady(page, "[...document.querySelectorAll('#project-list li button')].find(b=>b.textContent.includes('My First Widget'))");
      await page.waitFor("document.getElementById('project-name').value==='My First Widget'");
    }
    if (fallback) {
      await page.evaluate("window.__put=IDBObjectStore.prototype.put;IDBObjectStore.prototype.put=function(){throw new DOMException('Injected storage quota failure','QuotaExceededError');}");
      await edit(page, second);
      await page.waitFor("document.getElementById('save-state').textContent.includes('storage is unavailable')");
      await page.evaluate("IDBObjectStore.prototype.put=window.__put");
    }
    await page.evaluate(`(()=>{
      window.__delete=IDBObjectStore.prototype.delete;window.__holdDeleteFailure=true;window.__failureCallbacks=[];
      for(const name of ['onabort','onerror']){
        const descriptor=Object.getOwnPropertyDescriptor(IDBTransaction.prototype,name);
        Object.defineProperty(IDBTransaction.prototype,name,{configurable:true,get:descriptor.get,set(handler){descriptor.set.call(this,event=>{
          if(window.__holdDeleteFailure&&this.mode==='readwrite')window.__failureCallbacks.push(()=>handler.call(this,event));
          else handler.call(this,event);
        });}});
      }
      IDBObjectStore.prototype.delete=function(key){const request=window.__delete.call(this,key);this.transaction.abort();return request;};
    })()`);
    await clickReady(page, "document.querySelector('#project-list button[aria-label=\"Delete My First Widget\"]')");
    await clickReady(page, "[...document.querySelectorAll('[role=alertdialog] button')].find(b=>b.textContent==='Delete')");
    await page.waitFor("window.__failureCallbacks.length>0");
    if (active) await edit(page, second);
    await page.evaluate("window.__holdDeleteFailure=false;for(const resume of window.__failureCallbacks.splice(0))resume()");
    await page.waitFor("document.body.textContent.includes('Project could not be deleted')");
    assert.equal(await page.evaluate("document.querySelectorAll('#project-list li').length"), 2, 'an aborted deletion must retain its project');
    const savedProjects = await page.evaluate<Array<{id:string}>>(stored);
    assert.ok(savedProjects.some(item=>item.id===originalID));
    if (active) {
      await page.waitFor("document.getElementById('save-state').textContent==='Saved in this browser'");
      await page.goto(url);
      await page.waitFor(`document.querySelector('.cm-content')?.textContent===${JSON.stringify(second)}`,20000);
      assert.equal(await page.evaluate("document.querySelectorAll('#project-list li').length"), 2);
    } else {
      assert.equal(await page.evaluate("document.getElementById('project-name').value"), 'Widget 2');
      await page.evaluate("IDBObjectStore.prototype.delete=window.__delete");
      await clickReady(page, "document.querySelector('#project-list button[aria-label=\"Delete My First Widget\"]')");
      await clickReady(page, "[...document.querySelectorAll('[role=alertdialog] button')].find(b=>b.textContent==='Delete')");
      await page.waitFor("document.querySelectorAll('#project-list li').length===1");
      const remaining = await page.evaluate<Array<{id:string}>>(stored);
      assert.ok(!remaining.some(item=>item.id===originalID));
      await page.goto(url); await page.waitFor("document.querySelectorAll('#project-list li').length===1");
    }
    console.log(`persistence: aborted ${active ? 'active' : fallback ? 'memory-fallback' : 'inactive'} deletion preserves the project, ${active ? 'pending manual edits survive reload' : 'retry commits and survives reload'}`);
  } finally { await chrome.close(); }
}

try { await lateSaveCompletion(); await switchBeforeDebounce(); await deleteWhileSaveIsPending(); await outgoingDraftBlocksSaved(); await abortedDeletionKeepsProjectAndAllowsRetry(false); await abortedDeletionKeepsProjectAndAllowsRetry(true); await abortedDeletionKeepsProjectAndAllowsRetry(false, true); }
finally { server.close(); }
console.log("✓ Project persistence asynchronous acceptance passed");
