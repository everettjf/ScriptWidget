# Reminders Agenda

Shows pending reminders due today from the lists selected in ScriptWidget Settings.

1. Run the installed widget in ScriptWidget and open **Settings → Reminders**.
2. Grant system access, select allowed lists and save.
3. Optionally set the widget parameter to comma-separated IDs from `$reminders.lists()` to narrow the selection further.

The app requires full system Reminders access. The explicit **Complete next** action completes the next due reminder in the selected lists; ordinary rendering only reads. The package declares remindersWrite and storage and keeps a stable pending request until delivery is confirmed. If a result is uncertain, inspect the actual Reminders app first, then use **Checked Reminders? Clear pending** in a medium or larger widget. Clearing the pending request does not undo a system change or erase the runtime write receipt. Undated pending reminders are excluded. Query failures and setup states are shown separately from an empty day. Native execution never inserts sample reminders; Web Studio provides editable samples.

See [Reminders API](../../../../../../../docs/reminders-api.md).
