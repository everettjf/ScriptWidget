# Use ScriptWidget with Claude Code

## Install the Skill

Install the Mac CLI, then copy its entire bundled Skill folder (including references) to Claude Code's personal skills directory:

```sh
brew install everettjf/tap/scriptwidget-cli
mkdir -p ~/.claude/skills
# First installation: stop rather than overwrite an existing personal Skill.
test ! -e ~/.claude/skills/scriptwidget-creator && cp -R "$(brew --prefix scriptwidget-cli)/libexec/ScriptWidgetCLI.app/Contents/Resources/scriptwidget-creator" ~/.claude/skills/
```

The resulting file must be `~/.claude/skills/scriptwidget-creator/SKILL.md`. If that folder already exists, review/back up your local modifications before replacing it. For a project-only installation, use `.claude/skills/scriptwidget-creator/` instead. Claude Code documents these locations in its [official Skill guide](https://code.claude.com/docs/en/skills).

Without Homebrew, download the [Skill ZIP](https://github.com/everettjf/scriptwidget/releases/download/cli-v0.1.2/scriptwidget-creator-0.1.2.zip), unzip it, and copy the entire `scriptwidget-creator` folder to the same location. Browser preview does not require the Mac CLI; native checks do.

In Claude Code, invoke:

```text
/scriptwidget-creator Create a medium reading habit widget. Use clearly labeled demo data for preview, validate it, show me the result, and export a .swt package.
```

The folder structure follows the documented discovery contract. This release has validated folder copying and Skill contents; it does not claim end-to-end discovery testing in every Claude Code version or managed configuration.

## Preview in Web Studio

1. Ask the Agent to export a `.swt` package (on Mac: `scriptwidget pack ./MyWidget --output ./artifacts/MyWidget.swt --format json`).
2. Open [Web Studio](https://xnu.app/scriptwidget/studio/).
3. Drag the `.swt` onto the page, or choose **Validate → Open .swt package**. For a single-file draft, **Validate** also accepts pasted JSX.
4. Inspect the preview and mock data. Download the current validation report when the Agent needs the browser diagnostics.

The current public Studio does not accept code/package payloads in a preview URL, and native CLI 0.1.2 has no `preview`/`open` browser command. Opening the homepage alone does not transfer the generated widget. A future one-click preview needs an explicit package handoff; do not invent a working deep link or upload user code without permission.

Mac native preview remains available through `scriptwidget render`; see the [CLI guide](mac-cli.md). Browser rendering is approximate and uses mock data.

## Import on iPhone/iPad

The device must have ScriptWidget installed. A Skill supplies authoring instructions; it does not install the iOS app.

- From Mac: send the exported `.swt` with AirDrop or iCloud Drive, then use the iOS share sheet to open it with ScriptWidget.
- From Web Studio on iPhone: choose **Install on iPhone**. When file sharing is supported, choose ScriptWidget in the share sheet. Otherwise save the downloaded `.swt` and share it from Files.
- Review the imported package and permissions. Add a ScriptWidget widget through the Home Screen widget gallery and select the imported package yourself. Importing a package does not place a widget on the Home Screen.

No App Store update is needed for this existing import workflow.

## Later: paired device delivery

The existing development-only [Node preview tool](browser-preview-engine.md) supports `--device` and `--pair-code`, using the App's manually started local [Web Studio server](web-studio.md). This is separate from the native Homebrew CLI. It requires the same trusted network, the App screen in the foreground, and an initial `.swt` import. It syncs text files into an existing editable package; binary resources are skipped, and revision conflicts must remain visible.

A future native `device` workflow should discover/pair with explicit user action, preview the target package and changes, transfer resources within existing limits, preserve revision checks and require confirmation before overwriting. Pairing credentials must stay local and out of Skills/logs/share links. Public Studio preview links and complete first-time device installation remain follow-up work, not shipped capabilities.
