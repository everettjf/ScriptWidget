//
//  AppDelegate.swift
//  ScriptWidgetMac
//
//  Created by everettjf on 2022/1/14.
//

import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var openWidgetURL: (URL) -> Bool = { url in
        NSWorkspace.shared.open(url)
    }

    var reportUnavailableLink: () -> Void = {
        let alert=NSAlert();alert.messageText="Couldn’t Open Link"
        alert.informativeText="Check the link and make sure its target app is installed. Test saved launcher links in Records & Configuration."
        alert.addButton(withTitle:"OK");alert.runModal()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let scheme = url.scheme?.lowercased(),
                  scheme != kDeepLinkDefaultScheme,
                  scheme != kSpotifyAuthorizationCallbackScheme,
                  scheme != "scriptwidget" else { continue }
            if !openWidgetURL(url) { reportUnavailableLink() }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("did finish launching")
        // The embedded editor is served via a WKURLSchemeHandler — no
        // local HTTP server needed.
        precacheScripts()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        precacheScripts()
    }

    /// Proactively cache scripts locally while iCloud is reachable so widgets
    /// keep rendering if iCloud Drive later becomes unavailable (issue #6).
    private func precacheScripts() {
        DispatchQueue.global(qos: .utility).async {
            sharedScriptManager.precacheAllScripts()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
