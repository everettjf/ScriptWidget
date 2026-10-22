# Reminders API

Runtime API 1.4 adds `$reminders` on iOS/iPadOS and macOS. Package 2.0 must declare `"reminders"` in `permissions`. A malformed manifest or missing permission cannot be overridden by Web mocks.

The native app asks for system Reminders access in **Settings → Reminders**. Apple grants full access; the scripting API currently exposes reads only. It cannot create, edit, delete or complete reminders. Write operations are still pending M3 work and require a separate design and authorization boundary.

## Methods

| Method | Return |
| --- | --- |
| `isAvailable()` | Boolean platform availability; an isolated uninstalled preview returns false |
| `authorizationStatus()` | `authorized`, `denied`, `restricted`, `notDetermined`, `unavailable`, or `undeclared` |
| `requestAuthorization()` | Promise of Boolean; app requests consent, widget only reports current status |
| `lists()` | Promise of up to 64 `{id, title}` records inside the user's selected scope |
| `items(options?)` | Promise of `{status, items, fetchedAt, source, stale, truncated}` |

`options` accepts only:

| Field | Default / bounds |
| --- | --- |
| `start`, `end` | ISO 8601 timestamps with timezone. Defaults: local midnight through next local midnight. Positive window, at most 31 × 24 hours |
| `listIDs` | Optional 1–16 unique opaque list IDs, each at most 256 UTF-8 bytes; every requested ID must exist and be allowed |
| `completed` | Boolean, default false. Pending items use the **due** window; completed items use the **completion** window |
| `limit` | Integer 1–50, default 10 |
| `maxAgeSeconds` | 0–86400 seconds, default 60; zero disables cache reuse |

Rows contain `{id, listID, title, due, hasTime, completed, completedAt, priority}`. `due` is an ISO timestamp when timed, a `YYYY-MM-DD` local floating date when all-day, or null. `completedAt` is an ISO timestamp or null. Priorities use EventKit's 0–9 range (0 means unset).

Undated pending items are excluded. A completed item with no readable completion timestamp cannot be placed in a completion window and is excluded. All-day dates overlap the selected local calendar day; they are not interpreted as UTC midnight. The end timestamp is exclusive.

`status` is `ready` or `empty`. `source` is `system` or `cache`; `stale` indicates a reused snapshot older than 60 seconds. Errors reject with a bracketed code such as `permission_denied`, `invalid_options`, `query_failed`, `query_limit` or `snapshot_required`. Do not present an error as “nothing due.”

## Scope and snapshots

Native Settings selects all lists, a subset, or none. Scripts can narrow this scope with `listIDs`, never enlarge it. Calendar and Reminders preferences are separate. IDs use exact UTF-8 identity; visually equivalent Unicode IDs are not aliases. Malformed or unsafe present preferences fail closed; they do not fall back to all lists.

Reads share the per-execution eight-query system-data budget. The EventKit request is cancelled when the execution ends. Processing scans up to 1,000 returned rows and reports `truncated` for unscanned or omitted results. EventKit itself returns an array without a pagination API: this is a processing/output bound, not a proven native peak-memory bound.

A private, package-owner-scoped snapshot is limited to 64 KiB. Each read and callback rechecks execution, authorization and selected scope before delivery. Future timeline entries and Live Activity presentations only use a matching saved snapshot; they cannot start live queries. Changing the query, selection, or completed flag prevents reuse. App/widget signed-container and physical-device behavior still require acceptance testing.

## Web Studio

The Reminders Mock Data group includes best-state samples, editable responses, failure/empty/denied scenarios and allowed-list JSON. `remindersSelection` is null for all, `[]` for none, or an array of selected IDs. Mock values stay in the browser draft and are excluded from widget exports. They cannot grant the package `reminders` permission. Dates, status and scope still filter mocked results.

```js
const result = await $reminders.items({ limit: 6, completed: false });
// Render result.items, or handle a rejected query with a setup/error state.
```

System authorization references: [Event store access](https://developer.apple.com/documentation/eventkit/accessing-the-event-store), [full Reminders access](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoreminders(completion:)), [usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription).
