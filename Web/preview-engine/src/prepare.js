import { compilePackageEntry } from "./compiler.js";
import { createPackageFileSystem } from "./packageFiles.js";

const scriptFile = /\.(jsx?|mjs)$/i;

/// Compiles the entry (wrapped in $main) and every script file (unwrapped,
/// like $import) before execution. Precompilation keeps the Babel bundle out
/// of the realm that runs user code and lets $import stay synchronous.
export function preparePackage(compiler, { files, entry = "main.jsx", prelude = "" }) {
  const packageFiles = createPackageFileSystem(files);
  const source = packageFiles.read(entry);
  if (source === null) {
    return { ok: false, error: { kind: "internalError", message: `Entry file ${entry} not found` } };
  }
  const main = compilePackageEntry(compiler, prelude + source);
  if (!main.ok) return { ok: false, error: { kind: main.kind, message: main.message } };

  const imports = {};
  for (const path of packageFiles.paths()) {
    if (!scriptFile.test(path)) continue;
    imports[path] = JSON.stringify(compilePackageEntry(compiler, packageFiles.read(path), { wrap: false }));
  }
  const textFiles = {};
  for (const path of packageFiles.paths()) textFiles[path] = packageFiles.read(path);
  return { ok: true, code: main.code, imports, files: textFiles };
}
