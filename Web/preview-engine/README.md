# ScriptWidget preview engine

Executes ScriptWidget Package 2.0 widgets outside Apple platforms and produces
the same resolved element tree as the native JavaScriptCore runtime. See
[docs/browser-preview-engine.md](../../docs/browser-preview-engine.md).

```bash
npm test                          # contract, kernel, and corpus parity tests
node scripts/build-browser.mjs    # dist/ for the browser demo at /demo/
```

No dependencies. The Babel bundle and support scripts are read from
`Shared/ScriptWidgetRuntime/Widget/Resource/support.bundle`.
