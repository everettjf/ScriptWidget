---
name: scriptwidget-author
description: Create or edit ScriptWidget JavaScript/JSX widget packages, validate them with the ScriptWidget CLI, and inspect native preview images. Use for ScriptWidget widgets and package fixes; not for React web apps or other widget frameworks.
---

# Author ScriptWidget packages

Use the user's Coding Agent and model. ScriptWidget supplies the runtime contract and verification tools; this skill does not grant permissions, install dependencies or connect accounts.

## Before editing

Read [authoring](references/authoring.md) for the JSX dialect and a working starting point. For a specific tag or API, search [runtime API](references/runtime-api.md); read only the relevant section. Read [package format](references/package-format.md) when changing manifests, permissions, imports or resources. The included references target runtime API 1.4.

Keep work in a separate package directory. Preserve the user's existing files and package identity when editing. Prefer `widget.json` and `main.jsx` for new work. Never replace an invalid present manifest with a legacy package.

## Generate, check, preview, repair

1. Discover `scriptwidget --version --format json` and `scriptwidget doctor --format json`. Use CLI 0.1.x/report v1. If unavailable, explain the dependency and provide the documented Homebrew command; do not install without the user's authorization.
2. Create or modify the package using native ScriptWidget JSX and documented APIs. Use package-relative resources, minimum permissions and declared network domains. Do not embed credentials or assume access to real system data.
3. Run `scriptwidget check PACKAGE --format json`. Read the diagnostics; fix actual errors before rendering. A successful static check is not an execution result.
4. Run `scriptwidget render PACKAGE --family medium --appearance both --output OUTPUT --format json`, choosing a declared small/medium/large family. OUTPUT must be outside PACKAGE. Optional mock data uses `--fixtures fixtures.json`.
5. Read the current report and inspect both PNGs when image viewing is available. Check labels, values, clipping, contrast, density and requested behavior. Verify source hashes and artifact paths belong to the latest run. Never use a previous successful screenshot after a failed edit.
6. Repair and rerun the affected checks. Stop after three unsuccessful repair attempts and explain the remaining concrete error; do not weaken runtime limits or hide warnings to make a result pass.
7. Once the requested behavior is reviewed, run `scriptwidget pack PACKAGE --output OUTPUT/Widget.swt --format json` if the user wants an installable package. Packing does not install or modify App data. Let the user import it through the existing ScriptWidget app.

The CLI runs locally without the App, Node or Chrome, and uses offline mocks for system/network APIs. Real authorization, server availability, persistent real records and WidgetKit behavior require separate acceptance. The native PNG is a macOS SwiftUI snapshot, not a certificate of iPhone or desktop WidgetKit correctness.

## Interpret results precisely

Read [CLI behavior and mocks](references/cli.md). Distinguish package/compile/execute/render/export; `notRun` is not passed. Keep warnings and known unsupported APIs visible. Native CLI currently accepts `api`, `fetch` and string-valued `storage` fixtures. Data Source Plugin execution and browser-specific fixture sections are explicitly unsupported; report this instead of inventing a success.

When the model cannot view images, report that limitation and give the user the preview paths. When using the Web Studio instead, label it a browser approximation with mock data. It is available at https://xnu.app/scriptwidget/studio/ and does not require uploading code to an execution server.
