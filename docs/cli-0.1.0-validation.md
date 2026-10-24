# CLI 0.1.0 validation evidence

The external Agent workflow uses an independently distributed macOS CLI and Web Studio. No App Store update is required. This change adds two default-disabled validation host seams to shared native sources; application and extension behavior remains unchanged.

## Local checks

- Native CLI: universal arm64/x86_64 Release build succeeded. Fourteen smoke tests pass, covering compile-only checks, flat package archives, native PNG rendering, source fingerprints, permission enforcement, data-query budgets, temporary storage, sandbox isolation, path/output protections, stale artifacts, diagnostics and execution deadlines.
- Swift/Node source fingerprints agree for Unicode paths and binary resources.
- Web Studio: 98 tests pass; TypeScript/Vite production build and browser validation smoke pass. Pasting creates a separate project; exported reports identify browser checks and never claim native verification.
- macOS runtime suite: 703 passed, 32 skipped, zero failures (735 total).
- iOS simulator runtime suite: 709 passed, 31 skipped, zero failures (740 total).
- Editor, preview engine, browser compatibility, runtime/storage/security probes, macOS application build and iOS simulator application build passed in release-readiness checks.
- Skill package validation, release metadata, documentation links and generated project syntax passed.

The release-readiness shell run reached the final iOS test stage, whose existing simulator stalled before test execution. That invocation was interrupted. The same suite completed successfully on a newly created iOS 27 simulator with parallel testing disabled. The shell invocation itself is therefore not reported as a successful end-to-end run.

Local evidence: `/tmp/scriptwidget-cli-tests.log`, `/tmp/scriptwidget-cli-universal-build.log`, `/tmp/scriptwidget-web-tests.log`, `/tmp/scriptwidget-web-build.log`, `/tmp/scriptwidget-release-readiness.log`, `/tmp/scriptwidget-ios-fresh-tests.log`; Xcode result bundles are under `/tmp/scriptwidget-release-readiness/`.

## Boundaries

Apple Silicon is the physical host; Intel execution is checked with Rosetta, not a separate Intel Mac. System/health/account APIs use deterministic fixtures. Permission policy is checked, but real device authorization, live account access and complete native query-argument semantics are not certified by these fixtures. Data Source Plugin rendering remains explicitly unsupported by this CLI version. The native worker has no network or personal-data entitlements.

Before/after Web Studio screenshots: [before](images/agent-validation-before.png), [validation dialog](images/agent-validation-web.png).

Publication receipts and installation verification are recorded after signed release publication.
