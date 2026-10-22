// Stateful preview operations. These execute against fixtures.storage rather
// than accepting arbitrary per-method response overrides.
export const storageAPICatalog = [
  { id: "$storage.getString", arguments: ["key"], returns: "string", documentation: "Read a package-scoped string. Missing keys return an empty string." },
  { id: "$storage.setString", arguments: ["key", "value"], returns: "boolean", documentation: "Set a package-scoped string, limited to 256 KiB of UTF-8. Check the success result." },
  { id: "$storage.getJSON", arguments: ["key"], returns: "json", documentation: "Read a package-scoped JSON object. Missing or invalid values return an empty object." },
  { id: "$storage.setJSON", arguments: ["key", "value"], returns: "boolean", documentation: "Store a valid JSON object, limited to 256 KiB encoded. Check the success result." },
  { id: "$storage.compareAndSetString", arguments: ["key", "expected", "value"], returns: "boolean", minimumRuntimeVersion: "1.3", documentation: "Atomically replace a string only when it still matches expected. A missing key matches an empty string. Conflicts return false; reread and retry a bounded number of times. Requires the shared storage container." },
  { id: "$storage.compareAndSetJSON", arguments: ["key", "expected", "value"], returns: "boolean", minimumRuntimeVersion: "1.3", documentation: "Atomically replace a JSON object if its current value equals expected, independent of property order. A missing key matches an empty object. Wrong types and conflicts return false. Requires the shared storage container." },
  { id: "$storage.remove", arguments: ["key"], returns: "boolean", documentation: "Remove a key from this package only." },
  { id: "$storage.keys", arguments: [], returns: "string[]", documentation: "List keys in this package's namespace." },
  { id: "$storage.clear", arguments: [], returns: "boolean", documentation: "Clear this package's storage. Other packages are unaffected." },
].map((method) => ({ minimumRuntimeVersion: "1.0", ...method, preview: "initialState" }));
