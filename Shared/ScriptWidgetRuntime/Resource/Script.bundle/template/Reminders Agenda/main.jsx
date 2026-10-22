// Reminders Agenda — actual EventKit data on iPhone, iPad and Mac.
// Declare reminders in widget.json. Run in the app to grant access.
// Optional widget parameter: comma-separated list IDs from $reminders.lists().
// Browser previews use editable samples; native templates never seed fake reminders.
const size = $getenv("widget-size");
const accessory = size.startsWith("accessory");
const dark = $device.isdarkmode();
const foreground = accessory ? "primary" : (dark ? "#f3f4f6" : "#172033");
const secondary = accessory ? "secondary" : (dark ? "#9ca3af" : "#68758b");
const background = accessory ? "clear" : (dark ? "#131b2a" : "#f4f7fc");
const accent = accessory ? "primary" : "#5274d9";
const small = size === "small" || size === "systemSmall";
const limit = accessory || small ? 2 : (size === "medium" || size === "systemMedium" ? 3 : 6);
let items = [], message = "", authorized = false, stale = false, failed = false;


try {
  if (!$reminders.isAvailable()) message = "Reminders is unavailable on this device.";
  else if ($reminders.authorizationStatus() !== "authorized") message = small ? "Settings → Reminders in ScriptWidget." : "Connect Reminders in ScriptWidget Settings.";
  else {
    authorized = true;
    const parameter = $getenv("widget-param").trim();
    const options = { limit, maxAgeSeconds: 60 };
    if (parameter) options.listIDs = parameter.split(",").map(id => id.trim()).filter(Boolean);
    const result = await $reminders.items(options);
    items = Array.isArray(result.items) ? result.items : [];
    stale = result.stale;
    if (!items.length) message = "No reminders due today.";
  }
} catch (error) {
  failed = true;
  message = String(error).includes("No Reminder lists") ? (small || accessory ? "Choose reminder lists in Settings." : "Choose reminder lists in ScriptWidget Settings.")
    : String(error).includes("invalid_options") ? (small || accessory ? "Review Reminders selection." : "Review your Reminders selection and widget parameter.")
    : (small || accessory ? "Open ScriptWidget to check access." : "Reminders could not load. Open ScriptWidget to check access.");
}

function reminderTime(item) {
  if (!item.hasTime) return "Today";
  return new Date(item.due).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

if (small && (!authorized || failed)) {
  $render(<link url="scriptwidget://reminders-access"><vstack frame="max" padding="14" spacing="6" alignment="leading" background={background}>
    <text font="headline" color={foreground}>Reminders</text>
    <text font="caption" color={secondary}>{failed ? "Review list access in Settings." : "Connect in ScriptWidget Settings."}</text>
    <spacer/>
    <text font="caption" color={accent}>Open Settings →</text>
  </vstack></link>);
} else if (size === "accessoryInline") {
  $render(<text>{items.length ? `${reminderTime(items[0])} ${items[0].title}` : (failed ? "Check Reminders access" : authorized ? "Nothing due today" : "Connect Reminders")}</text>);
} else if (size === "accessoryCircular") {
  $render(<vstack spacing="2"><icon systemName="checklist" size="20"/><text font="caption">{failed ? "Check" : authorized ? `${items.length} items` : "Connect"}</text></vstack>);
} else {
  $render(
    <vstack frame="max" padding={accessory ? "4" : "16"} spacing={accessory ? "4" : "10"} alignment="leading" background={background}>
      <hstack spacing="6"><icon systemName="checklist" size="16" color={accent}/><text font="caption" color={secondary}>{small ? "AGENDA" : "DUE TODAY"}</text><spacer/>{stale && <text font="caption2" color={secondary}>Cached</text>}</hstack>
      {items.map(item => <hstack spacing="10"><rect frame="3,30" color={accent}/><vstack alignment="leading" spacing="3"><text font={small || accessory ? "caption" : "headline"} color={foreground}>{item.title || "Untitled reminder"}</text><text font="caption2" color={secondary}>{reminderTime(item)}</text></vstack><spacer/></hstack>)}
      {!!message && <text font={authorized && !failed ? "headline" : "caption"} color={foreground}>{message}</text>}
      {(!authorized || failed) && !accessory && <link url="scriptwidget://reminders-access"><hstack spacing="6"><icon systemName="lock.open" size="14"/><text font="caption">{small ? "Settings" : "Open ScriptWidget"}</text></hstack></link>}
      {!accessory && <spacer/>}
    </vstack>
  );
}
