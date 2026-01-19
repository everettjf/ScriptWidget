//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// System Insights
//

const memory = $system.memory();
const uptimeHours = ($system.systemUptime() / 3600).toFixed(1);
const cpuCount = $system.processorCount();
const activeCpu = $system.activeProcessorCount();

$render(
  <vstack frame="max" padding="12" background="#0f172a">
    <text font="caption" color="#94a3b8">System Insights</text>
    <text font="title3" color="#e2e8f0">{$system.platform().toUpperCase()}</text>
    <text font="caption" color="#94a3b8">OS: {$system.osVersionString()}</text>
    <text font="caption" color="#94a3b8">CPU: {cpuCount} ({activeCpu} active)</text>
    <text font="caption" color="#94a3b8">Memory: {(memory.physical / 1024 / 1024 / 1024).toFixed(1)} GB</text>
    <text font="caption" color="#94a3b8">Uptime: {uptimeHours}h</text>
  </vstack>
);
