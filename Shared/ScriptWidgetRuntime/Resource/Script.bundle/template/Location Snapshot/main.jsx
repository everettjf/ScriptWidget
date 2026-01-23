//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Location Snapshot
// Requires Location permission in the main app.
//

if (!$location.isAvailable()) {
  $render(
    <vstack frame="max" background="#0f172a">
      <text font="title3" color="#f87171">Location Unavailable</text>
      <text font="caption" color="#94a3b8">Location services are disabled.</text>
    </vstack>
  );
} else {
  const status = $location.authorizationStatus();
  const authorized = status === "authorizedWhenInUse" || status === "authorizedAlways";

  if (!authorized) {
    $render(
      <vstack frame="max" background="#0f172a">
        <text font="title3" color="#fbbf24">Permission Needed</text>
        <text font="caption" color="#94a3b8">Enable Location access in the app.</text>
      </vstack>
    );
  } else {
    const location = await $location.current();
    const lat = location.latitude.toFixed(4);
    const lon = location.longitude.toFixed(4);
    const accuracy = Math.max(0, Math.round(location.accuracy));

    $render(
      <vstack frame="max" background="#111827" spacing="6">
        <text font="caption" color="#94a3b8">Location Snapshot</text>
        <text font="title3" color="#e2e8f0">{lat}, {lon}</text>
        <text font="caption" color="#94a3b8">Accuracy: {accuracy}m</text>
        <text font="caption2" color="#64748b">{location.timestamp}</text>
      </vstack>
    );
  }
}
