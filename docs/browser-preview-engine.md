# Browser preview engine

Status: all stages of the [research plan](browser-widget-preview-research.md)
are implemented as of 2026-10-17: the JavaScriptCore-compatible engine
(Stage 0), the SwiftUI-calibrated renderer (Stage 1), the
[Web Studio](web-studio-browser.md) website (Stage 2), the preview CLI and MCP
server (Stage 3), and broader parity for icons, gauges, charts, grids, dates,
animations, Lock Screen and iPad families, and rendering modes (Stage 4). This
page records what was built, what was measured, and the known differences.

The engine lives in [`Web/preview-engine`](../Web/preview-engine); the website
lives in [`Web/studio`](../Web/studio).

## Decisions

- **Product shape:** a public website on GitHub Pages. Users design and
  preview in the browser, then install the package on iPhone.
- **Promise:** the browser exposes the standard global `Promise` and emits a
  `compat.promise` warning when a script names `Promise`. The native shim is
  left unchanged for now; none of the 151 bundled `.jsx` files construct a
  `Promise` or call `.catch`, `.finally`, or `Promise.all`. `fetch`, `$http`,
  `$health`, and `$location` still return the native then-only object, so
  `fetch(url).catch(...)` fails in the browser exactly as it does on iPhone.
- **Icons:** 283 SF Symbol names map to 252 look-alike [Lucide](https://lucide.dev)
  icons (ISC license, generated subset with the license in
  `src/render/icons.generated.js`). Unmapped names show a placeholder and an
  `icon.unmapped` warning. No Apple symbol artwork is distributed.
- **Install flow:** the website exports a validated `.swt`. On iPhone, the Web
  Share sheet hands it to the existing ScriptWidget share extension; elsewhere
  the file is downloaded and sent with AirDrop, iCloud Drive, or email.
- **Hosting:** GitHub Pages serves the Studio at `/studio/` next to the
  existing `site/`; the workflow builds it from source on every relevant push
  to `main`.
- **Font weight properties:** `fontWeight`, `fontDesign`, and the older
  `weight` were documented but ignored natively; the native font modifier now
  applies them (see below).
- **Tree JSON:** the canonical serialization is a test artifact
  (`BrowserPreviewParityTests.swift` and `kernel.js`), not part of the runtime
  contract.

## Architecture

```text
Studio page (GitHub Pages, CSP script-src 'self')
  └─ <iframe sandbox="allow-scripts" src="sandbox.html">  opaque origin, own CSP, connect-src 'none'
       ├─ compiler Worker (blob:)               bundled Babel, prepares the package
       └─ executor Worker (blob:), one per run  kernel + user code, terminated at the deadline
```

Pages without a CSP (the demo and the CLI's render page) may pass the same
document as `srcdoc`. A `srcdoc` frame inherits the parent's policy, so the
Studio loads `sandbox.html` by URL to keep its own policy strict.

| File | Role |
| --- | --- |
| `src/kernel.js` | Self-contained execution kernel evaluated inside the user realm. Mirrors `internalExecuteJavaScriptForWidget`, `resolveWidgetElementTree`, `validateElementTree`, host APIs, and the JavaScriptCore bridge. |
| `src/contract.js` | Limits, API version, compiler fingerprint, error categories, `$main` wrapper. `test/contract.test.js` checks them against the Swift sources. |
| `src/compiler.js`, `src/prepare.js` | Babel wrapper. The entry is wrapped in `$main`; every script file is precompiled unwrapped so `$import` stays synchronous and Babel never enters the user realm. |
| `src/node.js`, `src/nodeWorker.js` | Node host for tests and the future CLI: one `worker_threads` Worker per run, user code in a fresh `vm` context. Not a security boundary. |
| `src/browser/*` | Browser host: sandboxed frame, compiler and executor Workers, parent-page client. |
| `scripts/build-browser.mjs` | Generates `dist/sandbox-sources.js`, copies the support scripts, and writes the browser parity corpus. |

Run `npm test` in `Web/preview-engine`. For the browser check, run
`node scripts/build-browser.mjs`, serve `Web/preview-engine` (the
`preview-engine` entry in `.claude/launch.json`), and open `/demo/`.

## Native semantics reproduced

These were measured against JavaScriptCore on macOS 27, not inferred:

| Input crossing `$element.createElement` | Native result |
| --- | --- |
| `undefined` prop | key dropped |
| `null` prop, `null`/`undefined` array member or child | `NSNull` (`null`) |
| number | `NSNumber` double; `1` and `1.0` are identical |
| boolean | `CFBoolean`; `<text>{true}</text>` renders `1` natively |
| function, `Map`, `RegExp`, class instance | dictionary of own enumerable properties (functions become `{}`) |
| `Date` | `NSDate` |
| primitive props object | `TypeError: Cannot convert primitive to NSDictionary` |
| array as props | dictionary keyed `"0"`, `"1"`, … |

Function components receive the bridged dictionary, so function-valued props
are `{}` inside the component. JavaScriptCore has no `setTimeout`,
`setInterval`, `queueMicrotask`, `structuredClone`, `TextEncoder`, `URL`, or
`atob`; `console` has only `log` and `error`. The browser realm hides them.

Execution flow matches the native host: `util.js`, then Moment when the
transpiled code contains `moment(` or `moment.`, then the entry, then `$main()`.
A missing `$main` is `undefinedRender`. If the transpiled code does not contain
the text `$render`, the result is a `#UI Not Found#` text element. The first
`$render`, `$error`, or uncaught exception completes the run, and the first
completion is captured deterministically. Babel syntax errors are reported as
`scriptException` (category Runtime), because the native compiler receives
`undefined` output and then reports the exception.

## Parity results

`BrowserPreviewParityTests.swift` runs every package under
`Script.bundle/{api,component,template}` and `Gallery/widgets` with a shared
[prelude](../Web/preview-engine/test/parity/prelude.js) that fixes the clock,
randomness, `$device`, and `$system`, then writes the canonical tree JSON to
`Web/preview-engine/test/parity/native-trees.json`. Packages that need live
data (`fetch`, `$http`, `$location`, `$health`, `$dataSource`) are skipped on
both sides.

| Host | Engine | Result |
| --- | --- | --- |
| macOS 27 `ScriptWidgetRuntimeTests` | JavaScriptCore | reference: 118 packages, 100 trees, 18 skipped |
| iOS 27.0 Simulator (iPhone 17) `ScriptWidgetRuntimeTests` | JavaScriptCore | identical to the reference |
| Node 24 (`npm test`) | V8 | 100/100 byte-identical |
| Claude browser pane (Chromium) via sandboxed frame | V8 | 100/100 byte-identical; warm edit to tree 13–16 ms; sandbox ready 311 ms |

Regenerate the reference after an intentional runtime change:

```bash
TEST_RUNNER_SCRIPTWIDGET_UPDATE_PARITY=1 xcodebuild -project macOS/ScriptWidgetMac.xcodeproj -scheme ScriptWidgetRuntimeTests -destination 'platform=macOS' test -only-testing:ScriptWidgetRuntimeTests/BrowserPreviewParityTests
```

JavaScriptCore reads the process time zone once, so the native comparison
skips itself on a machine whose time zone differs from the recorded one. The
Node and browser comparisons run in the recorded zone.

## Isolation results

Probes run as user code in the sandboxed executor (Chromium):

| Probe | Result |
| --- | --- |
| `XMLHttpRequest`, `importScripts`, `postMessage`, `indexedDB`, `self`, `navigator`, `setTimeout`, `Babel`, `WebSocket` | all `undefined` |
| real `fetch` reached through the prototype chain, `no-cors` | blocked by CSP; the same request from the parent page succeeds (control) |
| real `importScripts` of an HTTPS URL through the prototype chain | blocked (`NetworkError`) |
| nested `Worker` | unavailable |
| frame `postMessage` through the prototype chain | unreachable; the frame also accepts only one schema-checked result per run |
| `while (true) {}` | Worker terminated, `resourceLimit` |
| `eval("1 + 1")` | `2` (`'unsafe-eval'` is allowed inside the opaque frame for JavaScriptCore parity) |

The CSP, not the global scrubbing, is the security boundary; scrubbing exists
for parity. The same probes pass in iOS 27 Safari (see the verification
matrix). Firefox and the deployed GitHub Pages site are not yet verified.

## Known differences

- Error message text differs between engines (`ReferenceError: x is not
  defined` versus `Can't find variable: x`). Compare error kinds and categories,
  not messages.
- Both hosts now stop runaway synchronous JavaScript: the browser terminates
  the Worker at the deadline, and the native runtime terminates the script
  through JavaScriptCore's execution-time watchdog within about 0.25 seconds.
- Built-ins differ by OS: iOS versions ship different JavaScriptCore releases,
  and the browser may offer newer `Array`/`Object` methods. The parity reference
  is macOS 27 and matches the iOS 27.0 simulator; older iOS releases and
  physical devices have not been compared.
- `$xml.parse` reports "not available in the web preview yet" because Workers
  have no `DOMParser`; a bounded parser matching `ScriptWidgetXMLParser` is
  pending.
- Props with object cycles fail with a bounded-depth error in the browser.
- `Intl` output depends on the host locale; the reference recorded `en-US`.

## Stage 1: visual renderer

Status: core renderer complete, 2026-10-17. `src/render/` turns the canonical
tree JSON into a widget-sized DOM element. Try it with `npm run build`, then
serve `Web/preview-engine` and open `/demo/preview.html`.

| File | Role |
| --- | --- |
| `src/render/props.js` | Ports of the native property readers and parsers: string-only `padding`, ARGB 8-digit hex, `frame` modes, fonts, points, gradients. |
| `src/render/layout.js` | SwiftUI-style propose/size/place layout: stacks give space to the least flexible child first and spacers only the leftover; text wraps with the browser's line breaker and truncates by available height. |
| `src/render/renderer.js` | Element builders in native modifier order (padding, frame, background, corner, clip, opacity, rotation, shadow), the widget container, and drawing with absolutely positioned elements. |
| `src/render/coverage.js` | Coverage matrix; published as [browser preview coverage](browser-preview-coverage.md). |
| `scripts/compare-snapshots.mjs` | Renders every package in headless Chrome and compares it with native iOS snapshots. |

### Calibration

`BrowserPreviewParityTests.testExportNativeSnapshots` renders the corpus and
the cases in `test/render/cases.json` on the iOS 27 simulator the way the
widget composes its root (root `background` as container background, root
view centered) at the 393-point iPhone sizes: small 158×158, medium 338×158,
large 338×354.

```bash
TEST_RUNNER_SCRIPTWIDGET_EXPORT_SNAPSHOTS=1 xcodebuild -project iOS/ScriptWidget.xcodeproj -scheme ScriptWidgetRuntimeTests -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:ScriptWidgetRuntimeTests/BrowserPreviewParityTests/testExportNativeSnapshots
```

Measured from those snapshots and encoded in the renderer:

- Single-line `Text` height is `ceil(size × 1.1934 × 2) / 2`: 20.5 for body, 41 for
  largeTitle. Additional lines advance by the Dynamic Type leading (22 for body).
- HStack default spacing is 8. In a VStack, text to text is the leading minus
  the natural height (2 for body, 1 for title); text to other views is about
  `8 + 0.18 × font size`; other views are 8 apart. Backgrounds keep a view's
  spacing behavior; padding and frames reset it. An HStack takes the largest
  text edge of its children.
- Spacers reserve their 8-point minimum and only take leftover space.
- Truncated text reports the whole offered width.
- Named colors are the iOS 26 system palette (blue `#0088FF`, red `#FF383C`, …);
  `secondary` is `rgba(60,60,67,0.6)`. Button labels default to the accent blue.

### Results

`npm run compare` against the native snapshots (pixels differing by more than
48 of 255 in any channel, Chrome on macOS with SF fonts):

| Set | Count | Median | ≤1% | ≤3% | ≤5% | ≤10% | ≤20% |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Corpus (100 packages × 3 sizes) | 300 | 1.79% | 105 | 192 | 242 | 283 | 296 |
| Calibration cases | 30 | 0.63% | 20 | 26 | 28 | 30 | 30 |

At Stage 1, `gauge`, `chart`, and grids were placeholders and SF Symbols were
placeholder glyphs; Stage 4 below replaced them. Smaller differences come from line-breaking choices
in large text (iOS sometimes hyphenates or breaks one word earlier) and
sub-pixel text positioning. On Windows and Linux, fonts fall back from SF Pro,
so widths and wrapping can differ more than these numbers.

### Results after Stage 4

The latest `npm run compare` (after icons, gauges, charts, grids, animations,
and the native font weight fix, with snapshots re-exported):

| Set | Count | Median | ≤1% | ≤3% | ≤5% | ≤10% | ≤20% |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Corpus (100 packages × 3 sizes) | 300 | 1.87% | 102 | 193 | 244 | 288 | 298 |
| Calibration cases (incl. dark, gauges, charts, grids, accessories) | 40 | 0.84% | 22 | 32 | 36 | 39 | 40 |

The largest remaining differences are animated templates (see Stage 4) and
Swift Charts styling.

### Native behaviors worth knowing

The renderer reproduces these because they are what users see on iPhone:

- `padding={10}` (a number) is ignored; only strings like `"10"` apply.
- `frame="max,20"` sets only the height; the width is not expanded.
- `#fff` (3-digit hex) is nearly transparent black; 8-digit hex is ARGB.
- Until 2026-10-17, `weight`, `fontWeight`, and `fontDesign` were not read by
  any native builder even though Studio completions advertised them; the
  bundled templates used `weight` 76 times with no effect. They are now
  applied by `ScriptWidgetAttributeFontModifier` (`fontWeight` wins over the
  older `weight`), on iPhone and in the web preview.
- An invalid color falls back to the shape's default fill (black in light mode).

## Stage 2: Web Studio

See the user guide, [Web Studio in the browser](web-studio-browser.md).

| File | Role |
| --- | --- |
| `Web/studio/src/main.js` | Projects, files, preview controls, Problems/Console/Package/Fixtures panels, templates, import, export, install. |
| `Web/studio/src/editor.js` | CodeMirror 6 with the Studio completions, diagnostics, and hover from `Editor/editorfe`. |
| `Web/studio/src/store.js` | IndexedDB drafts with an in-memory fallback and a visible warning when storage is unavailable. |
| `Web/studio/vite.config.js` | Generates `sandbox.html`, copies the runtime scripts, and builds `templates.json` from the 70 bundled templates and the Gallery. |
| `src/package/manifest.js` | Ports of `ScriptWidgetPackage.readManifest` (strict keys, Codable types) and `WidgetPackageManifestValidator`. |
| `src/package/archive.js` | Port of `ScriptPackageArchivePreflight`, extraction with the native root detection, and stored-ZIP export under the package directory. |

A present but malformed `widget.json` fails closed in the browser. Package
export is checked natively: `BrowserPreviewParityTests.testWebExportedPackageImportsNatively`
imports `test/fixtures/web-export.swt` (written by the web export code) with the
native preflight, SSZipArchive extraction, manifest validator, image lookup,
and execution.

## Stage 3: CLI and MCP

```bash
node Web/preview-engine/bin/scriptwidget-preview.mjs path/to/MyWidget --family small --output preview.png --diagnostics preview.json
```

- Runs the package in headless Chrome's sandboxed runtime frame (not in the Node
  process) and writes a PNG plus diagnostics: `sourceHash` (SHA-256 of every
  package file), size, fixtures hash, `engineVersion`, `compilerFingerprint`,
  timings, logs, validation issues, and the resolved tree.
- A failed render deletes the previous PNG so a stale image is never mistaken
  for the current edit. `--watch` re-renders on change.
- `--device http://<ip>:<port> --pair-code 123456` also pushes the text files to
  an iPhone or iPad running Web Studio (HTTP API v1, entry file last, revision
  checked) and saves the device's native SwiftUI preview as
  `preview.native.png`, rendered at the size selected in the app's preview.
  Binary resources are not part of that API and are reported as skipped.
- Debug builds launched with `-WebStudioAutoStart` open Web Studio and log
  `Web Studio QA pairing: port … code …`, so the loop can run unattended in the
  simulator: `xcrun simctl launch booted com.everettjf.scriptwidget -WebStudioAutoStart`,
  then read the code with `xcrun simctl spawn booted log show --last 1m --predicate 'eventMessage CONTAINS "Web Studio QA pairing"'`.
- `bin/scriptwidget-mcp.mjs` is a stdio MCP server with
  `render_widget_preview` (image plus diagnostics), `validate_widget_package`,
  and `export_widget_package`. Package paths are confined to the working
  directory (or `SCRIPTWIDGET_MCP_ROOTS`).

```bash
claude mcp add scriptwidget -- node Web/preview-engine/bin/scriptwidget-mcp.mjs
```

## Stage 4: broader parity

- Gauges follow `MineGaugeView`: segment arcs, round end caps, needle, and the
  native quirk that the default label is always `60%`. System gauge styles are
  approximated.
- Charts draw Swift Charts marks (bar, stacked bar, line, point, area, rule,
  Gantt) with 1/2/5 tick steps, grid lines, and a category legend.
- Lazy grids implement fixed, flexible, and adaptive tracks.
- Clock-hand animations rotate at the current time (hour, minute, second,
  custom period, time zone, anchor) and swing animations move with CSS.
  The native in-app snapshots are static because the animation modifier only
  runs in the widget target, so animated templates differ from them by design.
- Lock Screen families (circular, rectangular, inline) and an iPad profile
  (extra large, extra large portrait) are available; accented and vibrant
  rendering modes are approximated, honoring `widgetAccentable`.
- Dates use the real clock like the widget and the native `date` names
  (`now`, `tomorrow`, `start of today`, `+3h`, `-2d`, or milliseconds).
- SF Symbols ending in `.fill` draw their look-alike icon solid; long words that
  do not fit a line are hyphenated like UIKit, carrying at least three letters
  to the next line (`ScriptWid-get`); chart category labels that do not fit
  their band are truncated with "…".

## macOS comparison: ScriptWidget Preview

`Tools/ScriptWidgetPreview` is a small macOS app that renders each package
with the native runtime on macOS and with the web engine in a `WKWebView`,
side by side, and measures the difference (see its README). It made it
practical to compare every corpus package on macOS, and it showed that macOS
SwiftUI differs from iOS in ways the iOS-calibrated renderer did not model.
The web engine now has a `macos` device profile (also offered as **Mac** in
Web Studio) that uses these measured macOS 26 behaviors:

- Text styles are smaller (`body` 13 pt, `title` 22 pt, `headline` bold) and
  text lays out on whole points; sized fonts use a measured height table.
- `.primary` is black or white at 84.7% opacity and `.secondary` 49.8% /
  54.9%; dark `gray` is (152, 152, 157); the widget background (`.background`)
  is (46, 46, 46) in dark mode.
- In a `VStack`, text to text adds only the upper font's leading, text above
  another view 0.4729 × size, and a view above text 0.2109 × size, each plus
  a half-point step of about 0.118 × size (iOS uses 8 + 0.18 × size).
- Words wider than the line break between characters without a hyphen, a
  short last-line orphan is pushed down a line ("October / 18, 2026"),
  truncation drops the space before "…", and a narrow column keeps wrapping
  one character per line.
- `<button>` uses the bordered style: a 5-point rounded bezel of 7.45%
  primary around 4 × 12 points of padding, with the label in the primary
  color.
- Swift Charts starts the plot at the top edge and reserves 20 points for x
  labels and 20.5 for y labels.

SF Symbols now use their real proportions on every platform:
`symbolMetrics.generated.js` holds the SwiftUI size of all 281 mapped
symbols, so an `hourglass` is 0.825 em wide instead of 1.2 em.

Results from `--batch` (macOS 27, `WKWebView`, same 48/255 rule):

| Set | Count | Median | ≤1% | ≤3% | ≤5% | ≤10% | ≤20% |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Corpus, iOS metrics at macOS sizes (before) | 300 | 3.23% | 62 | 142 | 190 | 268 | 298 |
| Corpus, `macos` profile (after) | 300 | 0.97% | 153 | 254 | 280 | 296 | 299 |
| Calibration cases (before) | 38 | 1.92% | 15 | 23 | 30 | 36 | 37 |
| Calibration cases (after) | 38 | 0.24% | 30 | 35 | 37 | 38 | 38 |

The iOS comparison did not regress with the shared symbol metrics: corpus
median 1.80% (247/300 within 5%, 299/300 within 20%), cases unchanged at
0.84%. The largest remaining macOS differences are animated or time-based
templates (native clock hands are not captured by `ImageRenderer`), a few
narrow multi-column layouts, and icon artwork.

## Verification matrix

| Check | Result |
| --- | --- |
| Tree parity, macOS 27 JavaScriptCore reference | 100/100 corpus trees |
| Tree parity, iOS 27.0 simulator JavaScriptCore | identical to the reference |
| Tree parity, Node 24 / Chromium (headless and Claude pane) | 100/100 byte-identical |
| Tree parity, iOS 27 Safari (WebKit) in the simulator | 100/100 byte-identical; all isolation probes blocked; CSP control reached |
| Pixel comparison vs iOS 27 snapshots, Chrome on macOS | corpus median 1.80% (247/300 within 5%, 299/300 within 20%); calibration cases median 0.84% |
| Pixel comparison vs macOS 27 native, `WKWebView` (ScriptWidget Preview) | corpus median 0.97% (280/300 within 5%, 299/300 within 20%); calibration cases median 0.24% |
| Web Studio, headless Chrome smoke test | starter, 71 templates, image template, `.swt` import all render |
| Web Studio, iOS 27 Safari | renders with the strict page CSP and URL-loaded sandbox |
| Web-exported `.swt` imported by native code | passes preflight, extraction, validation, execution |
| Device sync, end to end | CLI → ScriptWidget app (Debug, iOS 27 simulator) over Web Studio API v1: paired, uploaded the changed entry, received the native PNG of the same source |
| Non-Apple fonts | corpus median 2.58% with the bundled Inter fallback (222/300 within 5%, 299/300 within 20%); 2.67% with generic fallback fonts |
| Pages layout | `site/` + Studio at `/studio/` assembled like the workflow passes the smoke test; both workflows parse |
| **Not verified** | Firefox; real Windows/Linux machines (measured on macOS with Apple fonts excluded); a physical iPhone; share-sheet install (needs taps); the live site, which publishes after merging into `main` |

WebKit note: revoking a blob URL immediately after `new Worker(url)` prevents
WebKit from starting the Worker because it fetches the script asynchronously.
The sandbox frame keeps the URL alive; this was found and fixed in the
simulator check above.

## Native fixes found by this work

- **Web Studio snapshot was blank.** The capture view lived in a `.background`,
  so it captured only the background host, and the preview was usually
  scrolled off-screen. Web Studio now renders the widget itself with
  `ImageRenderer`, composed like the real widget.
- **Package names with spaces failed in Web Studio.** Browsers encode query
  spaces as `+`, which `URLComponents` does not decode; opening or deleting a
  file in a package such as "My Widget" returned "Document not found". The
  server now decodes form spaces (`WebStudioServerTests.testDecodesFormEncodedQuerySpaces`).
- **Malformed manifests were reinterpreted on import.** A present but invalid
  `widget.json` was replaced by a legacy manifest; import now fails closed
  (`ScriptManagerLifecycleTests.testMalformedPresentManifestFailsClosedOnImport`).
- **Font weight properties were ignored** (see Stage 1 notes above).

## Fonts outside Apple platforms

SF Pro is not distributed with the site. The renderer's font stack falls back
to "ScriptWidget Inter", which the Studio bundles (Inter, SIL Open Font
License 1.1; license published at `/studio/licenses/`), so Windows and Linux
previews share one set of metrics. Measured on the corpus by excluding Apple
fonts (`SW_FONTS=inter npm run compare`): median 2.58% versus 1.87% with SF.

## Corrections to the research proposal

- `undefinedRender` means `$main` is missing. A script whose text never
  contains `$render` renders `#UI Not Found#`. A script that contains it but
  never calls it times out.
- `$import` needs real classic-script evaluation. Indirect `eval` does not
  share `let`/`const` between files the way `JSContext.evaluateScript` does.
