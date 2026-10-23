# Local Live Activities

This capability is in the development worktree. It has not shipped in the previously uploaded App Store build. Physical lock-screen and Dynamic Island acceptance remains required.

## Start, update and finish

On iOS 16.2 or later, open **Settings → Live Activities**, choose an installed widget, enter its parameter and initial state, and start while ScriptWidget is in the foreground. The editor's Live Activity command uses the same manager after compiling the selected installation. The system can refuse a request because of device support, user settings or activity limits; the app displays a concise error.

The management screen reads `Activity.activities` when reopened. It does not persist activity IDs or recreate an activity automatically. Select a running activity to edit its state or stale date, reload the latest state, finish with a final state, or dismiss immediately. An update based on an older draft is rejected; reload and review it before retrying. The app allows at most four pending/active/stale activities and rejects an identical start unless you explicitly request another copy. The system may impose a lower limit.

Static attributes and dynamic state share ActivityKit's 4 KiB encoded-data limit. ScriptWidget measures both together, including JSON escaping and a conservative envelope reserve. A state of 4 KiB alone will normally exceed the combined limit. Pending activities count toward the local limit and remain available for management.

Activities bind to the library and installation UUID, rather than just a widget name. Renaming preserves the binding. Removal, another active library, or reinstalling a widget with the same name cannot redirect an old activity to new source. Reconciliation ends retired or invalid activities; a temporarily unavailable library does not imply deletion. Older activities without installation identity must be restarted. Source and resource loading uses the owner-bound package snapshot and cache.

## Live Activity Demo

Install the bundled **Live Activity Demo** template and select it in the management screen. Its empty state is an explicit start instruction. It never invents health or activity readings. The “25-minute focus” preset creates a real deadline from the current time.

Optional state JSON (also accepted as widget parameter when state is empty):

```json
{"title":"Reading","detail":"Chapter finished","progress":3,"total":8}
```

```json
{"title":"Focus","detail":"One focused session","endsAt":"2026-12-01T18:25:00Z"}
```

Only `title` (1–40 characters), `detail` (up to 80), integer `progress` and `total` (0 ≤ progress ≤ total, 1 ≤ total ≤ 10000), and a timezone-qualified ISO `endsAt` are supported. Invalid state displays a helpful message without echoing the supplied data. Omit `progress` and `total` together to show status instead. A future deadline uses the native date timer; an expired deadline displays “Time is up”. Marking content stale shows that it needs an update. System scheduling controls when a stale or expired presentation is refreshed; this is not a precise alarm.

The template supplies the lock-screen layout, four expanded Island regions, compact leading/trailing, and minimal content. Browser tests capture these regions to compare their trees against real JavaScriptCore output. Web Studio does not currently provide the system's complete Dynamic Island presentation or ActivityKit lifecycle; tree parity is not evidence of a real device presentation.

## Runtime limits and platform scope

Scripts read `$getenv("live-activity-state")` and `$getenv("live-activity-is-stale")`. In Live Activity and Island presentations, network fetches, Data Source Plugin service requests, and location requests reject with `[live_activity_unavailable]`, even if scripts replace `$getenv`. Fetch or obtain data in the app, then update the activity's state. Rendering performs no background polling.

No push token is requested, no remote update server is configured, and macOS has no ActivityKit management screen. This is the local lifecycle scope of M2; remote updates and Watch are excluded from this release goal.

Apple references: [Live Activity data and constraints](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), [interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities). Interactive Live Activity controls require a suitable LiveActivityIntent; the demo uses the app's management screen and does not advertise interactive Island controls.

## Repeatable simulator SDK test

Run `./Scripts/activitykit-simulator-smoke.sh` to create a fresh private iPhone simulator, install and compile the actual demo into its App Group cache, call the real ActivityKit request/update/end APIs, restore through the system list after terminating the app host process, verify the final ended state and remove only that simulator. Evidence is saved under `__Release/capabilities/live-activity/sdk-run.*`. No existing simulator or physical-device data is selected.

The test requires an explicit opt-in flag, the expected simulator UUID and the private name prefix; existing activities or library profiles cause it to fail before changing them. Normal test runs skip this test and use isolated clients. `SCRIPTWIDGET_ACTIVITYKIT_DERIVED_DATA` can select a build cache; runtime and device-type overrides are available for installed Simulator versions. `SCRIPTWIDGET_ACTIVITYKIT_KEEP_SIMULATOR=1` retains the test device for inspection. `SCRIPTWIDGET_ACTIVITYKIT_CAPTURE=1` leaves the updated activity running for 30 seconds before ending it, for an interactive Simulator capture.

On 2026-10-21, the direct real-SDK test and a separate fresh-device run through this script both passed with one test, zero failures and zero skips. These establish Simulator SDK behavior with real installation-bound storage; they do not establish physical-device rendering or signed iCloud behavior.

The updated script uses Xcode's two test repetitions with `-test-repetition-relaunch-enabled YES`. The first process leaves its activity running and writes a run-bound checkpoint; the second requires a different PID and verifies that the writer process no longer exists. It retrieves the same activity ID, profile/installation binding and initial state from ActivityKit, resolves the saved native cache, updates progress, then ends the activity. Both repetition nodes must pass, even though Xcode's summary counts them as one unique test. The 2026-10-21 run `sdk-run.YnvFWZ` passed both repetitions; its saved reports contain the two PIDs and unchanged activity identity.

Two independent `xcodebuild test` invocations can install the host again and are not a clean app-relaunch experiment. The installed `xcodebuild.xctestrun(5)` manual documents `UseDestinationArtifacts`, but this Xcode only supports it on physical devices. The smoke uses the supported repetition/relaunch mode instead. This validates the manager and persisted library/cache across test-host processes; normal app navigation, physical lock-screen/Island appearance and signed iCloud still require separate acceptance. See Apple's [command-line testing reference](https://developer.apple.com/library/archive/technotes/tn2339/_index.html) for build/test artifact workflows.
