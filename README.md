# ScriptWidget

SwiftUI-powered widget builder that lets you author widgets with JavaScript + JSX and run them directly on iOS, iPadOS, macOS, widgets, Live Activities, and Dynamic Island surfaces. ScriptWidget is the multi-platform predecessor to **JSWidget** and remains useful for contributors who want to explore or extend the original runtime.

> App Store: [ScriptWidget](https://apps.apple.com/app/scriptwidget/id1555600758) · Docs & gallery: [xnu.app/scriptwidget](https://xnu.app/scriptwidget/)

## Why ScriptWidget
- **JSX workflow** – Write widgets with `$render(<stack>)` using JSX primitives that map to SwiftUI components.
- **JavaScriptCore runtime** – Built-in Babel preset + helper APIs (`$fetch`, `$file`, `$dynamic_island`, etc.) to create rich widgets.
- **Multi-target** – One codebase powers the app, WidgetKit extension (with AppIntents, Live Activity, Dynamic Island), macOS app, and a share extension.
- **Offline-first** – Scripts stored under iCloud (`iCloud.ScriptWidget`) or the shared app group to keep widgets synced across devices.

## Components at a Glance
| Component | Location | Notes |
| --- | --- | --- |
| iOS/iPadOS app | `iOS/ScriptWidget` | Script manager/editor, gallery, settings, import/export. |
| Widget extension | `iOS/ScriptWidgetWidget` | WidgetKit timelines, Live Activity, Dynamic Island views backed by `Shared/ScriptWidgetRuntime`. |
| Share extension | `iOS/ScriptWidgetShare` | Receive scripts/assets from Safari, Files, etc. |
| macOS app + widget | `macOS/ScriptWidgetMac*` | Desktop shell, shares runtime/resources with iOS. |
| Shared runtime | `Shared/ScriptWidgetRuntime` | JavaScriptCore host, Babel transform, SwiftUI renderer, storage helpers. |
| Web editor | `Editor/editorfe` | Create React App + CodeMirror 6 editor for authoring scripts. |
| Assets | `Resource/` | App Store/media artwork and screenshots. |

## Getting Started
### Prerequisites
- Xcode 14+ with SwiftUI, WidgetKit, ActivityKit, and the `iCloud.ScriptWidget` container enabled.
- Node.js 16+ / npm for the React editor (Create React App).
- CocoaPods is **not** required; dependencies are vendored via Swift Package Manager targets in the projects.

### Clone the repository
```bash
git clone https://github.com/everettjf/ScriptWidget.git
cd ScriptWidget
```

### Run the iOS app and widgets
1. Open `iOS/ScriptWidget.xcodeproj` in Xcode.
2. Choose the `ScriptWidget` scheme to run the app, `ScriptWidgetWidget` for widgets/Live Activities, or `ScriptWidgetShare` for the share extension.
3. Ensure the `iCloud.ScriptWidget` container and `group.everettjf.scriptwidget` application group are enabled so script storage works on-device.

### Run the macOS app
1. Open `macOS/ScriptWidgetMac.xcodeproj`.
2. Select `ScriptWidgetMac` (app) or `ScriptWidgetMacWidget` (widget) schemes and build.
3. The macOS targets reuse the code from `Shared/ScriptWidgetRuntime`.

### Run the editor frontend
```bash
cd Editor/editorfe
npm install
npm start    # http://localhost:3000
npm run build  # optional production build
```

## Writing Widgets
Use `$render` with JSX components inside your `.jsx` or `.js` script packages. Environment helpers such as `$getenv("widget-size")`, `$getenv("widget-param")`, `$preferences`, `$file`, `$fetch`, `$location`, and `$dynamic_island` are injected by the runtime.

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

## Additional Resources
- Script gallery, API docs, FAQ: [xnu.app/scriptwidget](https://xnu.app/scriptwidget/)
- Marketing assets & screenshots: `Resource/`
- Issues & feature planning: GitHub Issues / Discussions

## Contributing & Next Steps
- Please open an issue before landing breaking runtime changes.
- Helpful areas for contribution include: runtime unit tests, React editor modernization, documentation/localization improvements, and CI automation for iOS/macOS builds.

## License

MIT License – see [LICENSE](LICENSE).
