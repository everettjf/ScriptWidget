// Web Studio HTTP API v1 client (docs/web-studio.md): pushes a local
// package's text files to the paired iPhone/iPad and downloads the native
// SwiftUI preview PNG for the same source. The token is kept in memory only.

export class DeviceSession {
  constructor(baseURL, { fetchImpl = globalThis.fetch } = {}) {
    const url = new URL(baseURL);
    if (url.protocol !== "http:" && url.protocol !== "https:") throw new Error("Device URL must be http(s)");
    this.base = url.origin;
    this.fetch = fetchImpl;
    this.token = "";
  }

  async request(path, { method = "GET", body, binary = false } = {}) {
    const response = await this.fetch(`${this.base}${path}`, {
      method, headers: { "Content-Type": "application/json", "X-Studio-Token": this.token }, body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (!response.ok) {
      const detail = await response.json().catch(() => ({}));
      const error = new Error(detail.message || `${method} ${path} failed (${response.status})`);
      error.status = response.status; error.body = detail;
      throw error;
    }
    return binary ? new Uint8Array(await response.arrayBuffer()) : response.json();
  }

  async pair(code) {
    const result = await this.request("/api/v1/pair", { method: "POST", body: { code: String(code) } });
    this.token = result.token;
    return this.request("/api/v1/session");
  }

  /// Uploads text files, entry last so the device previews the final source.
  /// Returns {package, uploaded, skipped, snapshot (PNG bytes)}.
  async pushAndCapture({ files, manifestName, entry, packageID, timeoutMilliseconds = 20000, poll = 400 }) {
    const { packages } = await this.request("/api/v1/packages");
    const target = packageID ? packages.find((item) => item.id === packageID) : packages.find((item) => item.name === manifestName);
    if (!target) throw new Error(`No editable package named "${packageID ?? manifestName}" on the device. Import the .swt once, then sync.`);
    const before = (await this.request("/api/v1/session")).preview?.snapshotSequence ?? 0;
    const remote = new Set(target.files);
    const order = Object.keys(files).filter((path) => path !== entry).sort().concat(files[entry] !== undefined ? [entry] : []);
    const uploaded = []; const skipped = [];
    for (const path of order) {
      const content = files[path];
      if (typeof content !== "string") { skipped.push({ path, reason: "binary resources are not part of the Web Studio API" }); continue; }
      if (!remote.has(path)) await this.request("/api/v1/document", { method: "POST", body: { package: target.id, path } });
      const query = new URLSearchParams({ package: target.id, path });
      const current = await this.request(`/api/v1/document?${query}`);
      if (current.readOnly) { skipped.push({ path, reason: "read-only on the device" }); continue; }
      if (current.content === content && path !== entry) continue;
      await this.request("/api/v1/document", { method: "PUT", body: { package: target.id, path, content, baseRevision: current.revision } });
      uploaded.push(path);
    }
    const deadline = Date.now() + timeoutMilliseconds;
    while (Date.now() < deadline) {
      const session = await this.request("/api/v1/session");
      if ((session.preview?.snapshotSequence ?? 0) > before) {
        return { package: target.id, uploaded, skipped, snapshotSequence: session.preview.snapshotSequence, snapshot: await this.request("/api/v1/preview", { binary: true }) };
      }
      await new Promise((resolve) => setTimeout(resolve, poll));
    }
    throw new Error("The device did not publish a native preview in time. Keep Web Studio open in the foreground on the device.");
  }

  async disconnect() {
    try { await this.request("/api/v1/session", { method: "DELETE" }); } catch { /* already released */ }
    this.token = "";
  }
}
