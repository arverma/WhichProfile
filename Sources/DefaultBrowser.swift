import AppKit

/// True if this app is the one macOS opens web links with.
func isDefaultBrowser() -> Bool {
    guard let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) else { return false }
    return handler.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
}

/// Asks macOS to make this app the handler for http and https links. macOS shows its own
/// confirmation dialog; `completion` runs on the main queue once both requests have finished.
func makeDefaultBrowser(completion: @escaping () -> Void) {
    let group = DispatchGroup()
    for scheme in ["http", "https"] {
        group.enter()
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme) { error in
            if let error = error { log("could not set default browser for \(scheme): \(error.localizedDescription)") }
            group.leave()
        }
    }
    group.notify(queue: .main, execute: completion)
}
