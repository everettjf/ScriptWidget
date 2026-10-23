# Music Playback

Shows a snapshot of the **iOS Music app**, using `$music.current()` from Runtime API 1.4. Install the widget and allow Music access in ScriptWidget Settings. The package declares `music`; it does not need network access.

Web Studio supplies editable samples. Choose Music playback in Mock Data to simulate playing, paused, stopped, withheld track details, denied permission or an unavailable platform. Samples stay in your browser project and are not exported.

The public system-player API is unavailable on macOS. Other audio apps are outside its scope. Home Sharing can withhold track details even while playback continues. Duration and position can be null. Playback is a snapshot at render time, rather than a continuously running progress display. There are no playback controls, queue changes, artwork requests or library scans in this template.

The native adapter compiles for iOS app and widget targets. Real Music authorization and widget-extension behavior still require signed-device validation; automated native tests use an injected provider and never read your music.
