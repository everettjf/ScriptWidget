# ScriptWidget 27.1.2 store creatives

Light, friendly direction selected by the owner. The artwork uses the app icon,
real native widget captures, Space Grotesk headings and Inter supporting copy.

- `header-en.png`: 3840 × 1646, RGB PNG, product-page header.
- `search-results-en.png`: 3840 × 2560, RGB PNG, search-results creative.
- `sources/`: native iOS renders and the existing app icon. Widget content is
  scaled uniformly and receives rounded corners and a subtle contact shadow;
  no UI content is generated or redrawn.
- `generate.py`: local composition recipe. No credentials or remote UI capture.

The source skill is [store-screenshots](https://github.com/iamaz007/store-and-web-screenshots-claude-skill).
Install it using Codex's skill installer, then run `generate.py` with Python,
Pillow and numpy. Use `--skill-dir PATH` for a non-default skill installation.
The skill downloads the two fonts from the official Google Fonts repository.
Menlo, used for the illustrative JSX snippet, is supplied by macOS.

Native capture recipe (after building the test target):

```sh
TEST_RUNNER_SCRIPTWIDGET_EXPORT_SNAPSHOTS=1 \
TEST_RUNNER_SCRIPTWIDGET_EXPORT_FILTER=template/ \
TEST_RUNNER_SCRIPTWIDGET_EXPORT_SCALE=4 \
xcodebuild -quiet -project iOS/ScriptWidget.xcodeproj \
  -scheme ScriptWidgetRuntimeTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/scriptwidget-release-readiness/ios-tests \
  -only-testing:ScriptWidgetRuntimeTests/BrowserPreviewParityTests/testExportNativeSnapshots \
  test-without-building
```

Copy Month Calendar (small), Weather Glance (small), and Habit Heatmap (medium)
from `Web/preview-engine/dist/native-snapshots/` into the corresponding source
files, then run `generate.py`. Snapshot time and fixture data are deterministic;
these captures contain no personal calendar or health information.

Apple specifications checked on 2026-10-20:
[Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)
and [asset best practices](https://developer.apple.com/app-store/asset-best-practices/).
