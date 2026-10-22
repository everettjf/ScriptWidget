# Health Overview

Review Health access in ScriptWidget Settings on a supported device, then open the installed widget. This template queries real HealthKit summaries and never inserts or saves sample readings. Web Studio uses editable samples.

Widget parameter: `overview` (default), `sleep`, `activity` or `workouts`.

Sleep covers the last 24 elapsed hours; activity rings use the current local day and the system's move mode/goals; workouts list up to five fully-contained records in the last seven days. Missing optional goals/statistics stay missing. Empty results cannot distinguish no records from read access you chose not to share.

Sleep unions overlaps with an explicit detailed-stage precedence and flags conflicting sources/partial windows. It does not add time in bed to time asleep or invent sleep stages. See [Health API](../../../../../../../docs/health-api.md) for exact semantics and limits. The existing Health Steps Ring remains available for step, energy and heart-rate cards.
