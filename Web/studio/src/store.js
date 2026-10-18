// Browser-local project drafts in IndexedDB. Each project stores package
// files (strings or Uint8Arrays) plus preview-only fixtures.
const databaseName = "scriptwidget-studio";
const storeName = "projects";

function open() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(storeName, { keyPath: "id" });
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function run(mode, action) {
  const database = await open();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = database.transaction(storeName, mode);
      const request = action(transaction.objectStore(storeName));
      transaction.oncomplete = () => resolve(request?.result);
      transaction.onerror = () => reject(transaction.error);
      transaction.onabort = () => reject(transaction.error ?? new Error("Storage transaction aborted"));
    });
  } finally {
    database.close();
  }
}

/// Falls back to memory when IndexedDB is unavailable (private browsing,
/// blocked storage); the UI warns that drafts will not persist.
const memory = new Map();
let persistent = typeof indexedDB !== "undefined";

export const storage = {
  get persistent() { return persistent; },
  async list() {
    if (!persistent) return [...memory.values()];
    try { return await run("readonly", (store) => store.getAll()); } catch { persistent = false; return [...memory.values()]; }
  },
  async save(project) {
    const value = { ...project, updatedAt: Date.now() };
    memory.set(value.id, value);
    if (persistent) {
      try { await run("readwrite", (store) => store.put(value)); } catch { persistent = false; }
    }
    return value;
  },
  async remove(id) {
    memory.delete(id);
    if (persistent) {
      try { await run("readwrite", (store) => store.delete(id)); } catch { persistent = false; }
    }
  },
};

export const preferences = {
  read(key, fallback) {
    try { const value = localStorage.getItem(`scriptwidget-studio.${key}`); return value === null ? fallback : JSON.parse(value); } catch { return fallback; }
  },
  write(key, value) {
    try { localStorage.setItem(`scriptwidget-studio.${key}`, JSON.stringify(value)); } catch { /* storage unavailable */ }
  },
};
