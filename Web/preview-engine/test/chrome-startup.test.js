import assert from "node:assert/strict";
import fs from "node:fs";
import { once } from "node:events";
import test from "node:test";
import { startChrome } from "../scripts/lib/chrome.mjs";

function silentBrowser(portFile) {
  return ["-e", `
    const fs = require('node:fs'), path = require('node:path');
    const profile = process.argv.find(value => value.startsWith('--user-data-dir=')).slice('--user-data-dir='.length);
    fs.writeFileSync(path.join(profile, 'DevToolsActivePort'), ${JSON.stringify(portFile)});
    setInterval(() => {}, 1000);
  `, "--"];
}

test("Chrome startup accepts its private profile endpoint without stderr output", async () => {
  const result = await startChrome(process.execPath, silentBrowser("45678\n/devtools/browser/test-session\n"), 2000);
  try {
    assert.equal(result.wsURL, "ws://127.0.0.1:45678/devtools/browser/test-session");
  } finally {
    const exited = once(result.chrome, "exit");
    result.chrome.kill();
    await exited;
    fs.rmSync(result.profile, { recursive: true, force: true });
  }
});

test("Chrome startup rejects malformed profile endpoint files within its deadline", async () => {
  await assert.rejects(startChrome(process.execPath, silentBrowser("0\nhttps://outside.invalid/\n"), 400), /Chrome did not start/);
});
