//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Health Steps Ring
// Requires read-only HealthKit permission in the main app.
//

const goal = 8000;

if (!$health.isAvailable()) {
  $render(
    <vstack frame="max"  background="#0f172a">
      <text font="title3" color="#f87171">HealthKit Unavailable</text>
      <text font="caption" color="#94a3b8">Check platform support.</text>
    </vstack>
  );
} else {
  const granted = await $health.requestAuthorization();
  if (!granted) {
    $render(
      <vstack frame="max" background="#0f172a">
        <text font="title3" color="#fbbf24">Permission Needed</text>
        <text font="caption" color="#94a3b8">Enable Health access in the app.</text>
      </vstack>
    );
  } else {
    const steps = await $health.stepCountToday();
    const value = steps.value || 0;
    const progress = Math.min(1, value / goal);

    $render(
      <vstack frame="max" background="#0f172a">
        <text font="caption" color="#94a3b8">Steps Today</text>
        <gauge
          angle="260"
          value={progress}
          thickness="10"
          label={value.toFixed(0)}
          labelFont="title3"
          title={`Goal ${goal}`}
          titleFont="caption"
        />
        <text font="caption2" color="#94a3b8">{(progress * 100).toFixed(0)}% of goal</text>
      </vstack>
    );
  }
}
