# CLI 0.1 release validation evidence

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

## Publication receipts

- CLI release: https://github.com/everettjf/scriptwidget/releases/tag/cli-v0.1.1
- Signed source: ed7bce13316d1516b2cee4935bb348671a33b56d
- Homebrew tap: 1a9773f, final formula uses ditto to preserve signed resource layout.
- arm64 and x86_64: 14 tests each passed; notarized Accepted; nested and outer ticket validation passed after archive extraction.
- Homebrew fresh install, upgrade, uninstall/reinstall, doctor and formula tests passed. Installed 0.1.1: all 14 smoke tests passed; codesign, spctl Notarized Developer ID and stapler validation passed.
- Homebrew tests verify installed resources/signature and controller path denial. Native execution is tested separately outside Homebrew's additional test sandbox, which prevents App Sandbox worker activation.
- Public Skill 0.1.1: downloaded, SHA-256 verified, extracted and quick-validated.
- Agent acceptance: current compiler syntax diagnostic → repair → native light/dark PNGs visually inspected → .swt export. Run by this agent using the shipped Skill references; discovery in every third-party Agent client is not claimed.
- Native CLI CI: https://github.com/everettjf/scriptwidget/actions/runs/40065637969

- Browser CI passed on Linux and Windows: https://github.com/everettjf/scriptwidget/actions/runs/40065637964
- A Firefox navigation timeout in one earlier Windows job passed on retry: https://github.com/everettjf/scriptwidget/actions/runs/40065070583
- Production deployment succeeded: https://github.com/everettjf/scriptwidget/actions/runs/40066097024
- Production browser acceptance passed at https://xnu.app/scriptwidget/studio/: Validate entry, paste to a separate project, preview execution and current browser-only report download.
- Full App-platform remote CI was still running at publication: https://github.com/everettjf/scriptwidget/actions/runs/40065637972 . Local macOS/iOS suite results are documented above; this remote run is not claimed as passed.

## Follow-up: Creator naming and App CI

CLI 0.1.2 bundles the renamed `scriptwidget-creator` Skill. Both architecture archives passed the 14 smoke tests, release identity checks, Developer ID signing, notarization and extracted ticket verification. The installable Skill is `scriptwidget-creator-0.1.2.zip` in [CLI 0.1.2](https://github.com/everettjf/scriptwidget/releases/tag/cli-v0.1.2).

The previously pending [full App CI](https://github.com/everettjf/scriptwidget/actions/runs/40065637972) finished with a macOS editor test timeout: `VisualLayoutEditorTests/testWorkspaceLayoutSwitchPreservesPendingEdits` (698 passed, 1 failed, 33 skipped). The same test also timed out on the pre-change main run [40000963848](https://github.com/everettjf/scriptwidget/actions/runs/40000963848). This existing editor/CI issue remains open; no full remote App-gate success or subsequent iOS CI execution is claimed. It is separate from the successful native CLI, Web and local runtime checks above, and is not fixed as part of the Skill rename.
