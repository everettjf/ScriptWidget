//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Battery & Brightness
//

const battery = $device.battery();
const brightness = $system.brightness();
const percent = (battery.level * 100).toFixed(0);

$render(
  <vstack frame="max" padding="12" background="#1e293b">
    <text font="caption" color="#94a3b8">Battery & Brightness</text>
    <text font="title2" color="#e2e8f0">{percent}%</text>
    <text font="caption" color="#94a3b8">State: {battery.state}</text>
    <text font="caption2" color="#64748b">Brightness: {brightness >= 0 ? Math.round(brightness * 100) + "%" : "n/a"}</text>
  </vstack>
);
