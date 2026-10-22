// Descriptive data API metadata, shared by Studio completion and Web mocks.
// Native JSExport protocols remain authoritative. This catalog grants no access.
const sampleStart = "2026-01-01T00:00:00Z";
const sampleEnd = "2026-01-01T12:00:00Z";
const measure = (value, unit) => ({ value, unit, hasSamples: true, start: sampleStart, end: sampleEnd });
const group = (name, values, legacy) => Object.entries(values).map(([method, value]) => ({ id: `$${name}.${method}`, group: name, value, legacy: [legacy, method] }));
const samples = [
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
  { id: "$calendar.isAvailable", group: "calendar", value: true },
  { id: "$calendar.authorizationStatus", group: "calendar", value: "authorized" },
  { id: "$calendar.requestAuthorization", group: "calendar", value: true },
  { id: "$calendar.calendars", group: "calendar", value: [{ id: "sample.personal", title: "Personal" }] },
  { id: "$calendar.events", group: "calendar", value: { status: "ready", items: [{ id: "sample.event", calendarID: "sample.personal", title: "Read and recharge", start: "2026-01-01T15:00:00Z", end: "2026-01-01T15:30:00Z", allDay: false }], fetchedAt: sampleEnd, source: "system", stale: false, truncated: false } },
  { id: "$reminders.isAvailable", group: "reminders", value: true },
  { id: "$reminders.authorizationStatus", group: "reminders", value: "authorized" },
  { id: "$reminders.requestAuthorization", group: "reminders", value: true },
  { id: "$reminders.lists", group: "reminders", value: [{ id: "sample.reminders", title: "Personal" }] },
  { id: "$reminders.items", group: "reminders", value: { status: "ready", items: [{ id: "sample.reminder", listID: "sample.reminders", title: "Read a chapter", due: "2026-01-01T16:00:00Z", hasTime: true, completed: false, completedAt: null, priority: 0 }], fetchedAt: sampleEnd, source: "system", stale: false, truncated: false } },
  { id: "$reminders.create", group: "reminders", value: { id: "sample.reminder", listID: "sample.reminders", status: "applied", replayed: false } },
  { id: "$reminders.update", group: "reminders", value: { id: "sample.reminder", listID: "sample.reminders", status: "applied", replayed: false } },
  { id: "$reminders.setCompleted", group: "reminders", value: { id: "sample.reminder", listID: "sample.reminders", status: "applied", replayed: false } },
  { id: "$health.authorizationStatus", group: "health", value: "notDisclosed" },
  { id: "$health.isAvailable", group: "health", value: true },
  { id: "$health.requestAuthorization", group: "health", value: true, legacy: ["health"] },
  { id: "$health.stepCountToday", group: "health", value: measure(6840, "count"), legacy: ["health.stepCountToday"] },
  { id: "$health.activeEnergyToday", group: "health", value: measure(420, "kcal"), legacy: ["health.activeEnergyToday"] },
  { id: "$health.heartRateLatest", group: "health", value: measure(72, "bpm"), legacy: ["health.heartRateLatest"] },
  { id: "$location.isAvailable", group: "location", value: true },
  { id: "$location.authorizationStatus", group: "location", value: "authorizedWhenInUse" },
  { id: "$location.isAuthorizedForWidgetUpdates", group: "location", value: true },
  { id: "$location.requestAuthorization", group: "location", value: true, legacy: ["location.authorization"] },
  { id: "$location.current", group: "location", value: { latitude: 37.3349, longitude: -122.009, altitude: 0, accuracy: 10, verticalAccuracy: 10, speed: -1, course: -1, timestamp: sampleEnd, accuracyAuthorization: "full", age: 0, isStale: false }, legacy: ["location"] },
];

const groupPolicy = {
  reminders: { platforms: ["ios", "macos"], authorization: "remindersRead", notes: "Requires reminders in widget.json and full system Reminders access. Reads require native Settings selected lists. create/update/setCompleted additionally require remindersWrite and a native declared action, stable requestID, durable replay receipts and an unchanged selected list. Web writes update preview-only items/receipts; receipt identities are derived from that state, with configurable API errors. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission." },
  calendar: { platforms: ["ios", "macos"], authorization: "calendarRead", notes: "Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission." },
  device: { platforms: ["ios", "macos"], authorization: "none", notes: "Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements." },
  system: { platforms: ["ios", "macos"], authorization: "none", notes: "System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable." },
  health: { platforms: ["ios"], authorization: "healthRead", notes: "Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain." },
  location: { platforms: ["ios"], authorization: "locationWhenInUse", notes: "Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale." },
};
export const dataAPICatalog = samples.map((sample) => {
  const method = sample.id.split(".")[1];
  const asynchronous = (["calendar", "reminders"].includes(sample.group) && !["isAvailable", "authorizationStatus"].includes(method)) || (sample.group === "health" && !["isAvailable", "authorizationStatus"].includes(method)) ||
    (sample.group === "location" && ["current", "requestAuthorization"].includes(method));
  const options = (sample.group === "location" && ["current", "requestAuthorization"].includes(method)) || (["calendar", "reminders"].includes(sample.group) && ["events", "items"].includes(method));
  return {
    ...sample,
    ...groupPolicy[sample.group],
    minimumRuntimeVersion: sample.group === "reminders" ? "1.4" : ["calendar"].includes(sample.group) || ["$health.authorizationStatus", "$location.isAuthorizedForWidgetUpdates"].includes(sample.id) ? "1.3" : "1.0",
    arguments: sample.group === "reminders" && ["create", "update", "setCompleted"].includes(method) ? ["options"] : options ? ["options?"] : [],
    ...(sample.group === "reminders" && ["create", "update", "setCompleted"].includes(method) ? { authorization: "remindersWrite" } : {}),
    asynchronous,
    nativeSource: `Shared/ScriptWidgetRuntime/Widget/API/ScriptWidgetRuntime${sample.group[0].toUpperCase()}${sample.group.slice(1)}.swift`,
    operation: sample.group === "reminders" && ["create", "update", "setCompleted"].includes(method) ? "write" : method === "requestAuthorization" ? "authorization" : ["isAvailable", "authorizationStatus", "isAuthorizedForWidgetUpdates"].includes(method) ? "availability" : "read",
    mock: "editable",
  };
});
