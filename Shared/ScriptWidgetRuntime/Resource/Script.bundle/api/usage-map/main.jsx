// ScriptWidget 
// https://xnu.app/jswidget
// 
// Mapping over an array
// Thanks for Reina for telling me this good idea
// 

const values = ["one", "two", "three", "four"];

const test = values.map((value) => { 
  return(<text>{value}</text>)
})

$render(
  <vstack>
    <text font="title">test</text>
    {test}
  </vstack>
);
