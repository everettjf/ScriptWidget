# Data API capability catalog

> Generated from `Editor/editorfe/src/dataAPICatalog.js`. Native JSExport protocols remain authoritative. This catalog is descriptive and grants no permissions.

This covers device, system, health, location, calendar and reminders data methods. Files, network, storage, rendering and runtime configuration retain their own contracts. Platforms list intended real-data support, not mocked browser execution; hardware and OS authorization still determine availability.

Existing data-method return formats are unchanged. Present manifests now undergo package and minimum-version validation before execution. In particular, HealthKit does not expose individual read-denial status, and location cache presence is not proof that permission is still granted. Default mock values are illustrative, never measurements from the current device.

| API | Minimum native API | Native platforms | Execution | Authorization | Operation |
| --- | --- | --- | --- | --- | --- |
| `$device.screen()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.language()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.model()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.name()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.battery()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.systemVersion()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.isdarkmode()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.totalDiskSpace()` | 1.0 | ios, macos | Synchronous | none | read |
| `$device.freeDiskSpace()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.appInfo()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.locale()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.preferredLanguages()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.timeZone()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.is24HourClock()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.calendarInfo()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.systemUptime()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.memory()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.thermalState()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.lowPowerMode()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.brightness()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.reduceMotionEnabled()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.platform()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.hostName()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.processName()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.osVersionString()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.processorCount()` | 1.0 | ios, macos | Synchronous | none | read |
| `$system.activeProcessorCount()` | 1.0 | ios, macos | Synchronous | none | read |
| `$calendar.isAvailable()` | 1.3 | ios, macos | Synchronous | calendarRead | availability |
| `$calendar.authorizationStatus()` | 1.3 | ios, macos | Synchronous | calendarRead | availability |
| `$calendar.requestAuthorization()` | 1.3 | ios, macos | Promise | calendarRead | authorization |
| `$calendar.calendars()` | 1.3 | ios, macos | Promise | calendarRead | read |
| `$calendar.events(options?)` | 1.3 | ios, macos | Promise | calendarRead | read |
| `$reminders.isAvailable()` | 1.4 | ios, macos | Synchronous | remindersRead | availability |
| `$reminders.authorizationStatus()` | 1.4 | ios, macos | Synchronous | remindersRead | availability |
| `$reminders.requestAuthorization()` | 1.4 | ios, macos | Promise | remindersRead | authorization |
| `$reminders.lists()` | 1.4 | ios, macos | Promise | remindersRead | read |
| `$reminders.items(options?)` | 1.4 | ios, macos | Promise | remindersRead | read |
| `$health.authorizationStatus()` | 1.3 | ios | Synchronous | healthRead | availability |
| `$health.isAvailable()` | 1.0 | ios | Synchronous | healthRead | availability |
| `$health.requestAuthorization()` | 1.0 | ios | Promise | healthRead | authorization |
| `$health.stepCountToday()` | 1.0 | ios | Promise | healthRead | read |
| `$health.activeEnergyToday()` | 1.0 | ios | Promise | healthRead | read |
| `$health.heartRateLatest()` | 1.0 | ios | Promise | healthRead | read |
| `$location.isAvailable()` | 1.0 | ios | Synchronous | locationWhenInUse | availability |
| `$location.authorizationStatus()` | 1.0 | ios | Synchronous | locationWhenInUse | availability |
| `$location.isAuthorizedForWidgetUpdates()` | 1.3 | ios | Synchronous | locationWhenInUse | availability |
| `$location.requestAuthorization(options?)` | 1.0 | ios | Promise | locationWhenInUse | authorization |
| `$location.current(options?)` | 1.0 | ios | Promise | locationWhenInUse | read |

## device

Device values depend on hardware. Some legacy Mac values are placeholders; inspect the API documentation before using them as measurements.

### `$device.screen`

Default editable preview sample:

```json
{
  "width": 390,
  "height": 844,
  "scale": 3
}
```

### `$device.language`

Default editable preview sample:

```json
"en"
```

### `$device.model`

Default editable preview sample:

```json
"iPhone"
```

### `$device.name`

Default editable preview sample:

```json
"My iPhone"
```

### `$device.battery`

Default editable preview sample:

```json
{
  "level": 0.8,
  "state": "unplugged"
}
```

### `$device.systemVersion`

Default editable preview sample:

```json
"26.0"
```

### `$device.isdarkmode`

Default editable preview sample:

```json
false
```

### `$device.totalDiskSpace`

Default editable preview sample:

```json
128000000000
```

### `$device.freeDiskSpace`

Default editable preview sample:

```json
64000000000
```

## system

System metadata, not whole-device CPU, FPS or network traffic monitoring. Hardware-specific values may be unavailable.

### `$system.appInfo`

Default editable preview sample:

```json
{
  "name": "ScriptWidget",
  "bundleId": "com.everettjf.scriptwidget",
  "version": "27.1.2",
  "build": "27012"
}
```

### `$system.locale`

Default editable preview sample:

```json
"en_US"
```

### `$system.preferredLanguages`

Default editable preview sample:

```json
[
  "en-US"
]
```

### `$system.timeZone`

Default editable preview sample:

```json
{
  "identifier": "UTC",
  "abbreviation": "GMT",
  "offsetSeconds": 0
}
```

### `$system.is24HourClock`

Default editable preview sample:

```json
false
```

### `$system.calendarInfo`

Default editable preview sample:

```json
{
  "identifier": "gregorian",
  "firstWeekday": 1,
  "minimumDaysInFirstWeek": 1
}
```

### `$system.systemUptime`

Default editable preview sample:

```json
3600
```

### `$system.memory`

Default editable preview sample:

```json
{
  "physical": 8589934592
}
```

### `$system.thermalState`

Default editable preview sample:

```json
"nominal"
```

### `$system.lowPowerMode`

Default editable preview sample:

```json
false
```

### `$system.brightness`

Default editable preview sample:

```json
0.5
```

### `$system.reduceMotionEnabled`

Default editable preview sample:

```json
false
```

### `$system.platform`

Default editable preview sample:

```json
"ios"
```

### `$system.hostName`

Default editable preview sample:

```json
"My iPhone"
```

### `$system.processName`

Default editable preview sample:

```json
"ScriptWidgetWidget"
```

### `$system.osVersionString`

Default editable preview sample:

```json
"Version 26.0"
```

### `$system.processorCount`

Default editable preview sample:

```json
6
```

### `$system.activeProcessorCount`

Default editable preview sample:

```json
6
```

## calendar

Requires calendar in widget.json and full system Calendar access. The user's native Settings source selection limits metadata, events and cached snapshots; scripts cannot enlarge it. Use calendars() for permitted IDs and show setup when no sources are selected. Queries are read-only, limited to 31 days and 50 items. Preview calendarSelection simulates this scope without granting package permission.

### `$calendar.isAvailable`

Default editable preview sample:

```json
true
```

### `$calendar.authorizationStatus`

Default editable preview sample:

```json
"authorized"
```

### `$calendar.requestAuthorization`

Default editable preview sample:

```json
true
```

### `$calendar.calendars`

Default editable preview sample:

```json
[
  {
    "id": "sample.personal",
    "title": "Personal"
  }
]
```

### `$calendar.events`

Default editable preview sample:

```json
{
  "status": "ready",
  "items": [
    {
      "id": "sample.event",
      "calendarID": "sample.personal",
      "title": "Read and recharge",
      "start": "2026-01-01T15:00:00Z",
      "end": "2026-01-01T15:30:00Z",
      "allDay": false
    }
  ],
  "fetchedAt": "2026-01-01T12:00:00Z",
  "source": "system",
  "stale": false,
  "truncated": false
}
```

## reminders

Requires reminders in widget.json and full system Reminders access. Scripts have read-only access to native Settings selected lists; they cannot create, edit or complete reminders. Use lists() for IDs. items() selects pending due dates or completed completion dates in a positive window of at most 31 days, up to 50 items. Undated pending reminders are excluded. remindersSelection mocks the user scope without granting permission.

### `$reminders.isAvailable`

Default editable preview sample:

```json
true
```

### `$reminders.authorizationStatus`

Default editable preview sample:

```json
"authorized"
```

### `$reminders.requestAuthorization`

Default editable preview sample:

```json
true
```

### `$reminders.lists`

Default editable preview sample:

```json
[
  {
    "id": "sample.reminders",
    "title": "Personal"
  }
]
```

### `$reminders.items`

Default editable preview sample:

```json
{
  "status": "ready",
  "items": [
    {
      "id": "sample.reminder",
      "listID": "sample.reminders",
      "title": "Read a chapter",
      "due": "2026-01-01T16:00:00Z",
      "hasTime": true,
      "completed": false,
      "completedAt": null,
      "priority": 0
    }
  ],
  "fetchedAt": "2026-01-01T12:00:00Z",
  "source": "system",
  "stale": false,
  "truncated": false
}
```

## health

Read-only HealthKit. Request access in the app. Authorization completion does not reveal whether individual read types were granted; empty results must not be labelled permission denied. API 1.3 readings add hasSamples: false means no readable samples, never a read-denial verdict. Existing value/unit/start/end fields remain.

### `$health.authorizationStatus`

Default editable preview sample:

```json
"notDisclosed"
```

### `$health.isAvailable`

Default editable preview sample:

```json
true
```

### `$health.requestAuthorization`

Default editable preview sample:

```json
true
```

### `$health.stepCountToday`

Default editable preview sample:

```json
{
  "value": 6840,
  "unit": "count",
  "hasSamples": true,
  "start": "2026-01-01T00:00:00Z",
  "end": "2026-01-01T12:00:00Z"
}
```

### `$health.activeEnergyToday`

Default editable preview sample:

```json
{
  "value": 420,
  "unit": "kcal",
  "hasSamples": true,
  "start": "2026-01-01T00:00:00Z",
  "end": "2026-01-01T12:00:00Z"
}
```

### `$health.heartRateLatest`

Default editable preview sample:

```json
{
  "value": 72,
  "unit": "bpm",
  "hasSamples": true,
  "start": "2026-01-01T00:00:00Z",
  "end": "2026-01-01T12:00:00Z"
}
```

## location

Package 2.0 requires location permission. Request system access in the app. Widgets also require isAuthorizedForWidgetUpdates. Cache is rechecked against authorization and precision, discarded after 24 hours or revocation, and reports age/isStale.

### `$location.isAvailable`

Default editable preview sample:

```json
true
```

### `$location.authorizationStatus`

Default editable preview sample:

```json
"authorizedWhenInUse"
```

### `$location.isAuthorizedForWidgetUpdates`

Default editable preview sample:

```json
true
```

### `$location.requestAuthorization`

Default editable preview sample:

```json
true
```

### `$location.current`

Default editable preview sample:

```json
{
  "latitude": 37.3349,
  "longitude": -122.009,
  "altitude": 0,
  "accuracy": 10,
  "verticalAccuracy": 10,
  "speed": -1,
  "course": -1,
  "timestamp": "2026-01-01T12:00:00Z",
  "accuracyAuthorization": "full",
  "age": 0,
  "isStale": false
}
```
