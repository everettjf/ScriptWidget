# Browser preview engine

Status: Stage 0 (contract spike) complete, 2026-10-17. This page records what
was built, what was measured, and the known differences. The proposal and
staged plan live in [browser widget preview research](browser-widget-preview-research.md).

The engine lives in [`Web/preview-engine`](../Web/preview-engine). It compiles
and executes ScriptWidget packages outside Apple platforms and produces the
same resolved element tree as the native JavaScriptCore runtime. Rendering
that tree (Stage 1) and the public Studio website (Stage 2) build on it.

## Decisions

- **Product shape:** a public website on GitHub Pages. Users design and
  preview in the browser, then install the package on iPhone.
- **Promise:** the browser exposes the standard global `Promise` and emits a
  `compat.promise` warning when a script names `Promise`. The native shim is
  left unchanged for now; none of the 151 bundled `.jsx` files construct a
  `Promise` or call `.catch`, `.finally`, or `Promise.all`. `fetch`, `$http`,
  `$health`, and `$location` still return the native then-only object, so
  `fetch(url).catch(...)` fails in the browser exactly as it does on iPhone.
- **Icons:** map SF Symbol names to an open-source icon set and show a
  missing-icon diagnostic for unmapped names (Stage 1).
- **Tree JSON:** the canonical serialization is a test artifact
  (`BrowserPreviewParityTests.swift` and `kernel.js`), not part of the runtime
  contract.

## Architecture

```text
editor page (GitHub Pages origin)
  └─ <iframe sandbox="allow-scripts" srcdoc>   opaque origin, CSP connect-src 'none'
       ├─ compiler Worker (blob:)               bundled Babel, prepares the package
       └─ executor Worker (blob:), one per run  kernel + user code, terminated at the deadline
```

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
for parity. **Not yet verified:** Safari and Firefox, a GitHub Pages deployment
with its own response headers, and a parent-page CSP (a `srcdoc` frame inherits
the parent's policy, so the editor page must allow `blob:` Workers).

## Known differences

- Error message text differs between engines (`ReferenceError: x is not
  defined` versus `Can't find variable: x`). Compare error kinds and categories,
  not messages.
- The native 5-second limit returns an error but does not stop a synchronous
  JavaScript loop. The browser terminates the Worker. The native fix is tracked
  separately.
- Built-ins differ by OS: iOS versions ship different JavaScriptCore releases,
  and the browser may offer newer `Array`/`Object` methods. The parity reference
  is macOS 27 and matches the iOS 27.0 simulator; older iOS releases and
  physical devices have not been compared.
- `$xml.parse` reports "not available in the web preview yet" because Workers
  have no `DOMParser`; a bounded parser matching `ScriptWidgetXMLParser` is
  pending.
- Props with object cycles fail with a bounded-depth error in the browser.
- `Intl` output depends on the host locale; the reference recorded `en-US`.

## Corrections to the research proposal

- `undefinedRender` means `$main` is missing. A script whose text never
  contains `$render` renders `#UI Not Found#`. A script that contains it but
  never calls it times out.
- `$import` needs real classic-script evaluation. Indirect `eval` does not
  share `let`/`const` between files the way `JSContext.evaluateScript` does.
