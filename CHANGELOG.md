# Changelog

Notable user-visible changes are recorded here. ScriptWidget follows semantic versioning for public package/runtime contracts even when App Store marketing versions use another cadence.

## Unreleased

### Added

- Full macOS app and WidgetKit workspace with Studio editing, diagnostics, Console, multi-size previews, native commands, and first-run tutorial.
- OpenAI-compatible Widget generation with Keychain-backed credentials, structured prompts, run/diagnose/refine workflow, evaluations, and reusable Skills 1.0.
- Package 2.0 manifests, JSON schemas, migration compatibility, secure imports, and authoring documentation.
- GitHub-backed Widget & Skills Gallery with verified files, offline cache, install/update UI on macOS and iOS/iPadOS, seed content, and contributor workflow.
- Runtime XCTest targets, golden/template validation, release-readiness CI, and iPad/iCloud device scripts.
- Browser preview engine (`Web/preview-engine`): JavaScriptCore-compatible execution in a sandboxed browser worker and a SwiftUI-calibrated web renderer.
- Web Studio in the browser (`Web/studio`, published at `/studio/`): edit, preview, import, and export widgets on any desktop OS and install them on iPhone through the share sheet.
- `scriptwidget-preview` CLI and `scriptwidget-mcp` server for agent workflows, with optional sync to Web Studio on iPhone for native previews.
- ScriptWidget Preview (`Tools/ScriptWidgetPreview`), a macOS developer app that compares the native macOS rendering of a package with the web engine, one package at a time or across the whole corpus.
- A **Mac** device in the web preview and Web Studio, calibrated to macOS 26 text styles, colors, spacing, line breaking, buttons, and charts.

### Changed

- Web Studio is rebuilt with React, strict TypeScript, Tailwind CSS, and shadcn/ui: accessible selects, dialogs, and tabs replace browser prompts and alerts, deletions ask in an in-page dialog, messages appear as toasts, and images open as previews instead of text.
- Expanded the template catalog to 70 validated examples and generated preview fixtures.
- Reworked documentation around a five-minute path, versioned Runtime API, Studio, AI, Skills, packages, Gallery, release readiness, and bilingual onboarding.

### Fixed

- Web preview fidelity across every iOS widget size (16 sizes, 1,649 compared renders, 98.2% matching pixels): baselines, line pitch, VStack spacing, truncation, dictionary hyphenation for text styles, emoji metrics, and stack placement now follow measured SwiftUI behavior.
- Web preview on iPhone sizes: line breaking now follows TextKit's standard strategy, truncation cuts mid-word without a space before "…", Chinese text is no longer hyphenated, charts use the iOS plot insets and label font, and buttons lay out their label side by side.
- Web Studio on iPhone: the native preview image is no longer blank, and packages whose names contain spaces open and save correctly from the browser.
- The share extension imports `.swt` and `.jsx` files shared from a web page (Web Share in Safari), which arrive as files rather than URLs.
- Importing a package with a malformed `widget.json` now fails instead of replacing the manifest with a legacy one.
- `fontWeight`, `fontDesign`, and the older `weight` property are now applied to text, dates, icons, labels, and images. They were documented and used by templates but previously ignored.

- Added local build-cache fallback and proactive package caching for scripts evicted by iCloud. GitHub issue #6 remains open until the physical-iPhone offline acceptance matrix is complete.
