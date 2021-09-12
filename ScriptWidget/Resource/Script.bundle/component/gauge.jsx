// 
// ScriptWidget 
// https://scriptwidget.app
// 
// Usage for component guage
// 

let gaugeSections = [
  {color: "yellow", value: 0.1},
  {color: "blue", value: 0.2},
  {color: "orange", value: 0.3},
  {color: "green", value: 0.4},
];

$render(
  <vstack frame="max">
    <gauge 
      angle="260" 
      value="0.6" 
      thickness="10" 
      needleColor="black" 
      label="60%" labelFont="caption"
      title="Battery" titleFont="caption"
      sections={$json(gaugeSections)}
      >
    </gauge>
  </vstack>
);
