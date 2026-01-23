//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Meeting Countdown
// widget-param: "2026-02-01 09:30" or ISO string
//

const param = ($getenv("widget-param") || "").trim();
let target = null;

if (param) {
  const normalized = param.includes("T") ? param : param.replace(" ", "T");
  const parsed = new Date(normalized);
  if (!Number.isNaN(parsed.getTime())) {
    target = parsed;
  }
}

if (!target) {
  $render(
    <vstack frame="max" background="#0f172a">
      <text font="caption" color="#94a3b8">Meeting Countdown</text>
      <text font="title3" color="#e2e8f0">Set widget-param</text>
      <text font="caption2" color="#64748b">Example: 2026-02-01 09:30</text>
    </vstack>
  );
} else {
  const now = new Date();
  const diffMs = target.getTime() - now.getTime();
  const diffMin = Math.max(0, Math.floor(diffMs / 60000));
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);
  const hours = diffHour % 24;
  const minutes = diffMin % 60;

  $render(
    <vstack frame="max" background="#1e293b">
      <text font="caption" color="#94a3b8">Next Meeting</text>
      <text font="title2" color="#e2e8f0">{diffDay}d {hours}h {minutes}m</text>
      <text font="caption2" color="#64748b">Target: {target.toLocaleString()}</text>
    </vstack>
  );
}
