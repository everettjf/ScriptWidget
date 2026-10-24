# Creator preview delivery — CLI 0.2.0

`scriptwidget preview PACKAGE` validates and compiles a Package 2.0 snapshot, packs it, and opens the public Web Studio with a bounded ZIP in `#sw-preview=v1.<base64url>`. The CLI never executes widget code for this command. `--no-open` returns the same link without launching a browser.

The browser consumes/removes the fragment, validates the archive/manifest, then creates a separate project and runs the existing sandboxed mock preview. It waits for project initialization and handles both cold startup and same-document hash navigation. Reload does not import again; failures preserve existing projects. Native fixtures are not transferred. URLs contain package content and should be treated as private. Capacity is 45,000 compressed ZIP bytes; oversize errors do not drop resources or upload anything.

## Verification

- CLI: 16 smoke tests passed, including validated handoff without execution, exact ZIP/source payload, malformed source rejection, explicit size limits, native images, sandbox/path boundaries and deadlines.
- Web: 101 unit tests passed, including Unicode/binary roundtrip, early fragment removal, unsupported version/encoding, invalid manifest and traversal rejection.
- Browser handoff smoke passed using both browser-generated and native-CLI-generated archives: automatic import/render, existing project preservation, reload, malformed-link recovery and cold startup.
- Cross-browser suite passed in local Chromium and WebKit, including import of a committed native DEFLATE fixture. Local Firefox could not start its automation profile (`Could not find profile folder`); this is not reported as a pass. Linux/Windows browser CI covers Firefox separately.
- Website home and Creator guide were captured at desktop and 390-pixel mobile widths; no horizontal overflow was found and screenshots were inspected.
- The full release-readiness gate is being run; final CI/release/deployment receipts follow publication. Existing App editor CI instability is documented in [CLI release evidence](cli-0.1.0-validation.md).

## Visual evidence

[Website before](images/creator-home-before.png) · [Website after](images/creator-home-after.png) · [Creator guide on mobile](images/creator-guide-mobile.png) · [Automatically loaded preview](images/creator-preview-loaded.png)
