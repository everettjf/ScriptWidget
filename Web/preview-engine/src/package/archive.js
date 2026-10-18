// .swt (ZIP) packages: preflight mirrors ScriptPackageArchivePreflight,
// extraction mirrors ScriptManager.importScriptPackage's root detection, and
// export writes stored entries under one package directory like
// SSZipArchive(keepParentDirectory: true).

export const archivePolicy = Object.freeze({
  maximumArchiveBytes: 32 * 1024 * 1024,
  maximumExpandedBytes: 64 * 1024 * 1024,
  maximumFileBytes: 25 * 1024 * 1024,
  maximumFileCount: 500,
  maximumPathDepth: 16,
});

const u16 = (bytes, offset) => (offset >= 0 && offset + 2 <= bytes.length ? bytes[offset] | (bytes[offset + 1] << 8) : 0);
const u32 = (bytes, offset) => (offset >= 0 && offset + 4 <= bytes.length ? (bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)) >>> 0 : 0);
const u64 = (bytes, offset) => u32(bytes, offset) + u32(bytes, offset + 4) * 2 ** 32;
const utf8 = new TextDecoder("utf-8", { fatal: true });

function endOfCentralDirectory(bytes) {
  if (bytes.length < 22) return null;
  const lower = Math.max(0, bytes.length - 65557);
  for (let index = bytes.length - 22; index >= lower; index -= 1) if (u32(bytes, index) === 0x06054b50) return index;
  return null;
}

function validEntryPath(name) {
  if (name.startsWith("/") || name.startsWith("\\") || name.includes("\\") || name.includes(":") || name.includes("\0")) return false;
  const parts = name.split("/").filter((part) => part !== "");
  return parts.length > 0 && parts.length <= archivePolicy.maximumPathDepth && parts.every((part) => part !== "." && part !== "..");
}

function resolvedSizes(compressed32, uncompressed32, extra) {
  let compressed = compressed32; let uncompressed = uncompressed32;
  if (compressed32 !== 0xffffffff && uncompressed32 !== 0xffffffff) return { compressed, uncompressed };
  let cursor = 0;
  while (cursor + 4 <= extra.length) {
    const identifier = u16(extra, cursor); const length = u16(extra, cursor + 2); const end = cursor + 4 + length;
    if (end > extra.length) return null;
    if (identifier === 0x0001) {
      let value = cursor + 4;
      if (uncompressed32 === 0xffffffff) { if (value + 8 > end) return null; uncompressed = u64(extra, value); value += 8; }
      if (compressed32 === 0xffffffff) { if (value + 8 > end) return null; compressed = u64(extra, value); }
      return { compressed, uncompressed };
    }
    cursor = end;
  }
  return null;
}

/// Returns {error} or {entries: [{name, method, compressed, uncompressed, localOffset}]}.
export function preflightArchive(bytes) {
  if (bytes.length === 0 || bytes.length > archivePolicy.maximumArchiveBytes) return { error: "Archive must be between 1 byte and 32 MiB." };
  const end = endOfCentralDirectory(bytes);
  if (end === null) return { error: "Archive has no valid ZIP central directory." };
  if (u16(bytes, end + 4) !== 0 || u16(bytes, end + 6) !== 0 || u16(bytes, end + 8) !== u16(bytes, end + 10)) return { error: "Multi-disk ZIP archives are not supported." };
  if (end + 22 + u16(bytes, end + 20) !== bytes.length) return { error: "Archive has a malformed ZIP footer." };
  const count = u16(bytes, end + 10); const centralSize = u32(bytes, end + 12); const centralOffset = u32(bytes, end + 16);
  if (count <= 0 || count > archivePolicy.maximumFileCount) return { error: `Archive must contain 1–${archivePolicy.maximumFileCount} entries.` };
  if (centralOffset + centralSize > bytes.length) return { error: "Archive central directory is out of bounds." };
  let cursor = centralOffset; let expanded = 0;
  const seen = new Set(); const entries = [];
  for (let index = 0; index < count; index += 1) {
    if (cursor + 46 > bytes.length || u32(bytes, cursor) !== 0x02014b50) return { error: "Archive central directory contains an invalid entry." };
    const flags = u16(bytes, cursor + 8); const method = u16(bytes, cursor + 10);
    const nameLength = u16(bytes, cursor + 28); const extraLength = u16(bytes, cursor + 30); const commentLength = u16(bytes, cursor + 32);
    const external = u32(bytes, cursor + 38); const localOffset = u32(bytes, cursor + 42);
    const entryEnd = cursor + 46 + nameLength + extraLength + commentLength;
    if (nameLength === 0 || entryEnd > bytes.length) return { error: "Archive contains a truncated filename." };
    const sizes = resolvedSizes(u32(bytes, cursor + 20), u32(bytes, cursor + 24), bytes.subarray(cursor + 46 + nameLength, cursor + 46 + nameLength + extraLength));
    if (!sizes) return { error: "Archive contains malformed ZIP64 size metadata." };
    if (flags & 0x1) return { error: "Encrypted package entries are not supported." };
    if (method !== 0 && method !== 8) return { error: `Unsupported ZIP compression method ${method}.` };
    let name;
    try { name = utf8.decode(bytes.subarray(cursor + 46, cursor + 46 + nameLength)); } catch { return { error: "Archive contains an unsafe or non-UTF-8 path." }; }
    if (!validEntryPath(name)) return { error: "Archive contains an unsafe or non-UTF-8 path." };
    const normalized = name.normalize("NFC").toLowerCase().replace(/^\/+|\/+$/g, "");
    if (seen.has(normalized)) return { error: "Archive contains duplicate or case-colliding paths." };
    seen.add(normalized);
    if ((((external >>> 16) & 0xffff) & 0xf000) === 0xa000) return { error: "Symbolic links are not allowed in ScriptWidget packages." };
    if (!name.endsWith("/")) {
      if (sizes.uncompressed > archivePolicy.maximumFileBytes) return { error: `Package file ${name} exceeds 25 MiB.` };
      expanded += sizes.uncompressed;
      if (expanded > archivePolicy.maximumExpandedBytes) return { error: "Expanded package exceeds 64 MiB." };
      if (sizes.uncompressed > 1024 * 1024 && sizes.compressed === 0) return { error: `Archive entry ${name} has an invalid compression ratio.` };
    }
    entries.push({ name, method, compressed: sizes.compressed, uncompressed: sizes.uncompressed, localOffset });
    cursor = entryEnd;
  }
  if (cursor !== centralOffset + centralSize) return { error: "Archive entries do not match the declared central directory." };
  return { entries };
}

async function inflateRaw(data) {
  const stream = new Blob([data]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/// Extracts a preflighted archive and returns {files: {path: Uint8Array}}
/// relative to the package root, or {error}.
export async function readArchive(bytes, { inflate = inflateRaw } = {}) {
  const preflight = preflightArchive(bytes);
  if (preflight.error) return preflight;
  const files = {};
  let total = 0;
  for (const entry of preflight.entries) {
    if (entry.name.endsWith("/")) continue;
    const local = entry.localOffset;
    if (u32(bytes, local) !== 0x04034b50) return { error: `Archive entry ${entry.name} has an invalid local header.` };
    const start = local + 30 + u16(bytes, local + 26) + u16(bytes, local + 28);
    const raw = bytes.subarray(start, start + entry.compressed);
    if (raw.length !== entry.compressed) return { error: `Archive entry ${entry.name} is truncated.` };
    const data = entry.method === 0 ? raw.slice() : await inflate(raw);
    if (data.length !== entry.uncompressed) return { error: `Archive entry ${entry.name} does not match its declared size.` };
    total += data.length;
    if (total > archivePolicy.maximumExpandedBytes) return { error: "Expanded package exceeds 64 MiB." };
    const parts = entry.name.split("/").filter(Boolean);
    if (parts.some((part) => part.startsWith(".")) || parts[0] === "__MACOSX") continue;
    files[parts.join("/")] = data;
  }
  // ScriptManager.extractedPackageRoot: package files at the root, or one
  // top-level directory that contains them.
  const paths = Object.keys(files);
  if (paths.some((path) => path === "main.jsx" || path === "widget.json")) return { files, rootName: null };
  const roots = new Set(paths.map((path) => path.split("/")[0]));
  const directories = [...roots].filter((root) => paths.some((path) => path.startsWith(`${root}/`)));
  if (directories.length !== 1) return { error: "The archive must contain one widget package." };
  const root = directories[0];
  return { files: Object.fromEntries(paths.filter((path) => path.startsWith(`${root}/`)).map((path) => [path.slice(root.length + 1), files[path]])), rootName: root };
}

const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
export function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

/// A directory name that is safe on every platform the app runs on.
export function packageDirectoryName(name) {
  const cleaned = name.replace(/[\\/:*?"<>|\0]/g, "-").replace(/^\.+/, "").trim().slice(0, 80);
  return cleaned || "Widget";
}

/// Writes stored (uncompressed) entries under `rootName/`. `files` maps
/// package-relative paths to strings or Uint8Arrays.
export function writeArchive(rootName, files, { date = new Date() } = {}) {
  const encoder = new TextEncoder();
  const dosTime = ((date.getHours() & 31) << 11) | ((date.getMinutes() & 63) << 5) | ((date.getSeconds() >> 1) & 31);
  const dosDate = (((date.getFullYear() - 1980) & 127) << 9) | (((date.getMonth() + 1) & 15) << 5) | (date.getDate() & 31);
  const locals = []; const centrals = [];
  let offset = 0;
  const entries = Object.entries(files).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  if (entries.length === 0 || entries.length > archivePolicy.maximumFileCount) throw new Error("A package must contain 1–500 files.");
  for (const [path, value] of entries) {
    const name = encoder.encode(`${rootName}/${path}`);
    const data = typeof value === "string" ? encoder.encode(value) : value;
    const crc = crc32(data);
    const local = new Uint8Array(30 + name.length);
    const view = new DataView(local.buffer);
    view.setUint32(0, 0x04034b50, true); view.setUint16(4, 20, true); view.setUint16(6, 0x0800, true); view.setUint16(8, 0, true);
    view.setUint16(10, dosTime, true); view.setUint16(12, dosDate, true); view.setUint32(14, crc, true);
    view.setUint32(18, data.length, true); view.setUint32(22, data.length, true); view.setUint16(26, name.length, true); view.setUint16(28, 0, true);
    local.set(name, 30);
    const central = new Uint8Array(46 + name.length);
    const cview = new DataView(central.buffer);
    cview.setUint32(0, 0x02014b50, true); cview.setUint16(4, 0x031e, true); cview.setUint16(6, 20, true); cview.setUint16(8, 0x0800, true);
    cview.setUint16(10, 0, true); cview.setUint16(12, dosTime, true); cview.setUint16(14, dosDate, true); cview.setUint32(16, crc, true);
    cview.setUint32(20, data.length, true); cview.setUint32(24, data.length, true); cview.setUint16(28, name.length, true);
    cview.setUint32(38, (0o100644 << 16) >>> 0, true); cview.setUint32(42, offset, true);
    central.set(name, 46);
    locals.push(local, data); centrals.push(central);
    offset += local.length + data.length;
  }
  const centralSize = centrals.reduce((sum, item) => sum + item.length, 0);
  const end = new Uint8Array(22);
  const eview = new DataView(end.buffer);
  eview.setUint32(0, 0x06054b50, true); eview.setUint16(8, entries.length, true); eview.setUint16(10, entries.length, true);
  eview.setUint32(12, centralSize, true); eview.setUint32(16, offset, true);
  const output = new Uint8Array(offset + centralSize + 22);
  let cursor = 0;
  for (const part of [...locals, ...centrals, end]) { output.set(part, cursor); cursor += part.length; }
  if (output.length > archivePolicy.maximumArchiveBytes) throw new Error("Archive exceeds 32 MiB.");
  return output;
}
