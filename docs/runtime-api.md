# ScriptWidget runtime API 1.1

The public JavaScript/JSX host contract is versioned independently from the app. Scripts can read `$runtime.apiVersion` and must feature-detect optional device capabilities.

## Global API

Version 1.1 adds `$xml` to the 1.0 globals: `$component`, `$console`, `$dataSource`, `$device`, `$dynamic_island`, `$element`, `$error`, `$fetch`, `$file`, `$getenv`, `$health`, `$http`, `$import`, `$location`, `$render`, `$runtime`, `$storage`, `$system`, `console`, and `fetch`.

`$dataSource.request(pluginID, operationID, parameters)` calls an installed declarative connector. It is available only to Package 2.0 widgets that declare the plugin identifier, `network` permission, and the connector host. See [Data Source Plugins](data-source-plugins.md).

Removing or changing the meaning of a 1.0 global requires a new major API version. Additive properties may ship in a minor version.

### Built-in text and data handling

JavaScript already provides `String.prototype.includes`, `indexOf`, `match`, and `replace` for text search, plus `JSON.parse` and `JSON.stringify` for JSON. `$json(value)` remains a shorthand for `JSON.stringify(value)` when a JSX property needs a JSON string.

`$xml.parse(source)` parses an XML string into a node with `name`, `attributes`, `text`, and `children`. `text` contains only direct text in that node; child text stays in its child node. Whitespace is preserved. The result is a plain JavaScript object, not a DOM or XPath interface.

```jsx
const feed = $xml.parse('<feed><title>News</title></feed>');
const title = feed.children.find(child => child.name === 'title')?.text ?? 'Untitled';
$render(<text>{title}</text>);
```

XML input is limited to 256 KiB, 2,048 elements, 32 levels, and 256 KiB of decoded text. DTDs and entity declarations are rejected, and external entities are never resolved. Invalid or oversized XML throws an `Error`. This parser requires no package permission and cannot read files or make network requests. Package 2.0 network permissions still apply when the XML comes from a URL.

## Resource limits

- Source text: 512 KiB per execution.
- Transpiled JavaScript: 2 MiB per execution.
- Execution: 5 seconds, including unresolved asynchronous work.

Limits are available under `$runtime.limits`. Exceeding one produces a visible resource-limit error instead of a blank widget. Widget extensions remain subject to stricter operating-system CPU and memory budgets.

Bundled templates are contract-tested against the source limit. New examples must keep `main.jsx` UTF-8 encoded and runnable without undocumented globals.

## Frame and appearance

A finite, nonnegative numeric `frame` or a numeric string sets a square size: `frame={64}` and `frame="64"` both mean 64 × 64 points. Existing `frame="64,48"`, `frame="max"`, and alignment forms remain supported. Leave space around stroked shapes for their line width.

`$device.isdarkmode()` uses the appearance captured when its runtime is created, so JavaScript worker threads preserve the rendering context's light/dark choice. On macOS this resolves the native drawing appearance instead of always reporting dark mode.
