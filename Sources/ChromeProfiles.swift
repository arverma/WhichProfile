import Foundation

/// Chrome stores its profile list in `Local State` under `profile.info_cache`,
/// keyed by profile directory name.
let chromeLocalStatePath = NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Local State"

/// Parses the contents of Chrome's `Local State` file into profiles.
/// Order: "Default" first, then "Profile N" by N, then anything else alphabetically.
func parseLocalState(_ data: Data) -> [Profile] {
    guard
        let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let profile = root["profile"] as? [String: Any],
        let cache = profile["info_cache"] as? [String: Any]
    else { return [] }

    let profiles = cache.map { dir, value -> Profile in
        let info = value as? [String: Any]
        let name = (info?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? dir
        return Profile(dir: dir, name: name)
    }
    return profiles.sorted { profileSortKey($0.dir) < profileSortKey($1.dir) }
}

private func profileSortKey(_ dir: String) -> String {
    if dir == "Default" { return "0" }
    if dir.hasPrefix("Profile "), let n = Int(dir.dropFirst("Profile ".count)) {
        return "1" + String(format: "%08d", n)
    }
    return "2" + dir.lowercased()
}

/// Reads the installed Chrome's profiles, or nil if the file can't be read or has none.
/// On recent macOS versions other apps' data folders are protected, so this commonly fails
/// unless the app has been granted Full Disk Access; see `resolveProfiles`.
func loadChromeProfiles(path: String = chromeLocalStatePath) -> [Profile]? {
    guard let data = FileManager.default.contents(atPath: path) else {
        log("could not read Chrome Local State at \(path)")
        return nil
    }
    let profiles = parseLocalState(data)
    if profiles.isEmpty {
        log("no profiles found in Chrome Local State")
        return nil
    }
    return profiles
}
