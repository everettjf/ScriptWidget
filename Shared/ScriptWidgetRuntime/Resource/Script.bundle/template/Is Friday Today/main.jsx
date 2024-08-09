// 
// ScriptWidget 
// https://scriptwidget.app
// 
// Is Friday Today Template
// 
// Description: Is today friday ?
// 

var d = new Date();
var n = d.getDay();
console.log(n);

let linearGradient = {
  type: "linear",
  colors: ["yellow", "white"],
  startPoint: "top",
  endPoint: "bottom",
};


$render(
  <vstack
    background={$gradient(linearGradient)}
    frame="max,leading"
    alignment="leading"
  >
    <hstack padding="10">
      <vstack alignment="leading">
        <text font="body" color="black">
          {d.getFullYear()}-{d.getMonth() + 1}-{d.getDate()}
        </text>
        <text font="body" color="black">
          Is Friday today ?
        </text>
      </vstack>
      <spacer />
    </hstack>
    <spacer />
    <text font="largeTitle" color="black" padding="10">
      {n == 5 ? "Yes😊" : "No🤔"}
    </text>
  </vstack>
);
