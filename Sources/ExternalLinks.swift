import AppKit

/// Bundle identifiers of browsers to use for the app's own links, in order of preference.
let externalBrowserIdentifiers = ["com.google.Chrome", "com.apple.Safari"]

/// Picks the first installed browser from `externalBrowserIdentifiers`. `lookup` maps a bundle
/// identifier to the app's location, or nil if it isn't installed.
func chooseExternalBrowser(lookup: (String) -> URL?) -> URL? {
    for identifier in externalBrowserIdentifiers {
        if let url = lookup(identifier) { return url }
    }
    return nil
}

/// Opens a link from the app's own windows or menus (About, Help) in a real browser.
///
/// WhichProfile is normally the default browser, so handing such a link to the system would send
/// it straight back to this app, which would show its own picker and then quit. Naming a browser
/// explicitly avoids that loop.
func openExternalLink(_ url: URL) {
    let workspace = NSWorkspace.shared
    guard let browser = chooseExternalBrowser(lookup: { workspace.urlForApplication(withBundleIdentifier: $0) }) else {
        log("no Chrome or Safari found for \(url.host ?? "link"); falling back to the default handler")
        workspace.open(url)
        return
    }
    workspace.open([url], withApplicationAt: browser, configuration: NSWorkspace.OpenConfiguration()) { _, error in
        if let error = error { log("could not open an external link: \(error.localizedDescription)") }
    }
}
