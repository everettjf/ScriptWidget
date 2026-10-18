/// In-memory package file system. Paths follow
/// ScriptWidgetPackage.resolvedPackageURL: relative, standardized, and never
/// outside the package root. Content is preloaded because $import and $file
/// are synchronous in the native runtime.
export function normalizePackagePath(relativePath) {
  if (typeof relativePath !== "string" || relativePath === "" || relativePath.startsWith("/")) return null;
  if (relativePath.includes("\\") || relativePath.includes("\0")) return null;
  const parts = [];
  for (const part of relativePath.split("/")) {
    if (part === "" || part === ".") continue;
    if (part === "..") {
      if (parts.length === 0) return null;
      parts.pop();
      continue;
    }
    parts.push(part);
  }
  return parts.length === 0 ? null : parts.join("/");
}

export function createPackageFileSystem(files) {
  const entries = new Map();
  for (const [name, content] of Object.entries(files ?? {})) {
    const normalized = normalizePackagePath(name);
    if (normalized !== null && typeof content === "string") entries.set(normalized, content);
  }
  return {
    read(relativePath) {
      const normalized = normalizePackagePath(relativePath);
      return normalized === null ? null : entries.get(normalized) ?? null;
    },
    paths() { return [...entries.keys()].sort(); },
  };
}
