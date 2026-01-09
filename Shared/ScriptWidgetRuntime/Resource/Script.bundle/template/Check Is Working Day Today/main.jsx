// 
// ScriptWidget 
// https://xnu.app/scriptwidget
// 

var d = new Date();
var n = d.getDay();
console.log(n);

let linearGradient = {
  type: "linear",
  colors: ["yellow", "red"],
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
          Is Working Day Today ?
        </text>
      </vstack>
      <spacer />
    </hstack>
    <spacer />
    <hstack alignment="center">
        <text font="largeTitle" color="black" padding="10">
        {(n >= 1 && n <= 5) ? "Yes⛽️⛽️⛽️" : "No😄"}
        </text>
    </hstack>    
  </vstack>
);
