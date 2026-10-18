# Web Studio in the browser

Design ScriptWidget widgets on Windows, macOS, Linux, or iPad in any modern
browser, see an instant preview, and install the result on iPhone. No Mac,
Xcode, or connected device is needed while you work.

Open it from the ScriptWidget site (`/studio/`) or run it locally:

```bash
cd Web/studio && npm ci && npm run dev
```

This is different from [Web Studio on iPhone](web-studio.md), where the browser
edits files that live on a paired iPhone. The browser Studio keeps projects in
the browser and previews them itself.

## Create and edit

- **New** starts a blank Package 2.0 project. **Templates** starts from any of
  the 70 bundled templates or the Gallery. **Import** opens a `.swt` or `.zip`.
- The file list shows `widget.json`, the entry file, extra scripts for
  `$import`, and images under `image/`. **Add image…** uploads PNG, JPEG, WebP,
  or GIF files (up to 8 MB) for `<image id="name" />` and `<gif file="name" />`.
- The editor has ScriptWidget completions, hover help, and diagnostics.
- Projects are saved in this browser automatically. Clearing site data removes
  them, so export a `.swt` to keep a copy.

## Preview

- Choose a device (iPhone sizes, iPad, or Mac), a widget size from the manifest's
  `supportedFamilies`, light or dark appearance, a rendering mode, and the
  `widget-param` value.
- The preview runs your code in an isolated sandbox with the same rules as the
  iPhone runtime: the same compiler, limits, `$render` behavior, and error
  categories. It renders with layout calibrated against iOS.
- **Problems** lists runtime errors, manifest validation, and preview notes
  (for example, an SF Symbol drawn with a look-alike icon, or a property the
  iPhone runtime ignores). **Console** shows `console.log` output. **Package**
  summarizes the manifest. **Fixtures** maps URLs to responses.
- The web preview never uses the network. `fetch` and `$http` read the
  **Fixtures** JSON; location and health need fixtures too. Fixtures stay in
  the browser and are not exported.

The browser preview is fast feedback, not a pixel-perfect WidgetKit render.
On Windows and Linux the Studio uses the bundled Inter font in place of SF
Pro, so text can wrap slightly differently, and WidgetKit controls the final
look, refresh, and interactions. Always check the widget on iPhone before
sharing it. See [browser preview coverage](browser-preview-coverage.md) for
what is supported, approximated, or not yet rendered.

## Install on iPhone

1. Fix any errors in **Problems**; export is blocked until `widget.json` passes
   Package 2.0 validation.
2. Tap or click **Install on iPhone**.
   - In Safari on iPhone, the share sheet opens: choose **ScriptWidget**.
   - On a computer, the `.swt` file downloads. Send it to the iPhone with
     AirDrop, iCloud Drive, or email, open it, tap **Share**, and choose
     **ScriptWidget**.
3. Review the permissions, then add the widget to the Home Screen.

**Export .swt** downloads the same file without the instructions.

## For coding agents

The same engine is available from the command line and as an MCP server, so
Claude Code, Codex, and other agents can edit a package and check the result
without a browser:

```bash
node Web/preview-engine/bin/scriptwidget-preview.mjs MyWidget --family small --output preview.png --diagnostics preview.json
```

```bash
claude mcp add scriptwidget -- node Web/preview-engine/bin/scriptwidget-mcp.mjs
```

Both need Chrome or Chromium (`CHROME_PATH` overrides the location). Every
result includes the package's source hash so a stale image cannot be mistaken
for the latest edit. With `--device` and `--pair-code`, the CLI also uploads
the package to an iPhone running Web Studio and saves the native preview next
to the web one. Details are in [browser preview engine](browser-preview-engine.md).

## Supported browsers

Every change to the web code is checked in Chromium, Firefox, and WebKit on
Linux and Windows (the Web Browsers workflow), and the engine is also checked
in Safari on iOS. Use a current version of Chrome, Edge, Firefox, or Safari.

## Development

Web Studio is a React 19 app in strict TypeScript, built with Vite 7,
Tailwind CSS 4, and shadcn/ui components on Radix primitives. CodeMirror 6
is the editor; the widget preview comes from `Web/preview-engine`.

```bash
cd Web/studio && npm install
```

```bash
npm run dev
```

`npm test` runs the project helper tests, `npm run build` typechecks and
builds `dist/`, and `node scripts/smoke.ts` checks the built site in headless
Chrome. Add shadcn components with `npx shadcn@latest add <name>`; they are
copied into `src/components/ui` and import `cn` from `@/lib/utils`.

## Privacy and security

- Your code runs in a sandboxed frame with an opaque origin and no network
  access; it cannot read the Studio page, your projects, or other sites.
- Projects, images, and fixtures stay in your browser. The Studio has no
  server-side storage and sends nothing anywhere.
- Imported `.swt` files are checked with the same archive limits as the iPhone
  app (size, entry count, paths, symlinks), and a malformed `widget.json` is
  rejected rather than reinterpreted.
