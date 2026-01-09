# ScriptWidget

[![App Store](https://img.shields.io/badge/App%20Store-ScriptWidget-blue)](https://apps.apple.com/app/scriptwidget/id1555600758)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20iPadOS%20%7C%20macOS-lightgrey)](#architecture)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

SwiftUI-powered widget builder that lets anyone author widgets with JavaScript + JSX and run them directly on iOS, iPadOS, macOS, widgets, Live Activities, and Dynamic Island surfaces. ScriptWidget is the multi-platform predecessor to **JSWidget** and remains useful for contributors exploring or extending the original runtime.

> Docs, gallery, and FAQ live at [xnu.app/scriptwidget](https://xnu.app/scriptwidget/)

## Table of Contents
- [Highlights](#highlights)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Repository Layout](#repository-layout)
- [Writing Widgets](#writing-widgets)
- [Development Tips](#development-tips)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Community & Support](#community--support)
- [License](#license)

## Highlights
- **JavaScript + JSX workflow** – Build widgets with `$render(<stack>)` and Babel-transpiled JSX primitives that map directly to SwiftUI components.
- **Runtime helper APIs** – JavaScriptCore host injects `$fetch`, `$file`, `$location`, `$dynamic_island`, `$preferences`, and environment getters for widget size/parameters.
- **Multi-target** – One codebase powers the iOS/iPadOS app, WidgetKit extension (AppIntents, Live Activity, Dynamic Island surfaces), macOS app, and share extension.
- **Offline-first storage** – Scripts are stored under iCloud (`iCloud.ScriptWidget`) when available and fall back to the shared app group to keep data in sync.
- **Open editor workflow** – React + CodeMirror web editor mirrors the native experience for rapid iteration and previewing.

## Architecture
ScriptWidget is split across Swift and JavaScript targets while sharing the `ScriptWidgetRuntime` core.

| Area | Location | What it does |
| --- | --- | --- |
| iOS/iPadOS app | `iOS/ScriptWidget` | Script explorer/editor, gallery, import/export, photo picker, and settings. |
| Widget extension | `iOS/ScriptWidgetWidget` | WidgetKit timelines plus Live Activity + Dynamic Island views backed by the runtime. |
| Share extension | `iOS/ScriptWidgetShare` | Receives script bundles/assets from Safari, Files, and other apps. |
| macOS app + widget | `macOS/ScriptWidgetMac*` | Desktop shell that reuses the shared runtime/resources. |
| Shared runtime | `Shared/ScriptWidgetRuntime` | JavaScriptCore host, Babel preset, SwiftUI renderer, AppIntent glue, storage helpers. |
| Web editor | `Editor/editorfe` | Create React App + CodeMirror 6 frontend for writing scripts. |
| Assets | `Resource/` | App Store marketing artwork, screenshots, and promo material. |

## Quick Start
### Prerequisites
- Xcode 14+ with SwiftUI, WidgetKit, ActivityKit, and the `iCloud.ScriptWidget` container enabled.
- Node.js 16+ / npm for the React editor.
- No CocoaPods required — dependencies are vendored via Swift Package Manager.

### Clone the repository
```bash
git clone https://github.com/everettjf/ScriptWidget.git
cd ScriptWidget
```

### iOS app, widgets, and share extension
1. Open `iOS/ScriptWidget.xcodeproj` in Xcode.
2. Choose one of the schemes:
   - `ScriptWidget` – main app
   - `ScriptWidgetWidget` – widget extension + Live Activities
   - `ScriptWidgetShare` – share extension
3. Enable the `iCloud.ScriptWidget` container and the `group.everettjf.scriptwidget` app group so script storage works on-device.

### macOS app + widget
1. Open `macOS/ScriptWidgetMac.xcodeproj`.
2. Select `ScriptWidgetMac` (app) or `ScriptWidgetMacWidget` (widget) scheme and build/run.
3. macOS targets reuse `Shared/ScriptWidgetRuntime`, so changes here automatically benefit every platform.

### React editor frontend
```bash
cd Editor/editorfe
npm install
npm start        # Local dev server at http://localhost:3000
npm run build    # Optional production build for embedding/distribution
```

## Repository Layout
```
Shared/ScriptWidgetRuntime/   # JavaScriptCore host, JSX renderer, runtime APIs
iOS/ScriptWidget*             # App, widget, and share extensions for iOS/iPadOS
macOS/ScriptWidgetMac*        # macOS app + widget sources
Editor/editorfe/              # React + CodeMirror editor frontend
Resource/                     # Screenshots, marketing assets, icons
Scripts/                      # (runtime) user-created widget packages, synced via iCloud/app group
```

## Writing Widgets
Use `$render` with JSX components inside `Scripts/<PackageName>/main.jsx` packages. Runtime helpers such as `$getenv("widget-size")`, `$getenv("widget-param")`, `$preferences`, `$file`, `$fetch`, `$location`, and `$dynamic_island` are injected automatically.

```javascript
const widgetSize = $getenv("widget-size");
const widgetParam = $getenv("widget-param");

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

## Development Tips
- Keep user scripts under `Scripts/<PackageName>`; `ScriptManager` migrates them to `iCloud.ScriptWidget` via `moveSandboxFilesToICloud()` once the container is available.
- Touching runtime or storage logic? Run the iOS/macOS app + widget schemes to confirm scripts render, Live Activity/Dynamic Island surfaces update, and migrations succeed.
- For editor changes, run `npm test` inside `Editor/editorfe`, smoke-test save/export, and rebuild before shipping.
- Marketing assets live under `Resource/`; refresh screenshots/icons if user-facing UI changes.

## Contributing
We welcome issues and pull requests! Before landing breaking runtime changes, please open an issue so we can discuss migration plans. Helpful areas right now:
- ScriptWidgetRuntime unit tests that cover JSX ➜ SwiftUI conversion and error reporting.
- React editor modernization (React 18, Vite/Vitest, TypeScript typings for runtime APIs).
- Documentation refreshes (per-target onboarding, localization, screenshots) and CI automation for `xcodebuild` + `npm test`.

When submitting PRs:
1. Reference the GitHub issue (or open one) describing the problem.
2. Include repro steps or screenshots where applicable.
3. Verify builds/tests for the targets you touched (see [Development Tips](#development-tips)).

## Roadmap
| Item | Status | Notes |
| --- | --- | --- |
| Documentation refresh (README, AGENTS) | ✅ Done | High-level overview + contributor guidance landed.
| AI-generated Widget Builder | ⏳ Planned | Prompt-based assistant that writes starter widget scripts automatically.
| AI-generated Widget Template Library | ⏳ Planned | Auto-generate ready-to-use widget variations for each size and style.
| AI-generated Widget Guardrails | ⏳ Planned | Sandboxing + linting to keep AI-authored scripts safe to run.
| AI-generated Widget Editor Integration | ⏳ Planned | Surface AI suggestions directly inside the React editor for instant inserts.
| AI-generated Widget Distribution Pipeline | ⏳ Planned | Publish AI-generated widgets to a shared catalog with one-click import.

## Star History
[![Star History Chart](https://api.star-history.com/svg?repos=everettjf/ScriptWidget&type=Date)](https://star-history.com/#everettjf/ScriptWidget&Date)

## Community & Support
- App Store: [ScriptWidget](https://apps.apple.com/app/scriptwidget/id1555600758)
- Docs, gallery, FAQ: [xnu.app/scriptwidget](https://xnu.app/scriptwidget/)
- Issues & discussions: GitHub Issues/Discussions on this repository

## License

MIT License – see [LICENSE](LICENSE).
