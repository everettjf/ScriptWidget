# Reminders Agenda

Shows pending reminders due today from the lists selected in ScriptWidget Settings.

1. Run the installed widget in ScriptWidget and open **Settings → Reminders**.
2. Grant system access, select allowed lists and save.
3. Optionally set the widget parameter to comma-separated IDs from `$reminders.lists()` to narrow the selection further.

The app requires full system Reminders access, but this script only reads. It cannot create, modify or complete reminders. Undated pending reminders are excluded. Query failures and setup states are shown separately from an empty day. Native execution never inserts sample reminders; Web Studio provides editable samples.

See [Reminders API](../../../../../../../docs/reminders-api.md).
