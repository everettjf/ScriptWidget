import { inferredLibraries, makeError, runtimeContract, validateByteCount, wrappedSource } from "./contract.js";

/// Wraps a host-specific Babel entry point. `transform(source)` must run the
/// bundled support.bundle/core.js with presets: ['scriptwidget'].
export function createCompiler(transform) {
  const cache = new Map();
  return {
    fingerprint: runtimeContract.compilerFingerprint,
    transform(source) {
      if (cache.has(source)) return cache.get(source);
      const result = transform(source);
      if (cache.size > 64) cache.delete(cache.keys().next().value);
      cache.set(source, result);
      return result;
    },
  };
}

function describe(error) {
  let message;
  try { message = String(error); } catch { message = "unknown error"; }
  return message;
}

/// Mirrors ScriptWidgetRuntime.transform plus ScriptWidgetCompiler.compile.
/// A Babel exception is reported as scriptException because the native
/// compiler receives "undefined" output and then reports the exception.
export function compilePackageEntry(compiler, source, { wrap = true } = {}) {
  const sourceError = validateByteCount(source, runtimeContract.maximumSourceBytes, "Source");
  if (sourceError) return { ok: false, kind: sourceError.kind, message: sourceError.message };
  const input = wrap ? wrappedSource(source) : source;
  let code;
  try {
    code = compiler.transform(input);
  } catch (error) {
    return { ok: false, kind: "scriptException", message: describe(error) };
  }
  if (typeof code !== "string") {
    return { ok: false, kind: "transformError", message: "Transform result is nil" };
  }
  const transpiledError = validateByteCount(code, runtimeContract.maximumTranspiledBytes, "Transpiled script");
  if (transpiledError) return { ok: false, kind: transpiledError.kind, message: transpiledError.message };
  return { ok: true, code, libraries: inferredLibraries(code) };
}

export { makeError };
