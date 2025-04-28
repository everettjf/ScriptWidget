// 
// ScriptWidget 
// https://xnu.app/jswidget
// 
// Weather Template
// 
// Description: Display weather today
// 

// https://www.weatherapi.com/
// please register account for your api key
const apikey = "8883e2c78d854356bc813207212502";
const city = "Beijing";
const url = `https://api.weatherapi.com/v1/current.json?key=${apikey}&q=${city}&aqi=no`;

const result = await fetch(url);
console.log(result);
const data = JSON.parse(result);

$render(
  <vstack frame="max" background="#3a86ff">
    <text font="title3" color="white">
      Weather
    </text>
    <text font="caption" color="white">
      City: {data.location.name}
    </text>
    <text font="caption" color="white">
      Temp: {data.current.temp_c} - {data.current.temp_f}
    </text>
    <text font="caption" color="white">
      Condition: {data.current.condition.text}
    </text>
    <text font="caption2" color="white">
      Updated At: {data.current.last_updated}
    </text>
  </vstack>
);
