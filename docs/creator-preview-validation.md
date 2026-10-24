# Creator preview delivery — CLI 0.2.0

`scriptwidget preview PACKAGE` validates and compiles a Package 2.0 snapshot, packs it, and opens the public Web Studio with a bounded ZIP in `#sw-preview=v1.<base64url>`. The CLI never executes widget code for this command. `--no-open` returns the same link without launching a browser.

The browser consumes/removes the fragment, validates the archive/manifest, then creates a separate project and runs the existing sandboxed mock preview. It waits for project initialization and handles both cold startup and same-document hash navigation. Reload does not import again; failures preserve existing projects. Native fixtures are not transferred. URLs contain package content and should be treated as private. Capacity is 45,000 compressed ZIP bytes; oversize errors do not drop resources or upload anything.

## Verification

- CLI: 16 smoke tests passed, including validated handoff without execution, exact ZIP/source payload, malformed source rejection, explicit size limits, native images, sandbox/path boundaries and deadlines.
- Web: 101 unit tests passed, including Unicode/binary roundtrip, early fragment removal, unsupported version/encoding, invalid manifest and traversal rejection.
- Browser handoff smoke passed using both browser-generated and native-CLI-generated archives: automatic import/render, existing project preservation, reload, malformed-link recovery and cold startup.
- Cross-browser suite passed in local Chromium and WebKit, including import of a committed native DEFLATE fixture. Local Firefox could not start its automation profile (`Could not find profile folder`); this is not reported as a pass. Linux/Windows browser CI covers Firefox separately.
- Website home and Creator guide were captured at desktop and 390-pixel mobile widths; no horizontal overflow was found and screenshots were inspected.
- Release-readiness completed editor/catalog checks, Web tests/build/UI smokes, runtime/service/storage probes, both App builds and macOS tests (703 passed, 32 skipped, zero failures). The default iOS simulator destination stalled before execution; that invocation was stopped, and the same suite passed on a newly created iOS 27 simulator with parallel testing disabled (709 passed, 31 skipped, zero failures). The shell invocation itself is not reported as a successful end-to-end run. The test-only simulator was removed after completion.
- Existing remote App editor CI instability is documented in [CLI release evidence](cli-0.1.0-validation.md). This feature changes the separate CLI/Web tooling, not native App sources.

## Visual evidence

[Website before](images/creator-home-before.png) · [Website after](images/creator-home-after.png) · [Creator guide on mobile](images/creator-guide-mobile.png) · [Automatically loaded preview](images/creator-preview-loaded.png)

## Publication receipts

- [Merged PR #64](https://github.com/everettjf/scriptwidget/pull/64), merge commit `bb2b989cb7dd208e098e44b651f35a9ce5c04ae7`.
- [Native CLI CI passed](https://github.com/everettjf/scriptwidget/actions/runs/40068690105).
- [Linux and Windows browser CI passed](https://github.com/everettjf/scriptwidget/actions/runs/40068690102), including Chromium, Firefox and WebKit handoff tests with a native DEFLATE package.
- [Editor/catalog CI passed](https://github.com/everettjf/scriptwidget/actions/runs/40068690106); its independent full Apple-platform job was still running at publication, so no remote full-App gate success is claimed.
- [Website deployment passed](https://github.com/everettjf/scriptwidget/actions/runs/40069059017). Both the home page and `/creator/` page were checked live.
- [CLI/Skill 0.2.0 published](https://github.com/everettjf/scriptwidget/releases/tag/cli-v0.2.0); signed source commit `7843bcfaf5fa07603e12c93761f48afb8008d1e0`. Both architecture archives passed 16 smoke tests, Apple notarization and extracted ticket/signature checks. Intel runs used Rosetta rather than separate Intel hardware.
- Homebrew tap updated in commit `25d0e6c`; actual public-asset upgrade and `brew test` passed. Installed arm64 binary passed all 16 smoke tests, codesign, Gatekeeper Notarized Developer ID assessment and stapler validation.
- The published Skill ZIP was downloaded, checksum-verified, extracted and validated; it contains the automatic preview workflow.
- Production browser acceptance passed using the signed CLI's own URL: automatic import/render, source/helper/binary resources, preserved projects, malformed links, reload and cold startup.
- The installed CLI's default `preview` command actually opened the user's default Chrome. Accessibility state and a screenshot confirmed the new project, helper/resource files, rendered text, cleared URL fragment and no Problems. Its JSON report contained no package-bearing URL and did not falsely certify native execution/rendering.
