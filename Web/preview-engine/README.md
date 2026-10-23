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

Connected-service fixtures support GitHub profile reads through editable `apis`
entries. Unknown providers reject with `service_operation`. Fixtures contain no
credentials and cannot bypass manifest permissions, declared hosts or budgets.
