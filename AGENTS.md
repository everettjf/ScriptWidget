# AGENTS

## Project Snapshot
- ScriptWidget ships a SwiftUI-based iOS/iPadOS/macOS app, a WidgetKit extension (with Live Activities & Dynamic Island views), and a JavaScript runtime shared through `Shared/ScriptWidgetRuntime`.
- End users author widgets in JavaScript/JSX; the runtime transpiles them through an embedded Babel preset and renders SwiftUI components on-device.
- A lightweight React (Create React App) front-end (`Editor/editorfe`) is used as the external script editor previewer.

## Architecture Highlights
- **Runtime**: `ScriptWidgetRuntime` (Swift) wraps JavaScriptCore, injects helper APIs (`$render`, `$error`, fetch/file helpers, etc.), and marshals JSX to SwiftUI elements.
- **Data & Storage**: `ScriptManager` persists script packages under `Scripts/` (preferring iCloud container `iCloud.ScriptWidget`, falling back to the shared app group). Build artifacts live in `__Build`.
- **Targets**:
  - `iOS/ScriptWidget`: Main app with script explorer/editor, script import/export, photo picker, and settings.
  - `iOS/ScriptWidgetWidget`: WidgetKit/Life Activity extension consuming the shared runtime.
  - `iOS/ScriptWidgetShare`: Share extension for ingesting scripts from other apps.
  - `macOS/ScriptWidgetMac` (+ widget target) reuse the same runtime for desktop.
- **Editor**: React 17 + CodeMirror 6 frontend for writing scripts; output is bundled into the native apps.

## Repository Map
- `Shared/ScriptWidgetRuntime`: Common runtime (Widget rendering, JS API surface, AppIntent glue, resources).
- `iOS/ScriptWidget*`: iOS app, widget, and share targets (SwiftUI views under `View/`, managers under `Manager/`, localized content inside `Localizations/`).
- `macOS/ScriptWidgetMac*`: macOS app + widget specific sources.
- `Editor/editorfe`: CRA project for the script editor UI; ships CodeMirror-based editing experience.
- `Resource`: Marketing assets and store screenshots/icons.

## Build & Run
1. **iOS / Widget / Share extension**
   - Open `iOS/ScriptWidget.xcodeproj` in Xcode 14+.
   - Select the `ScriptWidget` scheme for the app, `ScriptWidgetWidget` for widgets/live activities, or `ScriptWidgetShare` for the share extension.
   - Enable the `iCloud.ScriptWidget` container & the `group.everettjf.scriptwidget` app group in Signing & Capabilities, or switch storage to sandbox-only by adjusting `ScriptManager`.
2. **macOS app / widget**
   - Open `macOS/ScriptWidgetMac.xcodeproj`.
   - Schemes mirror the iOS naming; mac targets also rely on resources in `Shared/ScriptWidgetRuntime`.
3. **React editor**
   - `cd Editor/editorfe && npm install`.
   - `npm start` for local preview at `http://localhost:3000`.
   - `npm run build` outputs static assets to `build/` which can be embedded or published.

## Tooling & Libraries
- SwiftUI, Combine, WidgetKit, ActivityKit.
- JavaScriptCore + embedded Babel transform (`Shared/.../Runtime/support/core.js`).
- ZipArchive for packaging scripts/import/export.
- React 17, CodeMirror 6 (`@uiw/react-codemirror`) for the web editor.

## Operational Notes
- Runtime expects user scripts under `Scripts/<PackageName>` with `main.jsx`; Asset folders accompany packages.
- `ScriptManager.moveSandboxFilesToICloud()` migrates documents from the shared app group into iCloud once available; keep user-visible copy prompts in mind when changing storage flows.
- Dynamic Island definitions rely on `$dynamic_island` helpers inside `ScriptWidgetRuntime`; verify Pro/ProMax behavior when touching runtime layout logic.
- Marketing assets live under `Resource/`; App Store metadata (screenshots/icons) are manually curated.

## Optimization Backlog
| Item | Status | Notes |
| --- | --- | --- |
| Documentation refresh (root README, AGENTS) | ✅ Done | Added high-level overview + contributor guidance. |
| Developer onboarding guide (per-target checklists, screenshots) | ⏳ | Extend README with target-specific screenshots & debugging caveats. |
| Shared runtime unit tests | ⏳ | Wrap `ScriptWidgetRuntime` transforms in XCTest to cover JSX -> SwiftUI conversion and error reporting. |
| React editor modernization | ⏳ | Upgrade to React 18 + Vite (or CRA 5+ alternatives), adopt TypeScript definitions for runtime APIs, add prettier/eslint config. |
| Continuous Integration | ⏳ | Automate `xcodebuild` (iOS + macOS) and `npm test` via GitHub Actions, surface lint/test badges. |
| Distribution pipeline | ⏳ | Script `fastlane` or `xcodebuild` archive steps for easier App Store Connect uploads. |

## Verification Checklist
- When touching runtime or storage, run the iOS/macOS app + widget schemes to confirm scripts render, Live Activity/Dynamic Island surfaces update, and iCloud migrations succeed.
- For editor changes, lint (`npm run test`) and smoke-test save/export flows.
- Before releases, build both iOS and macOS targets, regenerate marketing assets if UI changed, and verify bundle IDs/capabilities.
