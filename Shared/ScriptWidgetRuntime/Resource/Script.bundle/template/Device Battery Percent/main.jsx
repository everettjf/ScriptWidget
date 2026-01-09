//
// ScriptWidget 
// https://xnu.app/scriptwidget
// 
// Battery Percent Template
// 


var percent = $device.battery().level * 100;
percent = percent.toFixed(0);

let linearGradient = {
  type: "linear",
  colors: ["blue", "red", "green"],
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
    <text font="50">🔋{percent} % </text>
  </vstack>
);
