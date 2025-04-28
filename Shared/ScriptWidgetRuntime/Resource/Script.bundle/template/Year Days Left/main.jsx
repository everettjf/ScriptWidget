// 
// ScriptWidget 
// https://xnu.app/jswidget
// 
// Year Days Left Template
// 
// Description: Show you how many days left this year
// 

var today = new Date();
var lastDay = new Date(today.getFullYear(), 12, 31);
var perDay = 1000 * 60 * 60 * 24;
var leftDays = Math.ceil((lastDay.getTime() - today.getTime()) / perDay);

$render(
  <vstack background="red" frame="max">
    <text font="title3" color="white">
      今年还剩
    </text>
    <text font="title" color="white">
      {leftDays} 天
    </text>
  </vstack>
);
