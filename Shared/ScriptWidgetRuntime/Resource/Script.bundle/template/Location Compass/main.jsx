//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Location Compass
// Requires Location permission in the main app.
//

const directionFromCourse = (course) => {
  if (course < 0 || Number.isNaN(course)) return "-";
  const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"];
  const index = Math.round(course / 45);
  return dirs[index];
};

if (!$location.isAvailable()) {
  $render(
    <vstack frame="max" padding="12" background="#0f172a">
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
    <vstack frame="max" padding="12" background="#0f172a">
      <text font="title3" color="#fbbf24">Permission Needed</text>
      <text font="caption" color="#94a3b8">Enable Location access in the app.</text>
    </vstack>
  );
  return;
}

const location = await $location.current();
const course = location.course;
const speed = location.speed;

$render(
  <vstack frame="max" padding="12" background="#111827" spacing="6">
    <text font="caption" color="#94a3b8">Compass</text>
    <text font="title2" color="#e2e8f0">{directionFromCourse(course)}</text>
    <text font="caption" color="#94a3b8">Course: {course >= 0 ? Math.round(course) + " deg" : "-"}</text>
    <text font="caption" color="#94a3b8">Speed: {speed >= 0 ? speed.toFixed(1) + " m/s" : "-"}</text>
  </vstack>
);
