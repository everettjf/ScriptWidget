// Preview data only. Kept with the browser draft, never in exported packages.
export type MockValue = null | boolean | number | string | MockValue[] | { [key: string]: MockValue };
export type MockObject = { [key: string]: MockValue };
export interface MockAPI { id: string; group: string; value: MockValue; legacy?: string[] }
const sampleStart = "2026-01-01T00:00:00Z";
const sampleEnd = "2026-01-01T12:00:00Z";
const measure = (value: number, unit: string) => ({ value, unit, start: sampleStart, end: sampleEnd });
const group = (name: string, values: Record<string, MockValue>, legacy: string) => Object.entries(values).map(([method, value]) => ({ id: `$${name}.${method}`, group: name, value, legacy: [legacy, method] }));
export const mockAPIs: MockAPI[] = [
  ...group("device", {
    screen: { width: 390, height: 844, scale: 3 }, language: "en", model: "iPhone", name: "My iPhone",
    battery: { level: 0.8, state: "unplugged" }, systemVersion: "26.0", isdarkmode: false,
    totalDiskSpace: 128000000000, freeDiskSpace: 64000000000,
  }, "device"),
  ...group("system", {
    appInfo: { name: "ScriptWidget", bundleId: "com.everettjf.scriptwidget", version: "27.1.2", build: "27012" },
    locale: "en_US", preferredLanguages: ["en-US"], timeZone: { identifier: "UTC", abbreviation: "GMT", offsetSeconds: 0 },
    is24HourClock: false, calendarInfo: { identifier: "gregorian", firstWeekday: 1, minimumDaysInFirstWeek: 1 },
    systemUptime: 3600, memory: { physical: 8589934592 }, thermalState: "nominal", lowPowerMode: false,
    brightness: 0.5, reduceMotionEnabled: false, platform: "ios", hostName: "My iPhone", processName: "ScriptWidgetWidget",
    osVersionString: "Version 26.0", processorCount: 6, activeProcessorCount: 6,
  }, "system"),
  { id: "$health.isAvailable", group: "health", value: true },
  { id: "$health.requestAuthorization", group: "health", value: true, legacy: ["health"] },
  { id: "$health.stepCountToday", group: "health", value: measure(6840, "count"), legacy: ["health.stepCountToday"] },
  { id: "$health.activeEnergyToday", group: "health", value: measure(420, "kcal"), legacy: ["health.activeEnergyToday"] },
  { id: "$health.heartRateLatest", group: "health", value: measure(72, "bpm"), legacy: ["health.heartRateLatest"] },
  { id: "$location.isAvailable", group: "location", value: true },
  { id: "$location.authorizationStatus", group: "location", value: "authorizedWhenInUse" },
  { id: "$location.requestAuthorization", group: "location", value: true, legacy: ["location.authorization"] },
  { id: "$location.current", group: "location", value: { latitude: 37.3349, longitude: -122.009, altitude: 0, horizontalAccuracy: 10, verticalAccuracy: 10, timestamp: sampleEnd }, legacy: ["location"] },
];
// Dark appearance follows the preview setting until a user explicitly mocks it.
export function sampleFixtures(): MockObject {
  return {
    api: Object.fromEntries(mockAPIs.filter((api) => api.id !== "$device.isdarkmode").map((api) => [api.id, { value: api.value }])),
    fetch: [{ url: "https://api.example.com/data", method: "GET", body: '{"value":42}' }],
    storage: {}, dataSource: [],
  };
}
export const defaultFixtures = JSON.stringify(sampleFixtures(), null, 2);
export const isObject = (value: unknown): value is MockObject => value !== null && typeof value === "object" && !Array.isArray(value);
export function parseMocks(text: string): MockObject {
  const value: unknown = JSON.parse(text || "{}");
  if (!isObject(value)) throw new Error("Mock data must be a JSON object.");
  for (const key of ["api", "device", "system", "storage"]) {
    if (value[key] !== undefined && !isObject(value[key])) throw new Error(`${key} must be a JSON object.`);
  }
  if (isObject(value.api)) for (const [name, response] of Object.entries(value.api)) {
    if (!isObject(response) || (("value" in response) === ("error" in response))) throw new Error(`${name} needs either value or error.`);
    if ("error" in response && typeof response.error !== "string") throw new Error(`${name} error must be text.`);
  }
  for (const key of ["fetch", "dataSource"]) {
    if (value[key] !== undefined && !Array.isArray(value[key])) throw new Error(`${key} must be an array.`);
    if (Array.isArray(value[key])) for (const item of value[key]) {
      if (!isObject(item) || typeof item.url !== "string") throw new Error(`${key} rules need a URL.`);
      if (item.error !== undefined && typeof item.error !== "string") throw new Error(`${key} errors must be text.`);
      if (key === "fetch" && item.method !== undefined && (typeof item.method !== "string" || !["GET", "POST", "PUT", "PATCH", "DELETE"].includes(item.method.toUpperCase()))) throw new Error("Network methods must be GET, POST, PUT, PATCH or DELETE.");
      if (key === "fetch" && item.body !== undefined && typeof item.body !== "string") throw new Error("Network body must be response text.");
      if (key === "dataSource" && (("value" in item) === ("error" in item))) throw new Error("Data Source rules need either value or error.");
      if (key === "dataSource" && (typeof item.pluginID !== "string" || typeof item.operationID !== "string")) throw new Error("Data Source rules need pluginID and operationID.");
    }
  }
  return value;
}
export function responseFor(data: MockObject, api: MockAPI): MockObject {
  const override = isObject(data.api) ? data.api[api.id] : undefined;
  if (isObject(override)) return override;
  let legacy: MockValue | undefined = data;
  for (const key of api.legacy ?? []) legacy = isObject(legacy) ? legacy[key] : undefined;
  return { value: api.legacy && legacy !== undefined ? legacy : api.value };
}
export function setResponse(text: string, id: string, response: MockObject): string {
  const data = parseMocks(text);
  data.api = { ...(isObject(data.api) ? data.api : {}), [id]: response };
  return JSON.stringify(data, null, 2);
}
export function addSampleMocks(text: string): string {
  const data = parseMocks(text);
  const api = { ...(isObject(data.api) ? data.api : {}) };
  for (const item of mockAPIs) {
    if (item.id !== "$device.isdarkmode" && api[item.id] === undefined) api[item.id] = responseFor(data, item);
  }
  data.api = api;
  data.fetch ??= sampleFixtures().fetch!;
  data.storage ??= {};
  data.dataSource ??= [];
  return JSON.stringify(data, null, 2);
}
export function permissionScenario(text: string, group: "health" | "location", mode: "granted" | "denied" | "unavailable"): string {
  let result = text;
  for (const api of mockAPIs.filter((item) => item.group === group)) {
    const response: MockObject = mode === "granted" ? { value: api.value }
      : api.id.endsWith("isAvailable") ? { value: mode !== "unavailable" }
      : api.id.endsWith("requestAuthorization") ? { value: false }
      : api.id.endsWith("authorizationStatus") ? { value: mode === "unavailable" ? "disabled" : "denied" }
      : { error: mode === "unavailable" ? `${group} is unavailable` : `${group} permission denied` };
    result = setResponse(result, api.id, response);
  }
  return result;
}
