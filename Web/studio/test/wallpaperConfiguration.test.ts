import assert from "node:assert/strict";
import test from "node:test";
import { defaultWallpaperConfiguration, isWallpaperTemplate, readWallpaperConfiguration, serializeWallpaperConfiguration } from "../src/wallpaperConfiguration.ts";
import { createProject } from "../src/project.ts";
import { exportPackage, importPackage } from "../../preview-engine/src/package/index.js";

const asset = { family: "medium", appearance: "light", image: "background-00000000-0000-4000-8000-000000000001", label: "Top left" } as const;
test("wallpaper settings are portable package data, independent of preview fixtures", async () => {
  const values = { ...defaultWallpaperConfiguration(), title: "Quiet space", backgrounds: [asset] };
  const project = createProject("Portable wallpaper");
  project.files["wallpaper.json"] = serializeWallpaperConfiguration(values);
  project.files[`image/${asset.image}.png`] = new Uint8Array([1, 2, 3]);
  project.fixtures = '{"storage":{"recordTemplate.config.v1":"preview only"}}';
  const exported = exportPackage(project.files);
  assert.equal(exported.error, undefined);
  if (exported.error !== undefined) return;
  const imported = await importPackage(exported.bytes);
  assert.equal(imported.error, undefined);
  if (imported.error !== undefined) return;
  assert.deepEqual(readWallpaperConfiguration(imported.files), values);
  assert.deepEqual(imported.files[`image/${asset.image}.png`], new Uint8Array([1, 2, 3]));
  assert.ok(!JSON.stringify(imported.files).includes("preview only"));
});

test("missing configuration uses defaults; present malformed data never does", () => {
  assert.deepEqual(readWallpaperConfiguration({}), defaultWallpaperConfiguration());
  for (const raw of ["", "{", "{}", "null", JSON.stringify({ version: true, kind: "wallpaper", values: defaultWallpaperConfiguration() }), " ".repeat(4097), new Uint8Array([0xff])]) {
    assert.throws(() => readWallpaperConfiguration({ "wallpaper.json": raw }));
  }
  const values = { ...defaultWallpaperConfiguration(), backgrounds: [asset] };
  for (const invalid of [{ ...values, extra: true }, { ...values, backgrounds: [asset, asset] }, { ...values, backgrounds: [{ ...asset, image: "../escape" }] }, { ...values, backgrounds: [{ ...asset, label: "hidden\u202e" }] }, { ...values, title: "x".repeat(41) }]) {
    assert.throws(() => serializeWallpaperConfiguration(invalid));
  }
  assert.deepEqual(readWallpaperConfiguration({ "wallpaper.json": new TextEncoder().encode(serializeWallpaperConfiguration(values)) }), values);
});

test("wallpaper tooling requires the exact supported record descriptor", () => {
  assert.equal(isWallpaperTemplate({ "record-template.json": '{"formatVersion":1,"kind":"wallpaper"}' }), true);
  for (const descriptor of [{ formatVersion: true, kind: "wallpaper" }, { formatVersion: 2, kind: "wallpaper" }, { formatVersion: 1, kind: "photoCard" }, { formatVersion: 1, kind: "wallpaper", extra: true }]) {
    assert.equal(isWallpaperTemplate({ "record-template.json": JSON.stringify(descriptor) }), false);
  }
});
