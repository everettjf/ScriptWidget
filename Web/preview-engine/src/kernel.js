// The execution kernel runs *inside* the isolated realm that executes user
// code (a Node vm context in tests and the CLI, a sandboxed Worker in the
// browser). It must stay self-contained: its source text is evaluated in that
// realm, so it may not reference module-scope bindings.
//
// The kernel mirrors ScriptWidgetRuntime.internalExecuteJavaScriptForWidget,
// resolveWidgetElementTree, ScriptWidgetRuntimeContract.validateElementTree,
// and the JavaScriptCore <-> Foundation bridge conversions that native
// ScriptWidgetRuntimeElement properties go through. Values that leave the
// realm are strings only.
//
// host: {
//   evaluateScript(code)   classic-script evaluation in this realm (shared
//                          global lexical scope, like JSContext.evaluateScript)
//   compiledImport(path)   JSON string {ok, code} | {ok:false, kind, message},
//                          or null when the package file does not exist
//   readFile(path)         package-relative text or null
//   supportScript(name)    "util.js" / "moment.min.js" source or null
//   log(level, message)
//   parseXML(source)       JSON string matching ScriptWidgetXMLParser.parse
//   defer(callback)        run callback in a later macrotask
//   timeout(ms, callback)  run callback once the execution budget is spent
//   finish(resultJSON)     receives {tree, error, logs, diagnostics}
// }
export function scriptWidgetKernel(global, host, configJSON) {
  "use strict";
  const config = JSON.parse(configJSON);
  const contract = config.contract;
  const ObjectKeys = Object.keys;
  const ArrayIsArray = Array.isArray;
  const DateCtor = Date;
  const datePrototypeGetTime = Date.prototype.getTime;
  const StringCtor = String;
  const JSONStringify = JSON.stringify;
  const logs = [];
  const diagnostics = [];

  function diagnostic(severity, code, message) {
    if (diagnostics.length < 200) diagnostics.push({ severity, code, message: StringCtor(message) });
  }

  function describeException(error) {
    let message;
    try { message = StringCtor(error); } catch { message = "unknown error"; }
    if (error !== null && typeof error === "object") {
      const field = (name) => {
        try {
          const value = error[name];
          if (value === undefined || value === null) return null;
          const text = StringCtor(value);
          return text === "" ? null : text;
        } catch { return null; }
      };
      const line = field("line");
      if (line !== null) {
        const column = field("column");
        message += column !== null ? ` (line ${line}, column ${column})` : ` (line ${line})`;
      }
      const stack = field("stack");
      if (stack !== null) message += "\n" + stack;
    }
    return message;
  }

  // MARK: - Elements and the JavaScriptCore bridge

  const elements = new WeakSet();

  class ScriptWidgetRuntimeElement {
    constructor(tag, props, children) {
      this.tag = tag;
      this.props = props;
      this.children = children;
      elements.add(this);
    }
  }
  const isElement = (value) => value !== null && typeof value === "object" && elements.has(value);

  // JavaScriptCore converts arguments typed [AnyHashable: Any]? / [Any]? with
  // the rules measured in docs/browser-preview-engine.md: undefined object
  // members are dropped, undefined/null array members become NSNull, all
  // numbers become doubles, booleans stay booleans, Dates become NSDate,
  // functions and non-plain objects become dictionaries of their own
  // enumerable properties, and exported native objects keep their identity.
  function bridgeValue(value, depth) {
    if (depth > 64) throw new TypeError("Value nesting is too deep to cross the native bridge");
    if (value === undefined || value === null) return null;
    const type = typeof value;
    if (type === "string" || type === "number" || type === "boolean") return value;
    if (type === "bigint" || type === "symbol") return {};
    if (isElement(value)) return value;
    if (value instanceof DateCtor) return new DateCtor(datePrototypeGetTime.call(value));
    if (ArrayIsArray(value)) {
      const result = [];
      for (let index = 0; index < value.length; index += 1) result.push(bridgeValue(value[index], depth + 1));
      return result;
    }
    return bridgeDictionary(value, depth);
  }

  function bridgeDictionary(value, depth) {
    const result = {};
    for (const key of ObjectKeys(value)) {
      const member = value[key];
      if (member === undefined) continue;
      result[key] = bridgeValue(member, depth + 1);
    }
    return result;
  }

  function createElement(tag, props, children) {
    let bridgedProps = null;
    if (props !== undefined && props !== null) {
      if (typeof props !== "object" && typeof props !== "function") {
        throw new TypeError("Cannot convert primitive to NSDictionary");
      }
      bridgedProps = bridgeDictionary(props, 0);
    }
    let bridgedChildren = null;
    if (children !== undefined && children !== null) {
      bridgedChildren = ArrayIsArray(children) ? bridgeValue(children, 0) : [];
    }
    return new ScriptWidgetRuntimeElement(tag, bridgedProps, bridgedChildren);
  }

  // Foundation -> JavaScript copy used when a Swift dictionary is passed back
  // into a function component.
  function unbridge(value) {
    if (value === null || typeof value !== "object" || isElement(value)) return value;
    if (value instanceof DateCtor) return new DateCtor(datePrototypeGetTime.call(value));
    if (ArrayIsArray(value)) return value.map(unbridge);
    const result = {};
    for (const key of ObjectKeys(value)) result[key] = unbridge(value[key]);
    return result;
  }

  function childrenAsElements(children) {
    const result = [];
    const visit = (items) => {
      for (const child of items) {
        if (isElement(child)) result.push(child);
        else if (ArrayIsArray(child)) visit(child);
      }
    };
    if (children) visit(children);
    return result;
  }

  // MARK: - Execution state (one run per realm)

  let signalled = false;
  let signalWaiter = null;
  let resultElement = null;
  let rootResolutionError = null;
  let exceptionInfo = null;
  let snapshot = null;

  function signal() {
    if (signalled) return;
    signalled = true;
    // The native host waits on a counting semaphore. Capture the first
    // completion deterministically instead of racing later writes.
    snapshot = { resultElement, rootResolutionError, exceptionInfo };
    if (signalWaiter) signalWaiter();
  }

  function fail(kind, message) { return { ok: false, kind, message }; }

  function resolveWidgetElementTree(root) {
    const activePath = new Set();
    const maximumDepth = contract.maximumElementDepth;

    function singleFragmentElement(values) {
      const flattened = [];
      const append = (value) => { if (ArrayIsArray(value)) value.forEach(append); else flattened.push(value); };
      values.forEach(append);
      if (flattened.length !== 1) return null;
      return isElement(flattened[0]) ? flattened[0] : null;
    }

    function resolve(element, depth, unwrapFragment) {
      if (depth > maximumDepth) {
        return fail("resourceLimit", `Element tree exceeds the maximum depth of ${maximumDepth}`);
      }
      let current = element;
      const inserted = [];
      try {
        for (let step = 0; step < maximumDepth; step += 1) {
          if (activePath.has(current)) return fail("resourceLimit", "Element tree contains a component cycle");
          activePath.add(current);
          inserted.push(current);
          if (typeof current.tag === "string" || typeof current.tag !== "function") break;

          const argument = unbridge(current.props ?? {});
          argument.children = unbridge(current.children ?? []);
          let resolved;
          try {
            resolved = current.tag.call(undefined, argument);
          } catch (error) {
            exceptionInfo = describeException(error);
            signal();
            return fail("scriptError", "Custom component must return a ScriptWidget element");
          }
          if (!isElement(resolved)) return fail("scriptError", "Custom component must return a ScriptWidget element");
          current = resolved;
        }
        if (typeof current.tag !== "string") {
          return fail("resourceLimit", "Component resolution exceeds the maximum depth");
        }
        if (unwrapFragment && current.tag === "Fragment") {
          const child = singleFragmentElement(current.children ?? []);
          if (child) return resolve(child, depth, true);
        }

        const resolveChild = (child) => {
          if (isElement(child)) {
            const result = resolve(child, depth + 1, false);
            return result.ok ? { ok: true, value: result.element } : result;
          }
          if (ArrayIsArray(child)) {
            const values = [];
            for (const nested of child) {
              const result = resolveChild(nested);
              if (!result.ok) return result;
              values.push(result.value);
            }
            return { ok: true, value: values };
          }
          return { ok: true, value: child };
        };

        const resolvedChildren = [];
        for (const child of current.children ?? []) {
          const result = resolveChild(child);
          if (!result.ok) return result;
          resolvedChildren.push(result.value);
        }
        current.children = resolvedChildren;
        return { ok: true, element: current };
      } finally {
        for (const item of inserted) activePath.delete(item);
      }
    }

    return resolve(root, 1, true);
  }

  function validateElementTree(root) {
    let count = 0;
    const activePath = new Set();
    function visit(element, depth) {
      if (depth > contract.maximumElementDepth) {
        return fail("resourceLimit", `Element tree exceeds the maximum depth of ${contract.maximumElementDepth}`);
      }
      count += 1;
      if (count > contract.maximumElementNodes) {
        return fail("resourceLimit", `Element tree exceeds the ${contract.maximumElementNodes}-node limit`);
      }
      if (ObjectKeys(element.props ?? {}).length > contract.maximumPropsPerElement) {
        return fail("resourceLimit", `Element has more than ${contract.maximumPropsPerElement} properties`);
      }
      if (activePath.has(element)) return fail("resourceLimit", "Element tree contains a cycle");
      activePath.add(element);
      try {
        for (const child of childrenAsElements(element.children)) {
          const error = visit(child, depth + 1);
          if (error) return error;
        }
      } finally { activePath.delete(element); }
      return null;
    }
    return visit(root, 1);
  }

  // MARK: - Canonical tree JSON (shared with BrowserPreviewParityTests.swift)

  function encodeNumber(value) {
    if (value !== value) return '{"$number":"NaN"}';
    if (value === Infinity) return '{"$number":"Infinity"}';
    if (value === -Infinity) return '{"$number":"-Infinity"}';
    if (value === 0 && 1 / value < 0) return '{"$number":"-0"}';
    return StringCtor(value);
  }

  const sortKeys = (keys) => keys.sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));

  function encodeValue(value) {
    if (value === null) return "null";
    if (typeof value === "string") return JSONStringify(value);
    if (typeof value === "number") return encodeNumber(value);
    if (typeof value === "boolean") return value ? "true" : "false";
    if (isElement(value)) return encodeElement(value);
    if (value instanceof DateCtor) return `{"$date":${encodeNumber(datePrototypeGetTime.call(value))}}`;
    if (ArrayIsArray(value)) return "[" + value.map(encodeValue).join(",") + "]";
    return '{"$dict":' + encodeDictionary(value) + "}";
  }

  function encodeDictionary(value) {
    return "{" + sortKeys(ObjectKeys(value)).map((key) => JSONStringify(key) + ":" + encodeValue(value[key])).join(",") + "}";
  }

  function encodeElement(element) {
    const tag = typeof element.tag === "string" ? JSONStringify(element.tag) : '{"$function":true}';
    const props = element.props === null ? "null" : encodeDictionary(element.props);
    const children = element.children === null ? "null" : "[" + element.children.map(encodeValue).join(",") + "]";
    return `{"$element":${tag},"props":${props},"children":${children}}`;
  }

  // MARK: - Host APIs

  function nativeString(value) {
    // JSExport String parameters use JavaScript ToString.
    try { return StringCtor(value); } catch { return ""; }
  }

  // ScriptWidgetRuntimePromise exposes only then(resolve, reject), returns
  // undefined, and starts work when then() is called.
  function nativePromise(start) {
    const promise = {};
    Object.defineProperty(promise, "then", {
      enumerable: false,
      value: function then(resolve, reject) {
        const safeResolve = typeof resolve === "function" ? resolve : () => {};
        const safeReject = typeof reject === "function" ? reject : () => {};
        start((value) => host.defer(() => safeResolve(value)), (reason) => host.defer(() => safeReject(reason)));
        return undefined;
      },
    });
    return promise;
  }

  const environments = config.environments ?? {};
  const fixtures = config.fixtures ?? {};
  let networkRequests = 0;

  function fetchPolicyError(url) {
    const match = /^([A-Za-z][A-Za-z0-9+.-]*):\/\/([^/?#]*)/.exec(url);
    if (!match) return ["Only HTTP and HTTPS URLs are allowed", null];
    const scheme = match[1].toLowerCase();
    if (scheme !== "http" && scheme !== "https") return ["Only HTTP and HTTPS URLs are allowed", null];
    let host = match[2].replace(/^[^@]*@/, "").toLowerCase();
    if (host.startsWith("[")) host = host.slice(1, host.indexOf("]"));
    else host = host.replace(/:\d*$/, "");
    if (host === "") return ["URL host is required", null];
    const parts = host.split(".");
    const blocked = host === "localhost" || host === "::1" || host.endsWith(".local") ||
      host.startsWith("127.") || host.startsWith("10.") || host.startsWith("192.168.") ||
      (parts.length === 4 && parts[0] === "172" && Number(parts[1]) >= 16 && Number(parts[1]) <= 31);
    return blocked ? ["Local and private network hosts are not allowed", host] : [null, host];
  }

  function hostMatches(host, declarations) {
    return declarations.some((declaration) => {
      const domain = declaration.toLowerCase();
      if (domain.startsWith("*.")) {
        const suffix = domain.slice(2);
        return host !== suffix && host.endsWith("." + suffix);
      }
      return host === domain;
    });
  }

  function packageAllows(host) {
    if (!config.hasManifest) return true;
    const manifest = config.manifest;
    if (!manifest) return false;
    return (manifest.permissions ?? []).includes("network") && hostMatches(host, manifest.networkDomains ?? []);
  }

  function internalFetch(method, url, params) {
    const urlString = nativeString(url);
    const bridgedParams = params === undefined || params === null ? null : bridgeValue(params, 0);
    return nativePromise((resolve, reject) => {
      const [policyError, host] = fetchPolicyError(urlString);
      if (policyError) { reject(policyError); return; }
      if (!packageAllows(host)) { reject("Network host is not declared in widget.json"); return; }
      networkRequests += 1;
      if (networkRequests > 16) { reject("Network request budget exceeded"); return; }
      const fixture = (fixtures.fetch ?? []).find((item) =>
        item.url === urlString && (item.method ?? "GET").toUpperCase() === method);
      if (!fixture) {
        diagnostic("warning", "fixture.fetch.missing", `No fetch fixture for ${method} ${urlString}; the web preview does not use the network.`);
        reject(`${urlString} is empty`);
        return;
      }
      if (fixture.error) { reject(nativeString(fixture.error)); return; }
      const body = nativeString(fixture.body ?? "");
      if (bridgedParams && bridgedParams.responseType === "base64") resolve(fixture.base64 ?? body);
      else resolve(body);
    });
  }

  function unavailablePromise(api) {
    return () => nativePromise((resolve, reject) => {
      const fixture = fixtures[api];
      if (fixture !== undefined) { resolve(bridgeValue(fixture, 0)); return; }
      diagnostic("warning", `fixture.${api}.missing`, `${api} needs a fixture in the web preview.`);
      reject(`${api} is not available in the web preview`);
    });
  }

  const storage = new Map(Object.entries(config.storage ?? {}));
  const device = config.device ?? {};
  const system = config.system ?? {};
  const constant = (value) => () => unbridge(bridgeValue(value, 0));

  function readJSON(text) {
    if (text === null || text === undefined) return {};
    try {
      const value = JSON.parse(text);
      return value !== null && typeof value === "object" && !ArrayIsArray(value) ? value : null;
    } catch { return {}; }
  }

  const apis = {
    fetch: (url, params) => internalFetch("GET", url, params),
    $console: {
      log(message) { logs.push({ level: "log", message: nativeString(message) }); host.log("log", nativeString(message)); },
      error(message) { logs.push({ level: "error", message: nativeString(message) }); host.log("error", nativeString(message)); },
    },
    $element: { createElement },
    $device: {
      screen: constant(device.screen ?? { width: 390, height: 844, scale: 3 }),
      language: constant(device.language ?? "en"),
      model: constant(device.model ?? "iPhone"),
      name: constant(device.name ?? "iPhone"),
      battery: constant(device.battery ?? { level: 0.8, state: "unplugged" }),
      systemVersion: constant(device.systemVersion ?? "26.0"),
      isdarkmode: () => config.preview?.appearance === "dark",
      totalDiskSpace: constant(device.totalDiskSpace ?? 128000000000),
      freeDiskSpace: constant(device.freeDiskSpace ?? 64000000000),
    },
    $http: {
      get: (url, params) => internalFetch("GET", url, params),
      post: (url, params) => internalFetch("POST", url, params),
      put: (url, params) => internalFetch("PUT", url, params),
      patch: (url, params) => internalFetch("PATCH", url, params),
      delete: (url, params) => internalFetch("DELETE", url, params),
    },
    $file: {
      read(path) { const text = host.readFile(nativeString(path)); return text ?? ""; },
      readJSON(path) { return readJSON(host.readFile(nativeString(path))); },
    },
    $system: {
      appInfo: constant(system.appInfo ?? { name: "ScriptWidget", bundleId: "com.everettjf.scriptwidget", version: "", build: "" }),
      locale: constant(system.locale ?? "en_US"),
      preferredLanguages: constant(system.preferredLanguages ?? ["en-US"]),
      timeZone: constant(system.timeZone ?? { identifier: "UTC", abbreviation: "GMT", offsetSeconds: 0 }),
      is24HourClock: constant(system.is24HourClock ?? false),
      calendarInfo: constant(system.calendarInfo ?? { identifier: "gregorian", firstWeekday: 1, minimumDaysInFirstWeek: 1 }),
      systemUptime: constant(system.systemUptime ?? 3600),
      memory: constant(system.memory ?? { physical: 8589934592 }),
      thermalState: constant(system.thermalState ?? "nominal"),
      lowPowerMode: constant(system.lowPowerMode ?? false),
      brightness: constant(system.brightness ?? 0.5),
      reduceMotionEnabled: constant(system.reduceMotionEnabled ?? false),
      platform: constant(system.platform ?? "ios"),
      hostName: constant(system.hostName ?? "iPhone"),
      processName: constant(system.processName ?? "ScriptWidgetWidget"),
      osVersionString: constant(system.osVersionString ?? "Version 26.0"),
      processorCount: constant(system.processorCount ?? 6),
      activeProcessorCount: constant(system.activeProcessorCount ?? 6),
    },
    $health: {
      isAvailable: () => fixtures.health !== undefined,
      requestAuthorization: unavailablePromise("health"),
      stepCountToday: unavailablePromise("health.stepCountToday"),
      activeEnergyToday: unavailablePromise("health.activeEnergyToday"),
      heartRateLatest: unavailablePromise("health.heartRateLatest"),
    },
    $location: {
      isAvailable: () => fixtures.location !== undefined,
      authorizationStatus: () => (fixtures.location !== undefined ? "authorizedWhenInUse" : "notDetermined"),
      requestAuthorization: unavailablePromise("location.authorization"),
      current: unavailablePromise("location"),
    },
    $storage: {
      getString(key) { const value = storage.get(nativeString(key)); return typeof value === "string" ? value : ""; },
      setString(key, value) {
        const name = nativeString(key); const text = nativeString(value);
        if (name === "" || name.length > 256 || text.length > 256 * 1024) return false;
        storage.set(name, text); return true;
      },
      getJSON(key) { const value = storage.get(nativeString(key)); return value && typeof value === "object" ? unbridge(value) : {}; },
      setJSON(key, value) {
        const name = nativeString(key);
        if (name === "" || value === null || typeof value !== "object") return false;
        storage.set(name, bridgeDictionary(value, 0)); return true;
      },
      remove(key) { storage.delete(nativeString(key)); return true; },
      keys() { return [...storage.keys()].sort(); },
      clear() { storage.clear(); return true; },
    },
    $runtime: {
      apiVersion: contract.apiVersion,
      limits: {
        sourceBytes: contract.maximumSourceBytes,
        transpiledBytes: contract.maximumTranspiledBytes,
        executionMilliseconds: contract.executionTimeoutMilliseconds,
        elementNodes: contract.maximumElementNodes,
        elementDepth: contract.maximumElementDepth,
        propsPerElement: contract.maximumPropsPerElement,
      },
    },
    $dataSource: {
      request: (pluginID) => nativePromise((resolve, reject) => {
        diagnostic("warning", "fixture.dataSource.missing", `Data Source Plugin ${nativeString(pluginID)} is not available in the web preview.`);
        reject("Data Source Plugins are not available in the web preview");
      }),
    },
    $xml_parse: (source) => host.parseXML(nativeString(source)),
    $getenv: (key) => {
      const value = environments[nativeString(key)];
      return typeof value === "string" ? value : "";
    },
    $render(root) {
      if (isElement(root)) {
        const result = resolveWidgetElementTree(root);
        if (result.ok) resultElement = result.element;
        else rootResolutionError = { kind: result.kind, message: result.message };
      }
      signal();
    },
    $dynamic_island() { signal(); },
    $component() {},
    $error(message) { exceptionInfo = nativeString(message); signal(); },
    $import(relativePath) {
      const path = nativeString(relativePath);
      const compiled = host.compiledImport(path);
      if (compiled === null || compiled === undefined) {
        diagnostic("error", "import.missing", `$import("${path}") did not find a package file; the native runtime returns false silently.`);
        return false;
      }
      const transformed = JSON.parse(compiled);
      if (!transformed.ok) {
        diagnostic("error", "import.transform", `$import("${path}") failed to compile: ${transformed.message}`);
        return false;
      }
      try {
        host.evaluateScript(transformed.code);
      } catch (error) {
        exceptionInfo = describeException(error);
        signal();
      }
      return true;
    },
  };
  apis.$fetch = apis.fetch;
  apis.console = apis.$console;
  apis.Promise = global.Promise;

  for (const name of ObjectKeys(apis)) {
    Object.defineProperty(global, name, { value: apis[name], writable: true, configurable: true, enumerable: false });
  }

  function evaluate(code) {
    try {
      host.evaluateScript(code);
      return true;
    } catch (error) {
      exceptionInfo = describeException(error);
      signal();
      return false;
    }
  }

  function finish(state, extra) {
    let error = null;
    let tree = null;
    if (extra.error) error = extra.error;
    else if (state.exceptionInfo !== null) error = { kind: "scriptException", message: state.exceptionInfo };
    else if (state.rootResolutionError) error = state.rootResolutionError;
    else if (!state.resultElement) error = { kind: "scriptError", message: "Transform result is not Element : nil" };
    else {
      const validation = validateElementTree(state.resultElement);
      if (validation) error = { kind: validation.kind, message: validation.message };
      else tree = encodeElement(state.resultElement);
    }
    return JSONStringify({ tree, error, logs, diagnostics });
  }

  return {
    run(javaScript, timeoutMilliseconds) {
      let done = false;
      const complete = (extra) => {
        if (done) return;
        done = true;
        host.finish(finish(snapshot ?? { resultElement, rootResolutionError, exceptionInfo }, extra));
      };

      const supportJS = host.supportScript("util.js");
      if (supportJS === null) { complete({ error: { kind: "internalError", message: "scriptwidget not found" } }); return; }
      evaluate(supportJS);

      if (javaScript.includes("moment(") || javaScript.includes("moment.")) {
        const momentJS = host.supportScript("moment.min.js");
        if (momentJS !== null) evaluate(momentJS);
      }
      evaluate(javaScript);

      const main = global.$main;
      if (main === undefined) { complete({ error: { kind: "undefinedRender", message: "$main() is not defined" } }); return; }
      if (/\bPromise\s*(\.|\()/.test(javaScript) || /new\s+Promise\b/.test(javaScript)) {
        diagnostic("warning", "compat.promise", "The native runtime replaces the global Promise with a then-only shim; new Promise, Promise.all, .catch, and .finally may fail on iPhone.");
      }

      signalWaiter = () => host.defer(() => complete({}));
      try {
        main.call(undefined);
      } catch (error) {
        exceptionInfo = describeException(error);
        signal();
      }
      if (!javaScript.includes("$render")) {
        resultElement = new ScriptWidgetRuntimeElement("text", null, ["#UI Not Found#"]);
        signal();
      }
      if (signalled) { signalWaiter(); return; }
      host.timeout(timeoutMilliseconds, () => complete({
        error: { kind: "resourceLimit", message: "Script exceeded the 5-second execution limit" },
      }));
    },
  };
}
