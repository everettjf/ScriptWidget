# ScriptWidget Package 2.0

A ScriptWidget project is a directory whose authoritative metadata lives in `widget.json`. Exported projects use the `.swt` extension, but the file is a ZIP archive so it can be inspected with standard tools.

## Minimal project

```text
My Widget/
├── widget.json
└── main.jsx
```

```json
{
  "entry": "main.jsx",
  "formatVersion": 2,
  "id": "com.example.my-widget",
  "name": "My Widget",
  "networkDomains": [],
  "permissions": [],
  "plugins": [],
  "runtimeVersion": "1.0",
  "supportedFamilies": ["systemSmall", "systemMedium", "systemLarge"],
  "version": "1.0.0"
}
```

The machine-readable contract is [`widget.schema.json`](../Shared/ScriptWidgetRuntime/Resource/widget.schema.json). Unknown fields are rejected by the schema so typos do not silently change a package's security declaration.

## Fields

- `formatVersion`: package contract version; currently exactly `2`.
- `id`: stable reverse-DNS-style identifier, 3–128 characters.
- `name`: human-readable project name, 1–80 Unicode grapheme clusters and at most 240 UTF-8 bytes. Chinese names and joined emoji are supported. Names cannot start with a dot, equal `__Build` (case insensitive), contain path separators or control characters (except ZWNJ/ZWJ), or begin with a Windows drive prefix. Installed directory names must also be unambiguous after case folding and Unicode normalization. JSON Schema provides a conservative scalar bound; native/Web semantic validators enforce the grapheme and UTF-8 limits.
- `version`: semantic version such as `1.2.0` or `1.2.0-beta.1`.
- `runtimeVersion`: Package 2.0 compiler/runtime ABI; currently exactly `1.0`.
- `minimumRuntimeVersion`: optional minimum native public API version, such as `1.3`. Omit it for the 1.0 baseline. Only canonical `major.minor` strings are accepted; incompatible major versions and newer minor requirements fail closed. This field does not change the Package 2.0 ABI. Older readers reject the new field instead of silently ignoring it.
- `entry`: a relative `.js` or `.jsx` file inside the package.
- `supportedFamilies`: one or more WidgetKit families.
  iOS, iPadOS, and macOS 27 add `systemExtraLargePortrait`; packages may
  include it while retaining other families as fallbacks on older systems.
- `actions`: up to sixteen reusable script actions. Each action declares a
  stable `id`, title, SF Symbol `systemImage`, and JavaScript `function` in the
  package entry file. The same action can be selected in Siri and Shortcuts,
  referenced by Widget `<button actionID="…">` / `<toggle actionID="…">`, and
  reused by a Control Widget.
- `controls`: up to eight declarative Control Center buttons or toggles. Each
  control declares a stable `id`, an SF Symbol `systemImage`, and a JavaScript
  `actionID`. The legacy direct `action` function remains readable for existing
  manifests, but it cannot be combined with `actionID`. Toggles also require
  `stateKey` and the `storage`
  permission; the new value is available to the action as
  `$getenv("control-value")`.
- `pushUpdates`: optional self-hosted WidgetKit push registration. The object
  contains an HTTPS `registrationURL` on a declared `networkDomains` host and a
  non-secret `channel`. ScriptWidget posts the WidgetKit token, package ID, and
  channel when the token changes; packages never receive the token in JSX.
- `permissions`: declared capabilities: `network`, `location`, `health`, `calendar`, `reminders`, `remindersWrite`, `photos`, `storage`, or `files`.
- `networkDomains`: lowercase host allowlist. It requires `network`; use exact hosts or a leading wildcard such as `*.example.com`.
- `plugins`: optional Data Source Plugin identifiers. Every data-source request also requires `network` and a matching `networkDomains` entry.
- Optional discovery fields: `description`, `category`, `tags`, `icon`, `preview`, `author`, and `license`.

The Mac Studio Config panel edits and validates these values before saving. New blank projects get a manifest automatically; source, optional images and the manifest are prepared before atomic publication, so failed creation leaves no partial package. Saving an existing package rejects a present invalid manifest before changing its main file. Installing, remixing or editing a manifestless legacy template preserves its format and existing permission behavior; it does not invent an empty permission list. Remixing an existing Package 2.0 widget refreshes its manifest ID and name while preserving its declarations and resources. A legacy package containing `main.jsx` and optional `meta.json` is migrated when it is imported or exported.

## Reusable actions

Action calls receive a consistent environment on every system surface:

- `action-id`: the declared action identifier;
- `action-source`: `widget`, `control`, or `shortcut` (including Siri calls);
- `action-value`: `true` or `false` when a toggle supplies a value.

Control Widget calls additionally preserve `control-id` and `control-value` for
compatibility. Toggle state is stored under the package namespace before its
action runs; packages must declare the `storage` permission. A malformed
present manifest, missing action reference, unsafe state key, or undeclared
storage permission fails closed instead of invoking a legacy function.

## Import security

ScriptWidget treats every imported `.swt` as untrusted. Before extraction it checks the ZIP central directory and rejects:

- absolute paths, `..` traversal, backslashes, drive-style paths, invalid UTF-8, and excessive nesting;
- symbolic links, encrypted entries, multi-disk archives, malformed ZIP64 metadata, and unsupported compression methods;
- archives over 32 MiB, more than 500 entries, a file over 25 MiB, or more than 64 MiB expanded;
- malformed central directories and suspicious zero-byte compression claims.

Extraction uses a unique temporary directory that is removed after every attempt. The extracted tree is checked again before copying. The archive filename does not control the installed project directory; the validated manifest name does.

Permission declarations are surfaced for review during import and enforced by the Package 2.0 runtime. Generic network calls require `network`, use public HTTP(S) endpoints, and must match `networkDomains`; Data Source Plugin mappings remain HTTPS-only. Legacy packages remain compatible but do not gain access to the new plugin, Calendar or Reminders APIs. The additive `calendar` declaration enables read-only `$calendar` calls after system approval; it does not enable event writes. Older readers reject the unknown permission rather than silently running the package without it. See [Calendar API](calendar-api.md). The additive `reminders` declaration enables read-only `$reminders` calls within native Settings list selection. `remindersWrite` additionally permits explicit declared user actions to create, update or set completion after native identity, source scope and durable replay checks; rendering cannot write. see [Reminders API](reminders-api.md).

## Compatibility

`meta.json` remains readable for bundled and existing projects. Package 2.0 makes `widget.json` authoritative when both exist. A package requiring an unknown format or runtime is rejected instead of being opened with undefined behavior.


Before compiling or running a package, native widget rendering, Dynamic Island rendering and action execution validate a present manifest, including its minimum API requirement. Preview compilation does the same. The package file takes precedence over any host-provided manifest object; a malformed or incompatible present file is never treated as a legacy package. Legacy projects without `widget.json` keep their existing execution behavior.

A minimum version is an availability floor, not a permission grant. Declare the permissions required by the selected APIs separately, and obtain system approval in the application where needed. See the [data API catalog](data-api-catalog.md) for per-method availability. Calendar packages should declare `minimumRuntimeVersion: "1.3"`; Reminders APIs require `"1.4"`.

Runtime 1.3 adds optional `timeline` with 1–4 sorted `dailyTimes` and an optional IANA `timeZone`. It does not grant capabilities or change the execution clock. See [scheduled widget states](timeline-api.md) for DST behavior, projections and resource limits.


Package file access uses package-relative paths (at most 16 components, each at most 255 UTF-8 bytes). Reads and atomic writes reject links, multiply linked regular files, special files, and case aliases. Individual resource reads/writes are bounded to 25 MiB; metadata has its stricter 256 KiB limit. A present `Widget.json` or other incorrectly cased manifest is rejected rather than treated as a legacy package. Nested source and resource folders remain supported. These checks supplement archive validation; they do not grant package permissions.

## Native previews and personal data

An uninstalled native Gallery, template or AI trial preview uses a read-only package and fresh in-memory `$storage`. It cannot request or query personal calendar, reminders, location or Health data, even if the app already has system authorization. These APIs report unavailable in that preview and reject queries with `permission_denied`; install the widget, declare the capability and grant the relevant system access to use real data. AI trial runs do not retain records between executions.

Installed widgets execute from a frozen, read-only copy of their package, but retain their native installation identity, records and declared capabilities. This execution copy is not an uninstalled preview. Package 2.0 Health queries require `health`; genuine legacy scripts retain their existing authorization behavior. HealthKit read grants remain undisclosed.

Web Studio uses illustrative, editable Mock Data rather than querying the device's personal stores. A successful browser preview does not establish native system authorization.

### Native compiled fallback

Activated native libraries keep compiled output in their private storage profile, separately from authored package files. Each atomic cache entry records its installation owner, manifest policy hash, compiler contract, source hash and compiled-output hash. A later source syntax error can use the last valid output only while that installation and policy remain valid. Reinstalling a same-named widget or switching libraries invalidates the previous installation's cache access.

The cache uses 32 fixed slots, with a 2 MiB compiled-code limit and the storage metadata frame limit per slot. Collisions evict cached output and cause recompilation; they never select another installation's output. Unsaved editor overrides and uninstalled previews do not publish this cache. Source files remain authoritative, and cached output is disposable.

The additive `photos` declaration enables bounded JPEG thumbnail reads only from the photos/albums explicitly selected in native Settings. Missing native selection allows none; system limited access is supported. Rendering cannot modify the library. See [Photos API](photos-api.md).
