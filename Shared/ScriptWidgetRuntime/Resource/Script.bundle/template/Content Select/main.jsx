// 
// ScriptWidget 
// https://xnu.app/jswidget
// 
// Content Select Template
// 
// Description: Choose content at runtime
// 

var text = "Hello ScriptWidget :)";

var a = (
    <text>a text</text>
)

var b = (
    <text>b text</text>
)

var c = Math.random() * 10 % 10 > 5 ? a : b;


const widget_size = $getenv("widget-size");

$render(
  <vstack>
    <text font="title">{text}</text>
    {c}
    <text font="caption">Widget Size : {widget_size}</text>
  </vstack>
);
