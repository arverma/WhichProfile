import Foundation

/// A link after tracking parameters were removed, and the names of the parameters that went.
struct CleanedLink: Equatable {
    let url: URL
    let removed: [String]
}

/// Exact query parameter names that only record where a click came from. Anything starting with
/// `utm_` is also treated as tracking. The list is deliberately short: a parameter that might
/// carry meaning (`ref`, `id`, `token`, `si`…) is never removed.
let trackingParameterNames: Set<String> = [
    "fbclid", "gclid", "gbraid", "wbraid", "dclid", "msclkid", "yclid", "twclid", "ttclid",
    "igshid", "mc_eid", "mc_cid", "_hsenc", "_hsmi", "mkt_tok",
]

func isTrackingParameter(_ name: String) -> Bool {
    let lower = name.lowercased()
    return lower.hasPrefix("utm_") || trackingParameterNames.contains(lower)
}

/// Removes tracking parameters from an http(s) link. Only the query string is touched: the host,
/// path and fragment are kept as they were, and the parameters that stay keep their original
/// spelling and order (no re-encoding). Links with nothing to remove are returned unchanged.
func cleanLink(_ url: URL) -> CleanedLink {
    let unchanged = CleanedLink(url: url, removed: [])
    guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return unchanged }

    let text = url.absoluteString
    // Parameters after a `#` belong to the page (for example a single-page app route), not the server.
    let hash = text.firstIndex(of: "#")
    let beforeHash = hash.map { String(text[..<$0]) } ?? text
    let fragment = hash.map { String(text[$0...]) } ?? ""

    guard let question = beforeHash.firstIndex(of: "?") else { return unchanged }
    let base = String(beforeHash[..<question])
    let query = beforeHash[beforeHash.index(after: question)...]

    var kept: [Substring] = []
    var removed: [String] = []
    for pair in query.split(separator: "&", omittingEmptySubsequences: true) {
        let rawName = String(pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        let name = rawName.removingPercentEncoding ?? rawName
        if isTrackingParameter(name) { removed.append(name) } else { kept.append(pair) }
    }
    guard !removed.isEmpty else { return unchanged }

    let rebuilt = base + (kept.isEmpty ? "" : "?" + kept.joined(separator: "&")) + fragment
    guard let cleaned = URL(string: rebuilt) else { return unchanged }
    return CleanedLink(url: cleaned, removed: removed)
}

/// The link to actually open: cleaned when the user has that setting on.
func prepareLink(_ url: URL, config: Config) -> CleanedLink {
    config.cleanLinks ? cleanLink(url) : CleanedLink(url: url, removed: [])
}
