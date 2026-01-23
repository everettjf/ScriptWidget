//
// ScriptWidget
// https://xnu.app/scriptwidget
//
// Weather Now - Open-Meteo (no API key required)
// widget-param: "lat,lon" (optional)
//

let lat = 37.7749;
let lon = -122.4194;
const param = $getenv("widget-param");
if (param) {
  const parts = param.split(",").map((p) => p.trim());
  if (parts.length >= 2) {
    const latValue = parseFloat(parts[0]);
    const lonValue = parseFloat(parts[1]);
    if (!Number.isNaN(latValue) && !Number.isNaN(lonValue)) {
      lat = latValue;
      lon = lonValue;
    }
  }
}

const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,wind_speed_10m&timezone=auto`;
const result = await fetch(url);
const data = JSON.parse(result);

const current = data.current || {};
const units = data.current_units || {};

const weatherMap = {
  0: "Clear",
  1: "Mainly clear",
  2: "Partly cloudy",
  3: "Overcast",
  45: "Fog",
  48: "Fog",
  51: "Drizzle",
  61: "Rain",
  71: "Snow",
  80: "Showers",
  95: "Thunder"
};

const weatherText = weatherMap[current.weather_code] || "Unknown";
const temperature = current.temperature_2m ?? "-";
const wind = current.wind_speed_10m ?? "-";
const time = current.time ?? "";

$render(
  <vstack frame="max" background="#0ea5e9">
    <text font="caption" color="#e0f2fe">Weather Now</text>
    <text font="title2" color="white">{temperature}{units.temperature_2m || ""}</text>
    <text font="caption" color="#e0f2fe">{weatherText}</text>
    <text font="caption2" color="#bae6fd">Wind: {wind}{units.wind_speed_10m || ""}</text>
    <text font="caption2" color="#bae6fd">Updated: {time}</text>
  </vstack>
);
