# Countdown

Install the complete template, then open **Records & Configuration** from the installed widget's menu. Choose an event name, a target date, whether it repeats every year, and a blue, rose or green accent. Save Configuration publishes the settings for that installation. Backup & Restore includes these settings; the countdown does not invent daily history or check-ins.

An empty parameter uses the saved configuration. Before choosing a date the widget shows a setup prompt. Each widget instance may override the saved settings:

- `2027-07-12 Summer trip` counts local Gregorian calendar days.
- `2027-07-12T12:30:00 Flight` keeps the earlier local-time countdown format, including counting up after the moment.
- `{"title":"Birthday","targetDate":"2024-02-29","repeatYearly":true,"accent":"rose"}` repeats February 29 only in leap years.

JSON overrides may contain `title`, `targetDate`, `repeatYearly` and `accent` only. Dates must be real calendar dates in `YYYY-MM-DD` form from 1970 through 9999. Names accept up to 40 UTF-16 code units; the small widget shortens the visible title. Past dates show days since, and the target day shows Today. Parameters override rendering without modifying saved configuration.

Calendar days use date ordinals rather than elapsed 24-hour periods, so daylight-saving changes do not shift the result. Date-only input is kept as a local calendar date rather than parsed as UTC. A local timestamp that falls inside a daylight-saving gap is rejected. Yearly repeats ignore the original year, but preserve the selected month and day. The next valid February 29 is chosen rather than moving the event to March 1.

All declared home-screen and accessory families render offline. The package requests storage only. Midnight timeline entries allow the date to advance; WidgetKit decides when to display updates. This is not a continuously ticking or exact-alarm timer. Records stay on this installation/device; the template does not promise record synchronization through iCloud.
