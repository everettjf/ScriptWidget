//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Local Weather (Location)
// Requires Location permission in the main app.
//

if (!$location.isAvailable()) {
  $render(
    <vstack frame="max" background="#0f172a">
      <text font="title3" color="#f87171">Location Unavailable</text>
      <text font="caption" color="#94a3b8">Location services are disabled.</text>
    </vstack>
  );
  return;
}

const status = $location.authorizationStatus();
const authorized = status === "authorizedWhenInUse" || status === "authorizedAlways";

if (!authorized) {
  $render(
    <vstack frame="max" background="#0f172a">
      <text font="title3" color="#fbbf24">Permission Needed</text>
      <text font="caption" color="#94a3b8">Enable Location access in the app.</text>
    </vstack>
  );
  return;
}

const location = await $location.current();
const lat = location.latitude.toFixed(4);
const lon = location.longitude.toFixed(4);

const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,apparent_temperature,weather_code&timezone=auto`;
const result = await fetch(url);
const data = JSON.parse(result);
const current = data.current || {};

$render(
  <vstack frame="max" background="#0f172a" spacing="6">
    <text font="caption" color="#94a3b8">Local Weather</text>
    <text font="title2" color="#e2e8f0">{current.temperature_2m ?? "-"} deg C</text>
    <text font="caption" color="#94a3b8">Feels like {current.apparent_temperature ?? "-"} deg C</text>
    <text font="caption2" color="#64748b">Weather code: {current.weather_code ?? "-"}</text>
  </vstack>
);
