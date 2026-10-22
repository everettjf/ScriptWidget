export const gifLimits = Object.freeze({ inputBytes: 8 * 1024 * 1024, canvasPixels: 1048576, frames: 60, decodedBytes: 4 * 1024 * 1024, edge: 512 });

// Inspect bounded GIF blocks before handing any pixels to the browser decoder.
export function inspectGif(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length > gifLimits.inputBytes || bytes.length < 14) throw new Error("GIF input limit or invalid header");
  const header = String.fromCharCode(...bytes.subarray(0, 6));
  if (header !== "GIF87a" && header !== "GIF89a") throw new Error("Invalid GIF signature");
  const word = offset => bytes[offset] | (bytes[offset + 1] << 8);
  const width = word(6), height = word(8);
  if (!width || !height || width * height > gifLimits.canvasPixels) throw new Error("GIF canvas limit");
  let offset = 13 + ((bytes[10] & 128) ? 3 * 2 ** ((bytes[10] & 7) + 1) : 0), count = 0, delay = 0.1, complete = false;
  const delays = [];
  const skipBlocks = () => {
    while (offset < bytes.length) {
      const length = bytes[offset++];
      if (!length) return;
      offset += length;
    }
    throw new Error("Truncated GIF block");
  };
  while (offset < bytes.length) {
    const block = bytes[offset++];
    if (block === 0x3b) { complete = true; break; }
    if (block === 0x21) {
      const label = bytes[offset++];
      if (label === 0xf9) {
        if (offset + 6 > bytes.length || bytes[offset] !== 4 || bytes[offset + 5] !== 0) throw new Error("Invalid GIF delay block");
        const raw = word(offset + 2) / 100;
        delay = raw < 0.011 ? 0.1 : raw;
        offset += 6;
      } else skipBlocks();
    } else if (block === 0x2c) {
      if (offset + 9 >= bytes.length) throw new Error("Truncated GIF frame");
      const frameWidth = word(offset + 4), frameHeight = word(offset + 6), flags = bytes[offset + 8];
      if (!frameWidth || !frameHeight || frameWidth * frameHeight > gifLimits.canvasPixels) throw new Error("GIF frame canvas limit");
      offset += 9 + ((flags & 128) ? 3 * 2 ** ((flags & 7) + 1) : 0);
      if (offset >= bytes.length || bytes[offset] < 2 || bytes[offset] > 8) throw new Error("Invalid GIF LZW header");
      offset++; skipBlocks(); count++;
      if (delays.length < gifLimits.frames) delays.push(delay);
      delay = 0.1;
    } else throw new Error("Invalid GIF block");
  }
  if (!complete || !count || offset > bytes.length) throw new Error("Incomplete GIF");
  return { width, height, count, delays, frameLimit: count > gifLimits.frames, estimatedDecodedBytes: width * height * count * 4 };
}

export async function readGifBytes(url, fetcher = globalThis.fetch) {
  // Studio resources are data URLs. Decode locally under connect-src 'self';
  // reject oversized encoded/decoded lengths before allocating pixel buffers.
  if (typeof url === "string" && /^data:/i.test(url)) {
    const prefix = "data:image/gif;base64,";
    if (!url.startsWith(prefix)) throw new Error("Invalid GIF data URL");
    const encodedLength = url.length - prefix.length;
    if (encodedLength > Math.ceil(gifLimits.inputBytes / 3) * 4 || encodedLength % 4 !== 0) throw new Error("GIF input limit");
    const encoded = url.slice(prefix.length);
    if (!/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) throw new Error("Invalid GIF base64");
    const padding = encoded.endsWith("==") ? 2 : encoded.endsWith("=") ? 1 : 0;
    if (encodedLength / 4 * 3 - padding > gifLimits.inputBytes) throw new Error("GIF input limit");
    return Uint8Array.from(atob(encoded), character => character.charCodeAt(0));
  }
  const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 5000);
  let reader;
  try {
    const response = await fetcher(url, { signal: controller.signal });
    if (!response.ok || Number(response.headers.get("content-length")) > gifLimits.inputBytes || !response.body?.getReader) throw new Error("GIF response limit");
    reader = response.body.getReader();
    const chunks = []; let length = 0;
    while (true) {
      const item = await reader.read(); if (item.done) break;
      length += item.value.length;
      if (length > gifLimits.inputBytes) throw new Error("GIF input limit");
      chunks.push(item.value);
    }
    const bytes = new Uint8Array(length); let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return bytes;
  } finally {
    clearTimeout(timeout);
    if (reader) { try { await reader.cancel(); } catch { /* already closed */ } }
    controller.abort();
  }
}

export async function prepareGif(url, { document: doc, firstFrame = false, legacyStill = false, needImage = false } = {}) {
  const bytes = await readGifBytes(url), info = inspectGif(bytes), blob = new Blob([bytes], { type: "image/gif" });
  const memoryFallback = !legacyStill && info.estimatedDecodedBytes > gifLimits.decodedBytes;
  const freeze = firstFrame || legacyStill || info.frameLimit || memoryFallback;
  let decoder, primary = null, still = null;
  const edge = firstFrame || info.frameLimit || memoryFallback ? gifLimits.edge : Math.min(gifLimits.edge, Math.floor(Math.sqrt(gifLimits.decodedBytes / (4 * info.count)) / 16) * 16);
  try {
    const frame = async index => {
      let bitmap;
      try {
        if (typeof globalThis.ImageDecoder === "function") {
          decoder ??= new ImageDecoder({ data: bytes, type: "image/gif" });
          await decoder.tracks.ready;
          bitmap = (await decoder.decode({ frameIndex: index })).image;
        } else bitmap = await createImageBitmap(blob);
        const width = bitmap.displayWidth ?? bitmap.width, height = bitmap.displayHeight ?? bitmap.height;
        if (!width || !height || width * height > gifLimits.canvasPixels) throw new Error("Decoded GIF canvas limit");
        const canvas = doc.createElement("canvas"), ratio = Math.min(1, edge / Math.max(width, height));
        canvas.width = Math.max(1, Math.floor(width * ratio)); canvas.height = Math.max(1, Math.floor(height * ratio));
        const context = canvas.getContext("2d"); if (!context) throw new Error("GIF canvas unavailable");
        context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL("image/png");
      } finally { bitmap?.close?.(); }
    };
    if (firstFrame || info.frameLimit || memoryFallback || needImage) still = await frame(0);
    if (freeze) {
      let index = 0;
      if (legacyStill && !firstFrame && !info.frameLimit && !memoryFallback) {
        const target = info.delays.reduce((a, b) => a + b, 0) * 0.75;
        let elapsed = 0;
        for (; index < info.delays.length - 1; index++) { elapsed += info.delays[index]; if (elapsed >= target) break; }
      }
      primary = index === 0 && still ? still : await frame(index);
    } else primary = await new Promise((resolve, reject) => {
      const reader = new FileReader(); reader.onerror = () => reject(new Error("GIF conversion failed")); reader.onload = () => resolve(reader.result); reader.readAsDataURL(blob);
    });
    return { url: primary, firstFrame: still, info, memoryFallback };
  } finally { decoder?.close(); }
}
