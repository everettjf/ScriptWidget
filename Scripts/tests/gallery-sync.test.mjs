import test from "node:test";
import assert from "node:assert/strict";
import { cp, mkdtemp, mkdir, readFile, writeFile, rm, symlink, link } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const exec = promisify(execFile);
const repository = fileURLToPath(new URL("../../", import.meta.url));

test("baseline templates retain the optional minimum API requirement without undefined Gallery metadata", async () => {
  const root = join(repository,"Shared/ScriptWidgetRuntime/Resource/Script.bundle/template/Layout Starter");
  const manifest = JSON.parse(await readFile(join(root,"widget.json"),"utf8"));
  assert.equal(manifest.minimumRuntimeVersion,undefined);
  assert.equal(manifest.runtimeVersion,"1.0");
  const index = JSON.parse(await readFile(join(repository,"Gallery/index.json"),"utf8"));
  const item = index.items.find(item=>item.id===manifest.id);
  assert.ok(item); assert.equal(item.minimumRuntimeVersion,"1.0");
  assert.match(item.summary,/^Requires Runtime API 1\.0\./);
  assert.ok(!item.summary.includes("undefined"));
});

test("curated Gallery synchronization detects drift and refuses unsafe or stale destinations", async () => {
  const root = await mkdtemp(join(tmpdir(), "scriptwidget-gallery-sync-"));
  try {
    await mkdir(join(root, "Scripts"));
    await cp(join(repository, "Scripts/sync-gallery-templates.mjs"), join(root, "Scripts/sync-gallery-templates.mjs"));
    await cp(join(repository, "Gallery"), join(root, "Gallery"), { recursive: true });
    const index = JSON.parse(await readFile(join(repository, "Gallery/index.json"), "utf8"));
    for (const item of index.items.filter((item) => item.id.startsWith("app.scriptwidget.template."))) {
      const relative = join("Shared/ScriptWidgetRuntime/Resource/Script.bundle/template", item.name);
      await cp(join(repository, relative), join(root, relative), { recursive: true });
    }
    const run = (...args) => exec(process.execPath, [join(root, "Scripts/sync-gallery-templates.mjs"), ...args]);
    await run();
    const path = join(root, "Gallery/widgets/countdown/main.jsx");
    const original = await readFile(path);
    await writeFile(path, Buffer.alloc(original.length, 32));
    await assert.rejects(run(), /differs from the reviewed native template/);
    await run("--write");
    assert.deepEqual(await readFile(path), original);
    await rm(path);
    await assert.rejects(run(), /differs from the reviewed native template/);
    await run("--write");

    const stale = join(root, "Gallery/widgets/countdown/obsolete.js");
    await writeFile(stale, "unindexed code");
    await assert.rejects(run("--write"), /unindexed stale file/);
    await rm(stale);

    const outside = join(root, "untouched.jsx");
    await writeFile(outside, "must remain unchanged");
    await rm(path);
    await symlink(outside, path);
    await assert.rejects(run("--write"), /cannot contain links/);
    assert.equal(await readFile(outside, "utf8"), "must remain unchanged");
    await rm(path);
    await link(outside, path);
    await assert.rejects(run("--write"), /cannot contain hard links/);
    assert.equal(await readFile(outside, "utf8"), "must remain unchanged");
    await rm(path);
    await run("--write");
    await run();
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
