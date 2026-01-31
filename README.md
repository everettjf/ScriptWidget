# ScriptWidget 🎨

<div align="center">

[![GitHub Stars](https://img.shields.io/github/stars/everettjf/ScriptWidget?style=flat-square&color=4ECDC4)](https://github.com/everettjf/ScriptWidget/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/everettjf/ScriptWidget?style=flat-square)](https://github.com/everettjf/ScriptWidget/network)
[![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-lightgrey?style=flat-square&logo=apple)](https://developer.apple.com)
[![Version](https://img.shields.io/badge/Version-3.0-blue?style=flat-square)](https://github.com/everettjf/ScriptWidget/releases)

**Create native widgets for iOS & macOS using JavaScript and JSX**

[English](README.md) | [中文](README_CN.md)

</div>

> ✨ *Build iOS/macOS widgets without Swift. Just JavaScript, JSX, and creativity.*

---

## 🎯 What is ScriptWidget?

ScriptWidget is a powerful widget development platform that lets you create native iOS and macOS widgets using **JavaScript** and **JSX-like syntax**. No Swift required!

Think of it as "React Native for Widgets" - but simpler and more flexible.

![ScriptWidget Demo](screenshot.png)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🖥️ **Cross-Platform** | One codebase for iOS and macOS widgets |
| 🎨 **JSX Support** | Declarative UI with JavaScript XML syntax |
| ⚡ **Native Performance** | Compiled to native Swift/SwiftUI |
| 🔧 **Rich APIs** | Access device sensors, data sources, and more |
| 📱 **Interactive Widgets** | Tap, swipe, and interact with widgets |
| 🎨 **Custom Styling** | Full control over appearance |
| 📦 **Template Gallery** | Pre-built templates to get started |
| 🔄 **Live Preview** | See changes instantly in Xcode |

---

## 🚀 Quick Start

### 1. Download

```bash
# Clone the repository
git clone https://github.com/everettjf/ScriptWidget.git
cd ScriptWidget
```

### 2. Open in Xcode

```bash
open ScriptWidget/ScriptWidget.xcodeproj
```

### 3. Run & Explore

1. Select your target (iOS Simulator or macOS)
2. Press `Cmd + R` to build and run
3. Explore the example widgets in `Examples/`

---

## 📁 Project Structure

```
ScriptWidget/
├── ScriptWidget/          # Main app source
│   ├── App/               # App entry point
│   ├── Script/            # JavaScript runtime
│   ├── Views/             # SwiftUI views
│   └── Resources/         # Assets and templates
├── Examples/              # Example widgets
│   ├── HelloWorld/        # Simple widget
│   ├── Weather/           # Weather widget
│   ├── Calendar/          # Calendar widget
│   └── ...                # More examples
├── Templates/             # Widget templates
├── Docs/                  # Documentation
└── README.md
```

---

## 💻 Example Widgets

### Hello World

```javascript
// A simple widget
function render() {
  return (
    <widget type="medium">
      <text style={{ fontSize: 24, color: '#333' }}>
        Hello, ScriptWidget! 👋
      </text>
    </widget>
  );
}
```

### Weather Widget

```javascript
function WeatherWidget({ location }) {
  const [weather] = useWeather(location);
  
  return (
    <widget type="large">
      <view style={{ padding: 16 }}>
        <text style={{ fontSize: 32 }}>
          {weather.temperature}°C
        </text>
        <text style={{ fontSize: 16 }}>
          {weather.condition}
        </text>
      </view>
    </widget>
  );
}
```

### Todo List

```javascript
function TodoList({ todos }) {
  return (
    <widget type="medium">
      <list data={todos} render={(item) => (
        <row>
          <checkbox checked={item.done} />
          <text>{item.title}</text>
        </row>
      )} />
    </widget>
  );
}
```

---

## 🛠️ Development

### Prerequisites

- **Xcode** 14+ (for iOS 16+ / macOS 13+)
- **macOS** 13+ (Ventura or later)
- **iOS** 16+ (for iOS widgets)

### Build from Source

```bash
# Clone and setup
git clone https://github.com/everettjf/ScriptWidget.git
cd ScriptWidget

# Open in Xcode
open ScriptWidget/ScriptWidget.xcodeproj

# Build and run (Cmd + R)
```

### Create Your Own Widget

```bash
# 1. Duplicate an example
cp -r Examples/HelloWorld Examples/MyWidget

# 2. Edit the JavaScript file
cd Examples/MyWidget
vim script.js  # Write your widget code

# 3. Run and preview in the app
```

---

## 📚 Documentation

### Core Concepts

- **Widget Types** - small, medium, large, accessory
- **Components** - text, image, list, grid, etc.
- **Styling** - CSS-like inline styles
- **Data Sources** - weather, calendar, reminders, etc.
- **Interactions** - tap, swipe, long press

### APIs

| API | Description |
|-----|-------------|
| `useWeather()` | Get weather data |
| `useCalendar()` | Access calendar events |
| `useReminders()` | Fetch reminder lists |
| `useLocation()` | Get device location |
| `useHealth()` | HealthKit data |
| `useNetwork()` | Network requests |

---

## 🎨 Gallery

<div align="center">

![Widget Gallery](gallery.png)

*Sample widgets created with ScriptWidget*

</div>

---

## 📱 Platforms

| Platform | Support | Notes |
|----------|---------|-------|
| **iOS** | ✅ Full | iOS 16+ (iPhone, iPad) |
| **macOS** | ✅ Full | macOS 13+ (Mac) |
| **watchOS** | 🔄 Planned | Future release |
| **visionOS** | 🔄 Planned | Future release |

---

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

### Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest features
- 🔧 Submit pull requests
- 📝 Write documentation
- 🎨 Share your widgets

---

## 📜 License

ScriptWidget is released under the [MIT License](LICENSE).

---

## 🙏 Acknowledgements

Built with:
- [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) - Apple's JavaScript engine
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Modern UI framework
- [Xcode Gen](https://github.com/yonaskolb/XcodeGen) - Project generation

Inspired by:
- [React](https://reactjs.org/) - Component-based UI
- [React Native](https://reactnative.dev/) - Mobile development
- [WidgetKit](https://developer.apple.com/documentation/widgetkit) - Apple's widget framework

---

## 📈 Star History

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=everettjf/ScriptWidget&type=Date&theme=dark)](https://star-history.com/#everettjf/ScriptWidget&Date)

</div>

---

## 📞 Support

<div align="center">

[![GitHub Issues](https://img.shields.io/badge/Issues-Bug_Reports-FF6B6B?style=for-the-badge&logo=github)](https://github.com/everettjf/ScriptWidget/issues)
[![GitHub Discussions](https://img.shields.io/badge/Discussions-Q&A-4ECDC4?style=for-the-badge&logo=github)](https://github.com/everettjf/ScriptWidget/discussions)
[![Discord](https://img.shields.io/badge/Discord-Join_Chat-7289DA?style=for-the-badge&logo=discord)](https://discord.gg/scriptwidget)

**有问题？去 [Issues](https://github.com/everettjf/ScriptWidget/issues) 提问！**

</div>

---

<div align="center">

**Made with ❤️ by [Everett](https://github.com/everettjf)**

**Project Link:** [https://github.com/everettjf/ScriptWidget](https://github.com/everettjf/ScriptWidget)

</div>
