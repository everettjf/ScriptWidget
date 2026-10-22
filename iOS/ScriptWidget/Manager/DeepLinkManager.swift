import Foundation
import UIKit

@MainActor
class DeepLinkManager {
    typealias Opener = @MainActor (URL, @escaping @MainActor @Sendable (Bool) -> Void) -> Void

    static func openDeepLink(url: URL, open: Opener = { url, completion in
        UIApplication.shared.open(url, options: [:]) { accepted in
            Task { @MainActor in completion(accepted) }
        }
    }, completion: @escaping @MainActor @Sendable (Bool) -> Void = { _ in }) {
        guard let scheme=url.scheme?.lowercased(),scheme != kDeepLinkDefaultScheme,scheme != "scriptwidget" else { return }
        // The system decides whether an installed app can handle this link.
        // Do not log full URLs: shortcut input or app links may contain personal text.
        open(url,completion)
    }
}
