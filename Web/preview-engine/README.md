# ScriptWidget preview engine

Executes ScriptWidget Package 2.0 widgets outside Apple platforms, produces
the same resolved element tree as the native JavaScriptCore runtime, and
renders it with SwiftUI-style layout. See
[docs/browser-preview-engine.md](../../docs/browser-preview-engine.md).

```bash
npm test          # contract, kernel, corpus parity, renderer, and coverage tests
npm run build     # dist/ for /demo/index.html (isolation check) and /demo/preview.html
npm run compare   # headless Chrome vs native iOS snapshots in dist/native-snapshots
npm run coverage  # regenerate docs/browser-preview-coverage.md
```

No dependencies. The Babel bundle and support scripts are read from
`Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle`.

Connected-service fixtures keep GitHub responses in the legacy `apis` entries;
Spotify responses use `services.spotify.status` and `services.spotify.profile`
with a single `value` or `error` per response. Missing Spotify fixtures remain
unavailable. Profiles contain only the public eight-field DTO; unsupported
Spotify username/count fields must be null. Fixtures never contain credentials
and do not bypass manifest permissions, declared hosts or execution budgets.
Spotify playback uses `services.spotify.playback` and a separate boolean
`playbackGranted`. Its ten-field snapshot or null never represents a live
player; no device identifiers or arbitrary provider URLs are accepted.
