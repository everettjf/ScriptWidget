// 
// ScriptWidget 
// https://scriptwidget.app
// 
// Battery Percent Template
// 
// Description: Display system battery percentage
// 

var percent = $device.battery().level * 100;
percent = percent.toFixed(0);

let linearGradient = {
  type: "linear",
  colors: ["blue", "white", "pink"],
  startPoint: "topLeading",
  endPoint: "bottomTrailing",
};

let radialGradient = {
  type: "radial",
  colors: ["orange", "red", "white"],
  center: "center",
  startRadius: 100,
  endRadius: 470,
};

let angularGradient = {
  type: "angular",
  colors: ["green", "blue", "black", "green", "blue", "black", "green"],
  center: "center",
};

$render(
  <vstack background={$gradient(linearGradient)} frame="max">
    <text font="title">🔋{percent} % </text>
  </vstack>
);
