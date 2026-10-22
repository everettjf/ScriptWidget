# Scheduled widget states

Runtime 1.3 supports opt-in local daily transitions. The widget always receives an immediate current entry. Without a schedule, existing frequency settings still determine when WidgetKit is asked for a refresh.

## Declare the schedule

```json
{
  "minimumRuntimeVersion": "1.3",
  "timeline": {
    "dailyTimes": ["06:00", "12:00", "18:00", "22:00"],
    "timeZone": "America/Los_Angeles"
  }
}
```

Add these properties to a valid Package 2.0 `widget.json`. `dailyTimes` contains 1–4 sorted unique `HH:mm` strings. `timeZone` is optional; omission uses the device zone. An explicit zone must be UTC or a case-sensitive identifier from the supported zone catalog (`Web/preview-engine/src/timeZones.js`, generated from Foundation). Use e.g. America/Los_Angeles, not a wrong-case spelling or US/Pacific alias; available names also depend on the platform's timezone database. Unknown nested keys, invalid times/zones and unsupported package versions fail closed. Existing packages may omit `timeline` entirely.

The shared planner provides at most five entries: now and up to four transitions within the next 24 elapsed hours. The configured frequency remains the requested data-refresh interval. If a DST-shortened day would produce more future transitions, the planner requests another timeline by the last included transition, before the omitted ones. This bounds work without silently dropping the next day.

## Render the planned state

`$getenv` exposes:

| Name | Value |
| --- | --- |
| `timeline-date` | ISO-8601 UTC date for this entry |
| `timeline-time-zone` | Schedule/device zone identifier |
| `timeline-slot` | Index in `dailyTimes`, or `-1` for an unscheduled package |
| `timeline-is-projection` | `true` for future entries; `false` for the current entry |

Use the slot to select the corresponding content. It already accounts for timezone and DST rules. Do not replace `Date`, `Date.now`, or the system clock: those represent actual execution time, while WidgetKit may archive views ahead of their display time.

```jsx
const labels = ["Morning focus", "Afternoon flow", "Evening reset", "Quiet hours"];
const slot = Number($getenv("timeline-slot"));
$render(<vstack><text>{labels[slot] || "Find your rhythm"}</text></vstack>);
```

A missing wall time advances to the next valid local time. Repeated wall times use the first occurrence. If multiple transitions fall into one DST gap, the later slot wins at the collapsed instant. During an autumn clock rollback, slot identity retains the already-started period instead of moving backward merely because the displayed hour repeats. Midnight and non-hour zone offsets use calendar boundaries.

While running, the apps request a timeline reload on system timezone/day changes; iOS also observes significant time changes. This does not promise that the app is awakened in the background or that WidgetKit reloads immediately.

The built-in **Day Rhythm** template provides four original light themes and all supported widget families. Optional `widget-param` JSON can set a display name. Editing labels/assets does not require granting any system-data or network permission.

## Future entries are read-only

A future entry is a display projection, not an instruction to execute tomorrow's actions now. The host captures this state independently of the replaceable JavaScript `$getenv` function.

- Storage reads work; writes, compare-and-set, remove and clear return false.
- Network and Data Source Plugin requests reject with `[timeline_read_only]`.
- No authorization dialog is requested. Location can read an authorized, validated cached position. Calendar events can read a matching authorized bounded snapshot; listing live calendars is unavailable. Missing snapshots reject instead of fetching live data.
- Health live queries reject. A template may render an explicitly saved display summary, with its age and limitations, rather than implying that future measurements exist.
- Package file reads and imports still work. Existing execution, element, network and data-query limits remain in force for each render. The schedule caps the number of rendered states; it does not make arbitrary slow scripts cheap.

User-triggered buttons/controls run their own current action execution and may save records normally. A projected render itself cannot increment a habit, consume a task or send a service request. Package/system permissions are still checked before private snapshots are returned. Revocation is not bypassed by scheduling.

## Preview and validation

Web Studio's Timeline date control selects a scheduled state. Fixed-time preview is read-only; Now returns to current execution. Upcoming transition buttons use the package's schedule. The date input uses the browser's local time for entry, while slot calculation honors the declared schedule zone. No mock or fixed preview time is exported into the widget package.

The low-level preview engine exposes `buildTimelinePlan` from `src/timeline.js`. Native and browser hosts supply current schedule values by default; an explicit `environments` override can provide a planned date/slot for deterministic tests. This changes only the entry context, not clock globals or real system data.

Tests cover immediate legacy entries, UTC/year boundaries, non-hour offsets, DST gaps/repeats, entry caps and read-only boundaries. Fixed-date canonical native trees compare all four Day Rhythm phases across eight families with the Web result. Native fixture screenshots validate layout. The hosted five-runtime timing/memory probe is a repeatable baseline, not an extension-memory acceptance result.

WidgetKit controls actual display and refresh times. Dates and refresh policies are requests, not minute-accurate background scheduling guarantees. See Apple's [Timeline documentation](https://developer.apple.com/documentation/widgetkit/timeline) and [refresh guidance](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date). Physical iPhone/iPad/Mac widget installation, timezone changes and extension resource behavior require separate recorded acceptance; passing a hosted or simulator test does not prove these.
