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

  function utf8ByteLength(text) {
    let count = 0;
    for (const character of text) { const cp = character.codePointAt(0); count += cp <= 0x7f ? 1 : cp <= 0x7ff ? 2 : cp <= 0xffff ? 3 : 4; }
    return count;
  }

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
  const timelineProjection = environments["timeline-is-projection"] === "true";
  const liveActivityPresentation = ["live-activity","dynamic-island"].includes(environments["widget-size"]);
  const fixtures = config.fixtures ?? {};
  let networkRequests = 0;

  function fetchPolicyError(url) {
    if (liveActivityPresentation) return ["[live_activity_unavailable] Live Activity presentations cannot request network data; update their state from the app", null];
    if (timelineProjection) return ["[timeline_read_only] Future entries cannot make live network requests", null];
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

  function internalFetch(method, url, params, metadata = false) {
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
      const encodedBody = bridgedParams?.responseType === "base64" ? nativeString(fixture.base64 ?? body) : body;
      if (utf8ByteLength(body) > 2097152) { reject("Response exceeds the 2097152-byte limit"); return; }
      if (metadata) {
        const headers = {};
        const allowed = ["content-type", "cache-control", "expires", "last-modified", "date", "retry-after"];
        for (const [key,value] of Object.entries(fixture.headers ?? {})) {
          const name = key.toLowerCase();
          if (allowed.includes(name) && typeof value === "string" && utf8ByteLength(value) <= 2048) headers[name] = value;
        }
        resolve({status:fixture.status ?? 200,body:encodedBody,headers});
      } else resolve(encodedBody);
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

  const storage = new Map(Object.entries(config.storage ?? fixtures.storage ?? {}));
  const validStorageKey = (key) => key !== "" && utf8ByteLength(key) <= 256;
  function storageJSON(value) {
    if (value === null || typeof value !== "object") return null;
    try {
      const dictionary = bridgeDictionary(value, 0);
      const normalize = (item) => {
        if (item === null || typeof item === "string" || typeof item === "boolean") return item;
        if (typeof item === "number") { if (!Number.isFinite(item)) throw new Error("Nonfinite JSON"); return item; }
        if (item instanceof DateCtor || isElement(item)) throw new Error("Unsupported JSON value");
        if (ArrayIsArray(item)) return item.map(normalize);
        return Object.fromEntries(ObjectKeys(item).sort().map((key) => [key, normalize(item[key])]));
      };
      const encoded = JSONStringify(normalize(dictionary));
      return utf8ByteLength(encoded) <= 256 * 1024 ? { encoded, value: dictionary } : null;
    } catch { return null; }
  }
  const device = config.device ?? fixtures.device ?? {};
  const system = config.system ?? fixtures.system ?? {};
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
      getResponse: (url, params) => internalFetch("GET", url, params, true),
      post: (url, params) => internalFetch("POST", url, params),
      put: (url, params) => internalFetch("PUT", url, params),
      patch: (url, params) => internalFetch("PATCH", url, params),
      delete: (url, params) => internalFetch("DELETE", url, params),
    },
    $file: {
      exists(path) {
        const name = nativeString(path), parts = name.split("/");
        if (/^[A-Za-z]:/.test(name) || parts.length > 16 || parts.some((part) => !part || part === "." || part === ".." || part.includes("\\") || utf8ByteLength(part) > 255 || [...part].some((character) => /[\p{Cc}\p{Cf}]/u.test(character) && character !== "\u200c" && character !== "\u200d"))) return false;
        return host.fileExists?.(name) === true;
      },
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
    $reminders: {
      isAvailable: () => false,
      authorizationStatus: () => "unavailable",
      requestAuthorization: unavailablePromise("reminders.authorization"),
      lists: unavailablePromise("reminders.lists"),
      items: unavailablePromise("reminders.items"),
    },
    $calendar: {
      isAvailable: () => false,
      authorizationStatus: () => "unavailable",
      requestAuthorization: unavailablePromise("calendar.authorization"),
      calendars: unavailablePromise("calendar.calendars"),
      events: unavailablePromise("calendar.events"),
    },
    $health: {
      authorizationStatus: () => fixtures.health !== undefined ? "notDisclosed" : "unavailable",
      isAvailable: () => fixtures.health !== undefined,
      requestAuthorization: unavailablePromise("health"),
      stepCountToday: unavailablePromise("health.stepCountToday"),
      activeEnergyToday: unavailablePromise("health.activeEnergyToday"),
      heartRateLatest: unavailablePromise("health.heartRateLatest"),
    },
    $location: {
      isAuthorizedForWidgetUpdates: () => fixtures.location !== undefined,
      isAvailable: () => fixtures.location !== undefined,
      authorizationStatus: () => (fixtures.location !== undefined ? "authorizedWhenInUse" : "notDetermined"),
      requestAuthorization: unavailablePromise("location.authorization"),
      current: unavailablePromise("location"),
    },
    $storage: {
      getString(key) { const name = nativeString(key); const value = validStorageKey(name) ? storage.get(name) : undefined; return typeof value === "string" ? value : ""; },
      setString(key, value) {
        if (timelineProjection) return false;
        const name = nativeString(key); const text = nativeString(value);
        if (!validStorageKey(name) || utf8ByteLength(text) > 256 * 1024) return false;
        storage.set(name, text); return true;
      },
      getJSON(key) {
        const name = nativeString(key); const value = validStorageKey(name) ? storage.get(name) : undefined;
        return value && typeof value === "object" && !ArrayIsArray(value) ? unbridge(value) : {};
      },
      setJSON(key, value) {
        if (timelineProjection) return false;
        const name = nativeString(key), json = storageJSON(value);
        if (!validStorageKey(name) || json === null) return false;
        storage.set(name, json.value); return true;
      },
      compareAndSetString(key, expected, value) {
        if (timelineProjection || fixtures.storageAtomicAvailable === false) return false;
        const name = nativeString(key), before = nativeString(expected), next = nativeString(value);
        if (!validStorageKey(name) || utf8ByteLength(before) > 256 * 1024 || utf8ByteLength(next) > 256 * 1024) return false;
        if ((storage.has(name) && typeof storage.get(name) !== "string") || (storage.get(name) ?? "") !== before) return false;
        storage.set(name, next); return true;
      },
      compareAndSetJSON(key, expected, value) {
        if (timelineProjection || fixtures.storageAtomicAvailable === false) return false;
        const name = nativeString(key), before = storageJSON(expected), next = storageJSON(value);
        if (!validStorageKey(name) || before === null || next === null) return false;
        if (storage.has(name)) {
          const current = storage.get(name);
          if (!current || typeof current !== "object" || ArrayIsArray(current) || storageJSON(current)?.encoded !== before.encoded) return false;
        } else if (before.encoded !== "{}") return false;
        storage.set(name, next.value); return true;
      },
      remove(key) { if (timelineProjection) return false; const name = nativeString(key); if (!validStorageKey(name)) return false; storage.delete(name); return true; },
      keys() { return [...storage.keys()].sort(); },
      clear() { if (timelineProjection) return false; storage.clear(); return true; },
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
        systemDataQueries: contract.maximumDataQueries,
      },
    },
    $dataSource: {
      request: (pluginID, operationID) => nativePromise((resolve, reject) => {
        if (liveActivityPresentation) { reject("[live_activity_unavailable] Live Activity presentations cannot request service data; update their state from the app"); return; }
        if (timelineProjection) { reject("[timeline_read_only] Future entries cannot make live service requests"); return; }
        const plugin = nativeString(pluginID), operation = nativeString(operationID);
        const fixture = (fixtures.dataSource ?? []).find((item) => item.pluginID === plugin && item.operationID === operation);
        if (!fixture) {
          diagnostic("warning", "fixture.dataSource.missing", `No Data Source mock for ${plugin} / ${operation}.`);
          reject("Data Source Plugins need a matching mock in the web preview");
          return;
        }
        // A mock must not hide missing package permissions or a disallowed host.
        if (!config.manifest?.plugins?.includes(plugin)) { reject(`Plugin ${plugin} is not declared in widget.json`); return; }
        const [policyError, host] = fetchPolicyError(nativeString(fixture.url ?? ""));
        if (policyError || !nativeString(fixture.url).startsWith("https://")) { reject(policyError ?? "Data Source mocks require HTTPS"); return; }
        if (!packageAllows(host)) { reject("Network host is not declared in widget.json"); return; }
        if (++networkRequests > 16) { reject("Network request budget exceeded"); return; }
        if (fixture.error !== undefined) { reject(nativeString(fixture.error)); return; }
        resolve(bridgeValue(fixture.value, 0));
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
  // Explicit per-method mocks override data APIs only. Rendering, package files,
  // imports, runtime contracts and network policy continue to execute normally.
  // Fresh bridged values prevent a script from modifying later mock responses.
  const apiMocks = fixtures.api ?? {};
  for (const namespace of ["$device", "$system", "$health", "$location", "$calendar", "$reminders"]) {
    for (const method of ObjectKeys(apis[namespace])) {
      const mock = apiMocks[`${namespace}.${method}`];
      if (!mock || typeof mock !== "object" || ArrayIsArray(mock)) continue;
      const hasError = Object.prototype.hasOwnProperty.call(mock, "error");
      if (!hasError && !Object.prototype.hasOwnProperty.call(mock, "value")) continue;
      const asynchronous = (["$calendar", "$reminders"].includes(namespace) && !["isAvailable", "authorizationStatus"].includes(method)) || (namespace === "$health" && !["isAvailable", "authorizationStatus"].includes(method)) ||
        (namespace === "$location" && (method === "current" || method === "requestAuthorization"));
      apis[namespace][method] = asynchronous
        ? () => nativePromise((resolve, reject) => hasError ? reject(nativeString(mock.error)) : resolve(bridgeValue(mock.value, 0)))
        : () => { if (hasError) throw new Error(nativeString(mock.error)); return unbridge(bridgeValue(mock.value, 0)); };
    }
  }
  if (timelineProjection) {
    for (const method of ["requestAuthorization", "stepCountToday", "activeEnergyToday", "heartRateLatest"]) {
      apis.$health[method] = () => nativePromise((resolve, reject) => reject("[timeline_read_only] Future entries cannot query live Health data"));
    }
  }
  // Apply policy after fixture replacement: mocks cannot grant package access.
  let dataQueries = 0;
  const locationDeclared = () => !config.manifest || config.manifest.permissions?.includes("location") === true;
  const locationStatus = apis.$location.authorizationStatus;
  const locationWidgetAuthorization = apis.$location.isAuthorizedForWidgetUpdates;
  apis.$location.authorizationStatus = () => locationDeclared() ? locationStatus() : "undeclared";
  apis.$location.isAuthorizedForWidgetUpdates = () => locationDeclared() && apis.$location.isAvailable() === true &&
    ["authorizedAlways", "authorizedWhenInUse"].includes(apis.$location.authorizationStatus()) && locationWidgetAuthorization() === true;
  for (const method of ["requestAuthorization", "current"]) {
    const implementation = apis.$location[method];
    apis.$location[method] = (options) => nativePromise((resolve, reject) => {
      if (liveActivityPresentation) { reject("[live_activity_unavailable] Live Activity presentations cannot request location updates; update their state from the app"); return; }
      if (!locationDeclared()) { reject("[permission_denied] Declare location in widget.json"); return; }
      if (++dataQueries > contract.maximumDataQueries) { reject("[query_limit] System data query limit exceeded"); return; }
      if (method === "current") {
        if (!apis.$location.isAvailable()) { reject("[unavailable] Location services are disabled on this device"); return; }
        if (!["authorizedAlways", "authorizedWhenInUse"].includes(apis.$location.authorizationStatus())) { reject("[permission_denied] Location permission denied"); return; }
        if (!apis.$location.isAuthorizedForWidgetUpdates()) { reject("[widget_not_authorized] Allow location for widgets in Settings"); return; }
      }
      implementation(options).then(resolve, reject);
    });
  }
  const rawCalendarSelection = fixtures.calendarSelection;
  const calendarSelectionValid = rawCalendarSelection == null || (ArrayIsArray(rawCalendarSelection) && rawCalendarSelection.length <= 64 && new Set(rawCalendarSelection).size === rawCalendarSelection.length && rawCalendarSelection.every((id) => typeof id === "string" && id.length > 0 && utf8ByteLength(id) <= 256));
  const selectedCalendars = rawCalendarSelection == null ? null : calendarSelectionValid ? new Set(rawCalendarSelection) : new Set();
  const calendarDeclared = () => config.manifest?.permissions?.includes("calendar") === true;
  const calendarStatus = apis.$calendar.authorizationStatus;
  apis.$calendar.authorizationStatus = () => calendarDeclared() ? calendarStatus() : "undeclared";
  for (const method of ["requestAuthorization", "calendars", "events"]) {
    const implementation = apis.$calendar[method];
    apis.$calendar[method] = (options) => nativePromise((resolve, reject) => {
      if (!calendarDeclared()) { reject("[permission_denied] Declare calendar in widget.json"); return; }
      let calendarQuery = {};
      if (method === "events") {
        try {
          const query = options == null ? {} : bridgeDictionary(options, 0);
          calendarQuery = query;
          if (ObjectKeys(query).some((key) => !["start", "end", "limit", "calendarIDs", "maxAgeSeconds"].includes(key))) throw new Error("Unknown calendar query option");
          const parseDate = (value) => {
            if (typeof value !== "string" || value.length > 64 || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(new DateCtor(value).getTime())) throw new Error("Invalid calendar date");
            return new DateCtor(value);
          };
          const start = query.start === undefined ? new DateCtor(new DateCtor().setHours(0, 0, 0, 0)) : parseDate(query.start);
          const end = query.end === undefined ? new DateCtor(new DateCtor(start).setDate(start.getDate() + 1)) : parseDate(query.end);
          if (!(end > start) || end - start > 31 * 86400000) throw new Error("Calendar range must be positive and at most 31 days");
          if (query.limit !== undefined && (!Number.isInteger(query.limit) || query.limit < 1 || query.limit > 50)) throw new Error("Invalid limit");
          if (query.maxAgeSeconds !== undefined && (typeof query.maxAgeSeconds !== "number" || !Number.isFinite(query.maxAgeSeconds) || query.maxAgeSeconds < 0 || query.maxAgeSeconds > 86400)) throw new Error("Invalid maxAgeSeconds");
          const ids = query.calendarIDs;
          if (ids !== undefined && (!ArrayIsArray(ids) || ids.length < 1 || ids.length > 16 || new Set(ids).size !== ids.length || ids.some((id) => typeof id !== "string" || !id || utf8ByteLength(id) > 256))) throw new Error("Invalid calendarIDs");
        } catch (error) { reject(`[invalid_options] ${StringCtor(error.message)}`); return; }
      }
      if (method !== "requestAuthorization" && ++dataQueries > contract.maximumDataQueries) { reject("[query_limit] Too many system data queries"); return; }
      if (method !== "requestAuthorization" && !apis.$calendar.isAvailable()) { reject("[unavailable] Calendar is unavailable"); return; }
      if (method !== "requestAuthorization" && apis.$calendar.authorizationStatus() !== "authorized") { reject("[permission_denied] Allow calendar access in ScriptWidget"); return; }
      if (method !== "requestAuthorization") {
        if (!calendarSelectionValid) { reject("[permission_denied] Calendar source settings are unavailable"); return; }
        if (method === "events" && selectedCalendars?.size === 0) { reject("[permission_denied] No Calendar sources are selected in ScriptWidget Settings"); return; }
        const available = apiMocks["$calendar.calendars"]?.value;
        if (method === "events" && selectedCalendars !== null && ArrayIsArray(available) && !available.some((item) => selectedCalendars.has(item?.id))) {
          reject("[invalid_options] A requested Calendar source is unavailable or outside your selection"); return;
        }
        if (method === "events" && calendarQuery.calendarIDs?.some((id) => (selectedCalendars !== null && !selectedCalendars.has(id)) || (ArrayIsArray(available) && !available.some((item) => item?.id === id)))) {
          reject("[invalid_options] A requested Calendar source is unavailable or outside your selection"); return;
        }
      }
      if (timelineProjection) {
        if (method === "requestAuthorization") { resolve(apis.$calendar.authorizationStatus() === "authorized"); return; }
        const snapshot = apiMocks["$calendar.events"]?.value;
        if (method === "calendars" || snapshot?.source !== "cache") { reject("[timeline_read_only] No matching Calendar snapshot is available"); return; }
      }
      implementation(options).then((value) => {
        if (method === "requestAuthorization") { resolve(value); return; }
        const available = apiMocks["$calendar.calendars"]?.value;
        const allowed = (id) => typeof id === "string" && (selectedCalendars === null || selectedCalendars.has(id)) && (!ArrayIsArray(available) || available.some((item) => item?.id === id));
        if (method === "calendars") {
          if (!ArrayIsArray(value)) { reject("[mock_invalid] Calendar sources must be an array"); return; }
          resolve(value.filter((item) => allowed(item?.id)).slice(0,64)); return;
        }
        if (!value || !ArrayIsArray(value.items)) { reject("[mock_invalid] Calendar events need an items array"); return; }
        const items = value.items.filter((item) => allowed(item?.calendarID) && (!calendarQuery.calendarIDs || calendarQuery.calendarIDs.includes(item.calendarID)));
        const limit = calendarQuery.limit ?? 10;
        resolve({ ...value, items: items.slice(0, limit), status: items.length ? "ready" : "empty", truncated: value.truncated === true || items.length > limit });
      }, reject);
    });
  }
  const rawReminderSelection = fixtures.remindersSelection;
  const reminderSelectionValid = rawReminderSelection == null || (ArrayIsArray(rawReminderSelection) && rawReminderSelection.length <= 64 && new Set(rawReminderSelection).size === rawReminderSelection.length && rawReminderSelection.every((id) => typeof id === "string" && id.length > 0 && utf8ByteLength(id) <= 256));
  const selectedLists = rawReminderSelection == null ? null : reminderSelectionValid ? new Set(rawReminderSelection) : new Set();
  const remindersDeclared = () => config.manifest?.permissions?.includes("reminders") === true;
  const remindersStatus = apis.$reminders.authorizationStatus;
  apis.$reminders.authorizationStatus = () => remindersDeclared() ? remindersStatus() : "undeclared";
  for (const method of ["requestAuthorization", "lists", "items"]) {
    const implementation = apis.$reminders[method];
    apis.$reminders[method] = (options) => nativePromise((resolve, reject) => {
      if (!remindersDeclared()) { reject("[permission_denied] Declare reminders in widget.json"); return; }
      let reminderQuery = {};
      if (method === "items") {
        try {
          const query = options == null ? {} : bridgeDictionary(options, 0);
          reminderQuery = query;
          if (ObjectKeys(query).some((key) => !["start", "end", "limit", "listIDs", "maxAgeSeconds", "completed"].includes(key))) throw new Error("Unknown reminder query option");
          const parseDate = (value) => {
            if (typeof value !== "string" || value.length > 64 || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(new DateCtor(value).getTime())) throw new Error("Invalid reminder date");
            return new DateCtor(value);
          };
          const start = query.start === undefined ? new DateCtor(new DateCtor().setHours(0, 0, 0, 0)) : parseDate(query.start);
          const end = query.end === undefined ? new DateCtor(new DateCtor(start).setDate(start.getDate() + 1)) : parseDate(query.end);
          if (!(end > start) || end - start > 31 * 86400000) throw new Error("Reminder range must be positive and at most 31 days");
          if (query.limit !== undefined && (!Number.isInteger(query.limit) || query.limit < 1 || query.limit > 50)) throw new Error("Invalid limit");
          if (query.maxAgeSeconds !== undefined && (typeof query.maxAgeSeconds !== "number" || !Number.isFinite(query.maxAgeSeconds) || query.maxAgeSeconds < 0 || query.maxAgeSeconds > 86400)) throw new Error("Invalid maxAgeSeconds");
          if (query.completed !== undefined && typeof query.completed !== "boolean") throw new Error("completed must be a Boolean");
          reminderQuery = { ...query, start: start.toISOString(), end: end.toISOString() };
          const ids = query.listIDs;
          if (ids !== undefined && (!ArrayIsArray(ids) || ids.length < 1 || ids.length > 16 || new Set(ids).size !== ids.length || ids.some((id) => typeof id !== "string" || !id || utf8ByteLength(id) > 256))) throw new Error("Invalid listIDs");
        } catch (error) { reject(`[invalid_options] ${StringCtor(error.message)}`); return; }
      }
      if (method !== "requestAuthorization" && ++dataQueries > contract.maximumDataQueries) { reject("[query_limit] Too many system data queries"); return; }
      if (method !== "requestAuthorization" && !apis.$reminders.isAvailable()) { reject("[unavailable] Reminder is unavailable"); return; }
      if (method !== "requestAuthorization" && apis.$reminders.authorizationStatus() !== "authorized") { reject("[permission_denied] Allow reminders access in ScriptWidget"); return; }
      if (method !== "requestAuthorization") {
        if (!reminderSelectionValid) { reject("[permission_denied] Reminder source settings are unavailable"); return; }
        if (method === "items" && selectedLists?.size === 0) { reject("[permission_denied] No Reminder lists are selected in ScriptWidget Settings"); return; }
        const available = apiMocks["$reminders.calendars"]?.value;
        if (method === "items" && selectedLists !== null && ArrayIsArray(available) && !available.some((item) => selectedLists.has(item?.id))) {
          reject("[invalid_options] A requested Reminder source is unavailable or outside your selection"); return;
        }
        if (method === "items" && reminderQuery.listIDs?.some((id) => (selectedLists !== null && !selectedLists.has(id)) || (ArrayIsArray(available) && !available.some((item) => item?.id === id)))) {
          reject("[invalid_options] A requested Reminder source is unavailable or outside your selection"); return;
        }
      }
      if (timelineProjection || liveActivityPresentation) {
        if (method === "requestAuthorization") { resolve(apis.$reminders.authorizationStatus() === "authorized"); return; }
        const snapshot = apiMocks["$reminders.events"]?.value;
        if (method === "lists" || snapshot?.source !== "cache") { reject("[timeline_read_only] No matching Reminder snapshot is available"); return; }
      }
      implementation(options).then((value) => {
        if (method === "requestAuthorization") { resolve(value); return; }
        const available = apiMocks["$reminders.calendars"]?.value;
        const allowed = (id) => typeof id === "string" && (selectedLists === null || selectedLists.has(id)) && (!ArrayIsArray(available) || available.some((item) => item?.id === id));
        if (method === "lists") {
          if (!ArrayIsArray(value)) { reject("[mock_invalid] Reminder sources must be an array"); return; }
          resolve(value.filter((item) => allowed(item?.id)).slice(0,64)); return;
        }
        if (!value || !ArrayIsArray(value.items)) { reject("[mock_invalid] Reminder events need an items array"); return; }
        const inWindow = (item) => {
          if (item?.completed !== (reminderQuery.completed ?? false)) return false;
          const start = new DateCtor(reminderQuery.start).getTime(), end = new DateCtor(reminderQuery.end).getTime();
          const date = item.completed ? item.completedAt : item.due;
          if (typeof date !== "string") return false;
          if (!item.completed && item.hasTime === false && /^\d{4}-\d{2}-\d{2}$/.test(date)) {
            const [year, month, day] = date.split("-").map(Number);
            const midnight = new DateCtor(year, month - 1, day);
            if (midnight.getFullYear() !== year || midnight.getMonth() !== month - 1 || midnight.getDate() !== day) return false;
            const next = new DateCtor(midnight); next.setDate(next.getDate() + 1);
            return midnight.getTime() < end && next.getTime() > start;
          }
          if (!/^\d{4}-\d{2}-\d{2}T/.test(date)) return false;
          const time = new DateCtor(date).getTime();
          return Number.isFinite(time) && time >= start && time < end;
        };
        const items = value.items.filter((item) => allowed(item?.listID) && (!reminderQuery.listIDs || reminderQuery.listIDs.includes(item.listID)) && inWindow(item));
        const limit = reminderQuery.limit ?? 10;
        resolve({ ...value, items: items.slice(0, limit), status: items.length ? "ready" : "empty", truncated: value.truncated === true || items.length > limit });
      }, reject);
    });
  }
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
