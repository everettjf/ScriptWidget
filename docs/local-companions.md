# Local plants and pets

Plant Care and Pocket Pet use original JSX geometry and a local care journal. Install either template, then open **Records & Configuration** to change its name, view history, export a backup, or preview and restore a backup. They require only package-scoped storage; no network, account, Health or location access is involved.

## Plant Care

Set a plant name and a personal care interval of 1–30 days (default 3). **Record care** saves one explicit check-in per local calendar day. Repeat taps are idempotent. **Undo** reverts the last change; **Clear today** is also available through the declared action directory and Shortcuts.

Until the first check-in, the template shows **No care recorded**. After a check-in, it calculates the next care day from the last recorded local calendar date and your interval, including across daylight saving changes. A passed interval shows **Care due**. Refreshing a widget never records care. The original `name,days` example parameter still supplies the plant name; its demonstration countdown is not treated as a real check-in.

The artwork and routine labels reflect journal activity; they do not measure a real plant's condition or determine how much water it needs. The interval is your own schedule.

## Pocket Pet

Name your local virtual companion (default Pebble). **Feed**, **Play** and **Rest** each count once per local calendar day. The face and status follow today's saved care: rest closes its eyes, completing all three shows a content expression, and returning after several empty days offers a reconnect message. Friendship labels follow distinct recorded care days. It never invents earlier interactions or requires purchases to catch up.

Both templates retain at most 366 recent local calendar days on edits, with a single saved undo operation. Care totals and routine/friendship levels describe this retained window, rather than an unlimited lifetime total. Future-dated imported records do not advance the current level. Resetting or restoring records can lower that level.

## Rendering and actions

All eight supported Home Screen/accessory families have layouts. Light and dark appearances share the same data. The larger families show recent care history; small/accessory presentations prioritize status. JSX shapes provide a static fallback, with no reliance on animation or external artwork. A midnight timeline requests a date change; WidgetKit controls actual refresh timing. Rendering and future timeline projections are read-only.

Actions reuse the package declarations and existing Widget/Control/Shortcuts execution path. **Record plant care** and **Feed pet** also declare a Control button. Their availability in system pickers and actual device clicks still need the system acceptance pass.

Backups contain only each template's configuration and its own journal. They cannot select a storage namespace, switch an installation, import executable code or restore into a different record kind. Atomic writes reject conflicts or unavailable storage visibly; malformed saved data is not replaced by sample data.
