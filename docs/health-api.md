# Health readings

`$health` exposes read-only HealthKit access on iPhone. Package 2.0 must declare `health`; native uninstalled previews and future timeline projections cannot read it. Query cancellation, execution identity and data-query budgets apply. Request authorization through the main app; widgets cannot present the system consent sheet.

`authorizationStatus()` reports `notDisclosed` when HealthKit is available and the package can use it. It does not return a per-type read grant. Apple deliberately does not disclose read denial: [authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data). Consent-sheet completion is not evidence that all read types were granted.

`stepCountToday()` and `activeEnergyToday()` query cumulative statistics from local start of day to the query time, in count and kcal. `heartRateLatest()` returns the latest available sample in bpm, with sample start/end. All return Promises; unavailable, query and policy errors reject.

API 1.3 adds `hasSamples` to these reading objects. Existing `value`, `unit`, `start` and `end` fields remain compatible. A false flag means no readable quantity/sample was returned; it cannot distinguish denied access from an empty store. The legacy numeric zero remains for compatibility. A true flag permits an actual zero daily aggregate to be displayed. The latest-heart query returns false and empty dates when there is no sample.

The Health Steps Ring template offers steps, active energy and latest heart rate, saved goals and explicit empty/error/platform states across eight sizes. Its record backup includes settings only. Readings are queried afresh rather than retained in package storage. The system can retain its previous rendered widget until the next permitted refresh.

Studio defaults provide current-day, explicitly simulated readings. Editing values, timestamps, units and `hasSamples` allows testing no-data, stale or malformed results. HealthKit returns real values only on an installed, authorized, supported device; browser/native fixture screenshots do not prove device authorization or sampling coverage.
