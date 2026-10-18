# Browser-first Widget preview: technical research and implementation plan

Status: research proposal, 2026-10-17. This document records a direction and
validation plan. It does not change the runtime, package format, or Studio
behavior.

## Decision

Build a browser-first authoring and fast-preview path for ScriptWidget packages.
The browser should run on Windows, macOS, and Linux without Xcode or a connected
iPhone. Use the iPhone app's native SwiftUI preview and a real WidgetKit widget
for final verification. Keep the macOS Studio as an optional native workflow.

The browser does **not** need a general implementation of SwiftUI or WidgetKit.
It needs to compile and execute the existing ScriptWidget JSX contract, then
render the resulting ScriptWidget element tree with a carefully scoped web
renderer. WidgetKit still controls the actual widget host, appearance, timeline,
and refresh behavior on Apple devices.

## Evidence in this repository

- [Web Studio](web-studio.md) already serves the Vite/CodeMirror editor from an
  iPhone or iPad. The browser edits files; the device executes JSX and supplies
  a native-preview PNG. Its session ends when the device leaves the foreground.
  It is cross-platform authoring, but not standalone browser rendering.
- `ScriptWidgetCompiler` in
  [`ScriptWidgetRuntime.swift`](../Shared/ScriptWidgetRuntime/Widget/Runtime/ScriptWidgetRuntime.swift)
  wraps the entry in `$main`, then uses the bundled Babel `scriptwidget` preset.
  The bundle is about 2.7 MiB. A read-only Node VM check using that exact bundle
  transformed `<vstack><text>Hello</text></vstack>` into nested
  `ScriptWidget.createElement(...)` calls. Browser compilation is therefore
  feasible without translating JSX to Swift source.
- [`util.js`](../Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle/util.js)
  forwards `ScriptWidget.createElement` to `$element.createElement`. The native
  [`ScriptWidgetRuntimeElement`](../Shared/ScriptWidgetRuntime/Widget/Component/ScriptWidgetRuntimeElement.swift)
  stores tag, props, and children. The runtime resolves function components and
  nested children before validating the tree. The native
  [`ScriptWidgetElementView`](../Shared/ScriptWidgetRuntime/Widget/Component/ScriptWidgetElementView.swift)
  switch is the authoritative mapping from tags to SwiftUI views.
- The native runtime limits source to 512 KiB, transpiled source to 2 MiB,
  execution to 5 seconds, and the element tree to 1,000 nodes, 64 levels, and
  128 props per element. The browser should follow these contract boundaries.
- The real iOS widget uses `.contentMarginsDisabled()` and a separate root
  container-background modifier in
  [`ScriptWidgetMain.swift`](../iOS/ScriptWidgetWidget/ScriptWidgetMain.swift)
  and [`ScriptWidgetRootView.swift`](../iOS/ScriptWidgetWidget/ScriptWidgetRootView.swift).
  The in-app [`ScriptCodePreviewView`](../iOS/ScriptWidget/View/CodeEditor/Preview/ScriptCodePreviewView.swift)
  uses a SwiftUI element view with sizes from
  [`TOCropWidgetSizeHelper.m`](../iOS/ScriptWidget/View/PhotoPicker/TOCropViewController/TOCropWidgetSizeHelper.m),
  which includes fixed values for older screen sizes. In-app preview is useful,
  but it is not a universal pixel reference for the Home Screen.
- Package 2.0 already defines `widget.json`, an entry file, nested resources,
  and `.swt` ZIP export. See [package format](package-format.md). Browser export
  must preserve validation and iPhone import must continue to review declared
  permissions. Today's `scriptwidget://` handler only supports `reload-all`; it
  is not a one-tap package-install channel.

A simple scan of the 150 bundled JSX examples plus the Gallery Hello Card found
`vstack` in 137 files, `text` in 97, `hstack` in 64, `spacer` in 51, and `icon`
in 40. These counts are a prioritization signal, not a compatibility measure.
Text styling, frames, colors, spacing, backgrounds, and padding also occur
frequently. The first renderer milestone should focus there.

## Existing browser SwiftUI projects

| Project | What it demonstrates | Fit for ScriptWidget |
| --- | --- | --- |
| [MiniSwift](https://www.miniswift.run/) | A browser-hosted Swift compiler and SwiftUI-like runtime implemented without Apple's runtime. | Proof that an interactive browser preview is possible. It does not directly consume our JSX or guarantee WidgetKit appearance. |
| [Tokamak](https://github.com/TokamakUI/Tokamak) | SwiftUI-compatible web rendering with a limited view subset. Its repository was archived in January 2026. | Useful layout reference, unsuitable as the product's core dependency. |
| [SwiftWebUI](https://github.com/SwiftWebUI/SwiftWebUI) | Swift views served to a browser; its maintainers describe it as a toy project. | Does not meet the pure-browser JavaScript execution and package workflow requirement. |
| [SwiftUI Online Playground](https://github.com/kishikawakatsumi/swiftui-playground) | A browser editor backed by hosted Mac infrastructure. | Demonstrates remote-native preview, but introduces Mac/server cost and latency. |

Using one of these as a renderer would still require an adapter for every
ScriptWidget tag and property, plus separate WidgetKit environment simulation.
The smaller and more controllable target is our own element contract.

## Proposed architecture

```text
Package 2.0 files (browser draft or local project)
    -> exact ScriptWidget Babel preset, version-pinned and cached
    -> isolated JS execution with bounded host API adapters
    -> resolved and validated element tree
    -> preview-only normalized tree + diagnostics
    -> DOM/CSS layout and SVG for suitable shapes/charts
    -> browser view or PNG with source hash and renderer version
```

### Compiler and browser runtime

Use the same Babel preset and JSX pragma as the native runtime. Do not compile
JSX into React elements, HTML strings, or Swift. Pin the compiler fingerprint
and test representative transformed output against the JavaScriptCore path.
The browser executor must support the native entry convention, `$render`,
function components, fragments, nested arrays, and package-relative `$import`.
Preserve `String`, `JSON`, and other ordinary JavaScript behavior where possible,
while documenting differences between browser JavaScript and JavaScriptCore.

Implement host APIs behind a `PreviewContext`: family, appearance, rendering
mode, locale, fixed clock, parameter, sample data, and a virtual package file
system. `$getenv` reads this context. `$file` and `$storage` stay package-scoped.
Network, location, health, and authenticated data sources should default to
explicit fixtures; browser CORS and user secrets cannot silently stand in for
the extension's permission model. A later live-data mode needs its own explicit
capability and privacy design.

User JSX is untrusted executable code. It must not execute in the privileged
editor page. Run compilation and execution off the UI thread, enforce native
size/tree/time budgets, and terminate runaway work. A Worker alone prevents UI
blocking but is **not** a security boundary when it shares the editor's origin.
Before public hosting, validate an isolated execution origin or equivalent
sandbox, restrictive network policy, and a narrow `postMessage` protocol. Pass
only validated data into the renderer. Insert user text with DOM text APIs, not
`innerHTML`.

### Rendering model

Render ScriptWidget tags, not arbitrary SwiftUI. Start with DOM text and images,
CSS for common styling, and SVG for precise vector shapes. Keep a separate
measure/place policy for stacks, spacers, frames, and alignment so CSS Flexbox
is an implementation aid rather than the complete layout specification.
[Apple's SwiftUI layout description](https://developer.apple.com/documentation/swiftui/laying-out-a-simple-view)
explains why: a parent proposes a size, each child reports a size, then the
parent positions its children. A plain CSS translation will differ in intrinsic
sizing, default spacing, line wrapping, and flexible space allocation.

The native modifier order is part of the visual contract. For example,
[`ScriptWidgetAttributeGeneral`](../Shared/ScriptWidgetRuntime/Widget/Component/Attributes/ScriptWidgetAttributeGeneral.swift)
applies padding before frame and background, then corner radius, clipping,
opacity, and effects. The web implementation must be checked against this order
and the native property parsers. Unsupported tags or props should yield visible
diagnostics, never silently disappear or imply pixel accuracy.

The preview frame must specify a device/profile and WidgetKit context rather
than use one universal widget size. Support family, light/dark, full-color,
accented, and vibrant states in stages. The root container background and
content-margin policy deserve separate tests. Apple documents that Widget
appearance changes with [placement and rendering mode](https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances).

Text and SF Symbols are fidelity risks on Windows. System fonts, fallback font
metrics, symbol availability, and glyph rendering vary by browser and OS.
Before distributing any Apple font or symbol assets through a website, review
their applicable [font](https://developer.apple.com/fonts/) and
[SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols)
terms. Provide an explicit approximation or missing-symbol diagnostic where
the web renderer cannot legally or technically match the native result.

### Project storage and agent interface

Offer two authoring modes backed by the same preview engine:

1. **Standalone website:** create/import Package 2.0, save browser-local drafts,
   edit all declared text/resources, and export a validated `.swt`. The
   origin-private file system is available across modern browsers, but clearing
   browser data can remove drafts. Provide explicit export and backup affordances.
2. **Local agent workflow:** a small cross-platform process serves the editor,
   watches an ordinary package directory, and exposes the same renderer to
   Claude Code/Codex. A proposed CLI contract is
   `scriptwidget preview ./MyWidget --family systemSmall --fixture sample.json
   --output preview.png --diagnostics diagnostics.json`.

The CLI and future MCP adapter should share one implementation. Every preview
result should include source hash, family, fixture identifier, renderer version,
and diagnostics so an agent cannot mistake a stale image for the current edit.
Use a headless browser only for PNG capture; keep the actual preview semantics
in the same browser renderer as the editor. Playwright supports element
[screenshots](https://playwright.dev/docs/screenshots), but browser installation
size and startup time need measurement before selecting the CLI packaging.

Direct user-directory access via `showDirectoryPicker()` is an optional
convenience, not the only file workflow: MDN marks it as having
[limited browser availability](https://developer.mozilla.org/en-US/docs/Web/API/Window/showDirectoryPicker).
For an initial phone transfer, export `.swt` and use the app's existing import
path. A later QR/deep-link or paired transfer must reuse transactional package
validation and permission review. A hosted HTTPS editor cannot assume it can
call the phone's LAN HTTP server: browser
[local-network and mixed-content restrictions](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Local_network_access)
vary by browser.

## Fidelity model and acceptance

Label previews by their authority:

1. **Web fast preview:** immediate feedback and agent screenshots.
2. **iPhone app native preview:** shared SwiftUI component implementation.
3. **Real WidgetKit display:** final reference for Home Screen/Lock Screen
   appearance, interactions, and refresh behavior. WidgetKit renders widgets
   in a separate process and manages timeline refreshes; a website cannot
   simulate those system guarantees. See [Apple's WidgetKit guidance](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

Build a comparison corpus from roughly 20 representative existing packages,
covering common tags, custom components, imported files, images, long text,
small/medium/large families, light/dark, and at least one accented context.
Keep fixture data and time fixed. Compare:

- the resolved element tree from JavaScriptCore and browser execution;
- component bounds, text wrapping, clipping, backgrounds, and image cropping;
- web PNG, in-app native screenshot, and selected real WidgetKit screenshots.

The first release gate is: no silent unsupported feature, no stale screenshot
presented as current, no editor-origin exposure to user code, no package that
passes web export but fails known Package 2.0 validation, and no obvious crop
or missing content in the curated comparison corpus. Set numeric visual-diff
thresholds only after collecting native baselines; font and anti-aliasing
differences make a single raw-pixel threshold misleading. Target under one
second for a warm common edit-to-web-preview cycle, then measure on Windows
and macOS before treating that as a release promise.

## Implementation sequence

| Stage | Deliverable | Decision gate |
| --- | --- | --- |
| 0. Contract spike | Reuse the bundled compiler in a browser worker; execute a self-contained package; output a resolved tree and diagnostics. | Compare transforms and trees with JavaScriptCore on representative JSX, including functions and `$import`. Prove bounded termination and isolation design. |
| 1. Core visual prototype | `vstack`, `hstack`, `zstack`, `text`, `spacer`, basic shapes, frame, padding, color, background, alignment, clipping, and images. | Review native/web paired screenshots on the initial corpus; record every mismatch and unsupported prop. |
| 2. Standalone Studio | Package create/import/export, browser drafts, environment selectors, fixtures, and explicit preview status. | A Windows user can design, preview, export, and import a simple widget without a Mac or a continuously foregrounded iPhone. |
| 3. Agent tools | Local project watcher, CLI PNG/JSON output, then a thin MCP adapter and examples for Claude Code/Codex. | An agent can edit, render, inspect diagnostics and the matching screenshot, and iterate without UI clicks. |
| 4. Broader parity | Dates, icons, grids, charts, gauges, controls, accessibility states, additional families and modes. | Expand only where native comparison and user demand justify the maintenance cost. Keep Live Activity and Control Widget as distinct later scopes. |

## Open decisions before implementation

- Which iPhone/iPad and OS versions define the first device-profile corpus?
- Which icon strategy is both lawful for a public website and close enough to
  native SF Symbols on Windows?
- Should optional live HTTP preview use a browser-safe proxy, a paired device,
  or remain fixture-only in the first release?
- What is the lowest-friction `.swt` import flow on iPhone after browser export?
- Which browser engine should the optional headless CLI package use, and what
  download/startup cost is acceptable?

These questions do not block the Stage 0 contract spike. They should be
resolved with measurements and prototype screenshots before promising
pixel-perfect WidgetKit parity.
