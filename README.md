# ScriptWidget

ScriptWidget is an innovative iOS app that allows you to create beautiful and dynamic widgets using JavaScript and JSX. It's the predecessor to JSWidget, offering powerful capabilities for iOS widget development.

![](https://scriptwidget.app/assets/images/screenshot-888432460db6bfcd7a207c15183adbc2.jpg)

## Features

- **JSX Style Coding**: Create widgets using familiar JSX syntax for intuitive and efficient development
- **JavaScript Powered**: Leverage the full power of JavaScript to build dynamic and interactive widgets
- **SwiftUI Integration**: Built on SwiftUI for high performance and native look and feel on iOS and iPadOS

## Download

- US App Store: [https://apps.apple.com/us/app/scriptwidget/id1555600758](https://apps.apple.com/us/app/scriptwidget/id1555600758)
- CN App Store: [https://apps.apple.com/cn/app/scriptwidget/id1555600758](https://apps.apple.com/cn/app/scriptwidget/id1555600758)

## Documentation

For detailed documentation and guides, visit: [https://scriptwidget.app/](https://scriptwidget.app/)

## Example Code

```javascript
const widget_size = $getenv("widget-size");
const widget_param = $getenv("widget-param");

const beijingDate = new Date().toLocaleString("zh-CN", { timeZone: "Asia/Shanghai" });
const sanJoseDate = new Date().toLocaleString("zh-CN", { timeZone: "America/Los_Angeles" });
const newYorkDate = new Date().toLocaleString("zh-CN", { timeZone: "America/New_York" });
const sydneyDate = new Date().toLocaleString("zh-CN", { timeZone: "Australia/Sydney" });

$render(
  <hstack frame="max">
    <vstack alignment="leading">
      <text font="title3" color="blue" font="custom,Unispaced">World Clock</text>
      <text font="title3" color="green" font="custom,Unispaced">Beijing: {beijingDate}</text>
      <text font="title3" color="orange" font="custom,Unispaced">San Jose: {sanJoseDate}</text>
      <text font="title3" color="secondary" font="custom,Unispaced">New York: {newYorkDate}</text>
      <text font="title3" color="purple" font="custom,Unispaced">Sydney: {sydneyDate}</text>
    </vstack>
  </hstack>
);
```

## License

This project is open source and available under the MIT License.

