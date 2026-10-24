# CLI 0.2 / report v1

Install through the project's Homebrew tap:

```sh
brew install everettjf/tap/scriptwidget-cli
```

The Mac application continues to be distributed through the Mac App Store. The CLI is independent, uses macOS 26+ and needs a logged-in graphical session for native screenshots. It does not need a separate model or inference server.

`check` compiles package JS/JSX without executing user scripts. `render` checks, executes with isolated mocks and writes new light/dark PNGs and report.json into a unique run directory. `pack` requires a valid Package 2.0 manifest and produces a .swt without executing scripts. Outputs must be outside the package; existing archives are never overwritten. Native preview families are small, medium and large.

Use `--format json`; stdout is a single report and progress is on stderr. Exit 0 means the requested stages completed; 1 means widget/fixture validation failed; 2 means usage or environment failure; 3 means internal worker failure; 124 means overall timeout; 130 means cancellation. Inspect the concrete diagnostics before retrying.

Fixtures remain external to the package. Start with an empty object to use versioned offline sample data. Override API replies with exactly one of value/error:

```json
{
  "api": {
    "$device.battery": {"value": {"level":0.75,"state":"unplugged"}},
    "$location.current": {"error":"Location permission denied"}
  },
  "storage": {"habit.count":"7"},
  "fetch": [{"url":"https://api.example.com/data","method":"GET","body":"{\"count\":42}"}]
}
```

The manifest must still declare the matching permissions/domains. Unknown API IDs, malformed replies and unsupported fixture sections fail explicitly. Without an HTTP fixture, requests fail offline. Data Source Plugin execution is not available in native CLI 0.1; use the Web preview for that mock scenario and describe the difference. API mock values can simulate capabilities unavailable on a real Mac; reports must be treated as synthetic data.

Offline API replies validate manifest permissions and fixture structure. They do not certify real system-query argument semantics; calls with arguments produce a `mock.arguments_not_validated` warning. Test real API queries separately in the App. Remote image previews require a matching fetch fixture whose body is a data-image URL; otherwise an explicit warning accompanies the placeholder.

`scriptwidget preview PACKAGE --format json` validates/compiles and opens the public Web Studio with a complete package in a URL fragment. `--no-open` returns the link without launching. Backend `web-handoff` never claims execution or rendering passed. Maximum compressed archive size is 45,000 bytes; no resources are silently omitted. The link contains package content and must be treated as private. The Studio creates a new project and removes the fragment before importing. No upload server is involved; browser mock data remains separate from native fixtures.
