# Quick Launcher

Install the complete template. Open Records & Configuration to save a title, accent and one to six ordered links. Each link can be a web URL, an external app URL or the name of a saved Shortcut with optional text input. Add/remove/reorder links, then Save Configuration. Test Draft Link opens the unsaved draft only when you press it.

Web URLs must be absolute HTTP(S), without embedded credentials or spaces. App links require an external URL scheme; script/data/file/internal/settings schemes are not accepted by this template. Installing an app or a matching shortcut is the user's responsibility. Shortcut names and text are encoded as query data so ampersands, plus signs and Unicode cannot introduce extra parameters. It never reads the clipboard, lists shortcuts or executes a shortcut while rendering.

The native test button reports whether the system accepted the URL. Acceptance does not prove that a shortcut or target-app operation completed; confirm in the destination app. Widget links use the system directly. When the containing app receives a forwarded URL, it opens external links and reports missing handlers without logging full URLs. System routing varies by OS/version; the manual device checklist remains required.

Compact and accessory families prioritize the first link, medium shows the first three, and larger families show up to six. Move Up/Down controls which links appear first. The root widget URL falls back to the first item; larger-family link tiles open their individual destinations. The saved title, ordered links and optional shortcut input are included in explicit record backups, so treat those backups as personal data. Total configuration is limited to 32 KiB; links use stable IDs and do not change the package's runtime permissions. This package requests storage only and does not fetch the URL while rendering.

Optional instance parameter: a JSON object overriding `title`, `accent` or the complete `items` list. Each item contains exactly `id`, `title`, `icon`, `type`, `target`, `input`; use the native form for a valid example. Old manually edited launcher projects are not rewritten by this new bundled template.

Apple's Shortcuts URL documentation: https://support.apple.com/guide/shortcuts/apd624386f42/ios and https://support.apple.com/guide/shortcuts-mac/apd624386f42/mac.
