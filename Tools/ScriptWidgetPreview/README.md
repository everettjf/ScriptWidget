# ScriptWidget Preview

A small macOS developer app that renders the same widget package two ways
and shows them side by side:

- **macOS native**: the shared `ScriptWidgetRuntime` (JavaScriptCore +
  SwiftUI), composed like the macOS widget's root view and captured with
  `ImageRenderer` at 2x.
- **Web engine**: `Web/preview-engine` running in a `WKWebView` with the
  `macos` device profile, served from `127.0.0.1` by the app.

The third pane shows the pixel difference (a pixel differs when any channel
moves by more than 48 of 255, the same rule as `npm run compare`).

## Build and run

```bash
cd Tools/ScriptWidgetPreview && xcodegen generate
```

```bash
(cd Web/preview-engine && npm run build)
```

```bash
xcodebuild -project Tools/ScriptWidgetPreview/ScriptWidgetPreview.xcodeproj -scheme ScriptWidgetPreview build
```

The project is generated from `project.yml` and compiles the same shared
runtime sources as the macOS widget extension. The app finds the repository
from its source location; set `SCRIPTWIDGET_REPO` to use another checkout.

The sidebar lists the comparison corpus (bundled `api`, `component`, and
`template` packages, Gallery widgets, `Web/preview-engine/test/render/cases.json`,
and the component catalog `Web/preview-engine/test/catalog/catalog.json`).
**File › Open Package Folder…** compares any package directory. Launch with
`--select <id>` (for example `--select "template/Plant Care"`) to open an entry.

The web engine has no network. When a script's GET request has no fixture,
the app downloads that URL once and renders again with the response as a
fixture, so both sides show the same data. Other methods (POST, PUT, …) are
not replayed, so packages that depend on them show the web error.

## Batch comparison

```bash
"ScriptWidget Preview.app/Contents/MacOS/ScriptWidget Preview" --batch /tmp/compare
```

Options: `--filter <prefix>` (for example `case/`) and
`--families small,medium,large`. Packages that read `$location`, `$health`,
or `$dataSource` are skipped; network packages are compared as above. The output
directory receives `native/`, `web/`, and `diff/` PNGs and `report.json`.

## SF Symbol metrics

`Scripts/symbol-metrics.swift` measures every SF Symbol the web engine maps
to a look-alike icon, their `.fill` variants, and every symbol name that
appears as a string in the bundled scripts, Gallery, and test sources, and
regenerates
`Web/preview-engine/src/render/symbolMetrics.generated.js`:

```bash
swiftc -parse-as-library -o /tmp/symbol-metrics Tools/ScriptWidgetPreview/Scripts/symbol-metrics.swift
```

```bash
/tmp/symbol-metrics "$PWD"
```

## Line breaking reference

`Scripts/line-break-sweep.swift` compares the web engine's push-out rule
with TextKit's `.standard` line break strategy across texts, sizes, weights,
and widths and prints the number of mismatches.

## Notes

- The app is a local developer tool: ad-hoc signed, not sandboxed, and not
  shipped. Its server binds to `127.0.0.1` only and serves read-only files
  from `Web/preview-engine` and the runtime support bundle.
- Native clock-hand animations are not captured by `ImageRenderer`, and
  templates that show the current time differ by when each side rendered.
