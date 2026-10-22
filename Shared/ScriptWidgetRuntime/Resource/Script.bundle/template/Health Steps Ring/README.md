# Health card

Install the complete package, then open Records & Configuration to choose steps, active energy or latest heart rate. Save a daily step goal and active-energy goal. An optional JSON instance parameter overrides `metric` (`steps`, `energy`, `heart`), `stepsGoal` (1–100000) or `energyGoal` (1–10000 kcal).

On iPhone, enable Health access from ScriptWidget Settings. The script never prompts for authorization or writes to HealthKit. It queries only the chosen metric in the current timeline entry. Other platforms, uninstalled native previews and future projections show guidance instead of reading personal data. Web Studio uses editable, explicitly simulated examples.

HealthKit does not reveal whether read access was denied. No readable samples, including a legacy zero without sample-presence information, show an explanatory empty state. API 1.3 adds `hasSamples`; a readable zero is valid for steps/energy. This flag indicates readable data presence, never permission status. See Apple's authorization documentation: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data.

Daily totals use the device's current day and are accepted only with a recent query timestamp. Heart rate is the latest available sample, labelled with its age, never a live measurement or a goal ring; samples older than 24 hours are not shown. Invalid units, dates and values are rejected. Refresh timing is controlled by the system.

Health readings are not persisted by this template. Record backups contain configuration only. WidgetKit may retain an already-rendered view until it next refreshes; this template cannot promise immediate system refresh after permissions change. Bundled artwork and test previews use synthetic readings, never private data.
