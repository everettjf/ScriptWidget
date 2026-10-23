# Control Switch

Install this package to get one local persistent flag, `switch.enabled`. It is not a system Focus mode, network appliance or device setting. It requests storage only. The widget Toggle, the ScriptWidget control-center toggle and Shortcuts use the same declared action and package installation identity.

In Shortcuts, select **Run ScriptWidget Action**, then Toggle local switch, Turn local switch on, or Turn local switch off. In Control Center, add a ScriptWidget toggle and choose Local switch from this installation. Explicit toggle values are idempotent: setting true twice stays true rather than toggling twice. Writes use bounded compare-and-set retries. Actions request ordinary widget and compatible control reloads; the system decides when to render them.

Rendering never writes a fake initial value. An unset flag displays Off. The flag survives reopening with the same installed package, is isolated from other installations and is not inherited by deleting/reinstalling the same name. Read-only template previews cannot execute actions. The bundled On preview uses a synthetic isolated fixture.

This developer example does not use the native daily-record backup format. Exporting the script package exports code, not its local storage flag. Use an explicit data-export feature in a project if the flag needs a portable backup. Widget interactivity, Control Center availability, Shortcuts discovery and real cross-process execution still require appropriate OS versions and signed-device acceptance.
