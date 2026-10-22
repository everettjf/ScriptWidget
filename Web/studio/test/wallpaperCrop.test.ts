import test from "node:test";
import assert from "node:assert/strict";
import { fitWallpaperSize, initialWallpaperCrop, inspectWallpaperImage, validateWallpaperCrop, validateWallpaperSize } from "../src/wallpaperCrop.ts";

function png(width: number, height: number): Uint8Array {
  const bytes = new Uint8Array(33);
  const view = new DataView(bytes.buffer);
  [0x89504e47, 0x0d0a1a0a, 13, 0x49484452, width, height].forEach((value, index) => view.setUint32(index * 4, value));
  return bytes;
}

test("wallpaper allocation preflight rejects oversized, missing and malformed dimensions", () => {
  assert.deepEqual(inspectWallpaperImage(png(1179, 2556)), { width: 1179, height: 2556 });
  for (const bytes of [png(0, 1), png(20_001, 1), png(10_001, 10_000), png(1, 1).slice(0, 24), new Uint8Array(), new Uint8Array(25 * 1024 * 1024 + 1)]) {
    assert.throws(() => inspectWallpaperImage(bytes));
  }
  assert.doesNotThrow(() => validateWallpaperSize({ width: 20_000, height: 5000 }));
  for (const width of [NaN, Infinity, -1, 0, 1.5]) assert.throws(() => validateWallpaperSize({ width, height: 1 }));
});

test("JPEG header walking handles metadata, fill bytes and progressive frames within a view slice", () => {
  const jpeg = Uint8Array.from([0xff, 0xd8, 0xff, 0xe1, 0, 4, 0, 0, 0xff, 0xff, 0xc2, 0, 8, 8, 0x09, 0xfc, 0x04, 0x9b, 1]);
  const padded = new Uint8Array(jpeg.length + 10);
  padded.set(jpeg, 5);
  assert.deepEqual(inspectWallpaperImage(padded.subarray(5, 5 + jpeg.length)), { width: 1179, height: 2556 });
  for (let end = 0; end < jpeg.length; end++) assert.throws(() => inspectWallpaperImage(jpeg.slice(0, end)));
  const invalid = jpeg.slice(); invalid[5] = 1;
  assert.throws(() => inspectWallpaperImage(invalid));
});

test("native-sized presets remain valid for portrait, landscape and single-pixel images", () => {
  for (const image of [{ width: 1179, height: 2556 }, { width: 3072, height: 1700 }, { width: 1, height: 1 }]) {
    for (const family of ["small", "medium", "large", "extraLarge", "extraLargePortrait"] as const) {
      const crop = initialWallpaperCrop(family, image);
      assert.doesNotThrow(() => validateWallpaperCrop(crop, image));
      const output = fitWallpaperSize(crop, 1024);
      assert.ok(Math.max(output.width, output.height) <= 1024);
    }
  }
  assert.deepEqual(initialWallpaperCrop("small", { width: 1179, height: 2556 }), { x: 342, y: 1030, width: 495, height: 495 });
  assert.deepEqual(fitWallpaperSize({ width: 6000, height: 4000 }, 3072), { width: 3072, height: 2048 });
  assert.deepEqual(fitWallpaperSize({ width: 10, height: 20 }, 1024), { width: 10, height: 20 });
});

test("crop validation rejects fractional, overflowing and out-of-image selections", () => {
  const image = { width: 100, height: 200 };
  for (const crop of [
    { x: -1, y: 0, width: 10, height: 10 }, { x: 0.5, y: 0, width: 10, height: 10 },
    { x: 91, y: 0, width: 10, height: 10 }, { x: 0, y: 191, width: 10, height: 10 },
    { x: 0, y: 0, width: 101, height: 10 }, { x: 0, y: 0, width: Infinity, height: 10 },
    { x: Number.MAX_SAFE_INTEGER, y: 0, width: 10, height: 10 },
  ]) assert.throws(() => validateWallpaperCrop(crop, image));
  assert.doesNotThrow(() => validateWallpaperCrop({ x: 90, y: 190, width: 10, height: 10 }, image));
  assert.throws(() => fitWallpaperSize(image, 3073));
});
