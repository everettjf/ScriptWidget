// Browser-local project drafts in IndexedDB. Each project stores package
// files (strings or Uint8Arrays) plus preview-only fixtures.
import type { Project } from "./project.ts";

const databaseName = "scriptwidget-studio";
const storeName = "projects";

function open(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(databaseName, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(storeName, { keyPath: "id" });
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function run<T>(mode: IDBTransactionMode, action: (store: IDBObjectStore) => IDBRequest<T> | undefined): Promise<T | undefined> {
  const database = await open();
  try {
    return await new Promise<T | undefined>((resolve, reject) => {
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
const memory = new Map<string, Project>();
let persistent = typeof indexedDB !== "undefined";

// Preserve mutation order even when opening IndexedDB takes different amounts
// of time. A late older write must not replace a newer save or undo a removal.
let operations: Promise<unknown> = Promise.resolve();
function ordered<T>(operation: () => Promise<T>): Promise<T> {
  const result = operations.then(operation, operation);
  operations = result.then(() => undefined, () => undefined);
  return result;
}

export const storage = {
  get persistent(): boolean { return persistent; },
  async list(): Promise<Project[]> {
    return ordered(async () => {
      if (!persistent) return [...memory.values()];
      try { return (await run<Project[]>("readonly", (store) => store.getAll())) ?? []; } catch { persistent = false; return [...memory.values()]; }
    });
  },
  async save(project: Project): Promise<Project> {
    const value = { ...project, updatedAt: Date.now() };
    memory.set(value.id, value);
    await ordered(async () => {
      if (persistent) {
        try { await run("readwrite", (store) => store.put(value)); } catch { persistent = false; }
      }
    });
    return value;
  },
  async remove(id: string): Promise<void> {
    memory.delete(id);
    await ordered(async () => {
      if (persistent) {
        try { await run("readwrite", (store) => store.delete(id)); } catch { persistent = false; }
      }
    });
  },
};

export const preferences = {
  read<T>(key: string, fallback: T): T {
    try { const value = localStorage.getItem(`scriptwidget-studio.${key}`); return value === null ? fallback : (JSON.parse(value) as T); } catch { return fallback; }
  },
  write(key: string, value: unknown): void {
    try { localStorage.setItem(`scriptwidget-studio.${key}`, JSON.stringify(value)); } catch { /* storage unavailable */ }
  },
};
