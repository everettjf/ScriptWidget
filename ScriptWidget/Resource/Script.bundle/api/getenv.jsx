// 
// ScriptWidget 
// https://scriptwidget.app
// 
// Usage for component $getenv
// 

/*
 widget-size
 - large
 - medium
 - small
*/
const widget_size = $getenv("widget-size");


$render(
  <vstack frame="max">
    <text font="title">Widget Size : {widget_size}</text>
  </vstack>
);
