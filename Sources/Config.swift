import Foundation

/// Optional user configuration, read from `~/.config/profile-picker/config.json`.
/// Every field is optional; with no file at all the picker lists every Chrome profile.
///
///     {
///       "profiles": [{ "dir": "Profile 3", "name": "Work" }],
///       "hidden": ["Profile 5"],
///       "order": ["Profile 3", "Default"],
///       "labels": { "Profile 3": "Work" },
///       "rememberLast": true
///     }
///
/// Keys are Chrome profile directory names (`Default`, `Profile 3`, ...).

/// A profile declared by hand in the config file.
struct ConfiguredProfile: Codable, Equatable {
    var dir: String
    var name: String?
}

struct Config: Codable, Equatable {
    /// When non-empty, replaces auto-detection entirely.
    var profiles: [ConfiguredProfile] = []
    var hidden: [String] = []
    var order: [String] = []
    var labels: [String: String] = [:]
    var rememberLast: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([ConfiguredProfile].self, forKey: .profiles) ?? []
        hidden = try c.decodeIfPresent([String].self, forKey: .hidden) ?? []
        order = try c.decodeIfPresent([String].self, forKey: .order) ?? []
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        rememberLast = try c.decodeIfPresent(Bool.self, forKey: .rememberLast) ?? true
    }
}

let configPath = NSHomeDirectory() + "/.config/profile-picker/config.json"

func loadConfig(path: String = configPath) -> Config {
    guard let data = FileManager.default.contents(atPath: path) else { return Config() }
    do {
        return try JSONDecoder().decode(Config.self, from: data)
    } catch {
        log("invalid config at \(path): \(error)")
        return Config()
    }
}

/// Chooses the base profile list: profiles declared in the config win, then auto-detection,
/// then a lone "Default" with a warning so the failure is visible rather than silent.
func resolveProfiles(config: Config, detect: () -> [Profile]?) -> (profiles: [Profile], warning: String?) {
    if !config.profiles.isEmpty {
        return (config.profiles.map { Profile(dir: $0.dir, name: $0.name ?? $0.dir) }, nil)
    }
    if let detected = detect() { return (detected, nil) }
    return ([Profile(dir: "Default", name: "Default")], "Can't read Chrome profiles. See README.")
}

/// Applies hiding, relabelling and ordering. Never returns an empty list:
/// if everything is hidden, the original list is returned so links can still be opened.
func arrange(_ profiles: [Profile], with config: Config) -> [Profile] {
    var result = profiles.filter { !config.hidden.contains($0.dir) }
    if result.isEmpty { result = profiles }

    for i in result.indices {
        if let label = config.labels[result[i].dir], !label.isEmpty { result[i].name = label }
    }

    var ordered: [Profile] = []
    for dir in config.order {
        if let p = result.first(where: { $0.dir == dir }), !ordered.contains(p) { ordered.append(p) }
    }
    ordered += result.filter { !ordered.contains($0) }
    return ordered
}

/// Index of the profile to pre-select: the last-used one when enabled and still present, else 0.
func initialSelection(in profiles: [Profile], lastUsed: String?, config: Config) -> Int {
    guard config.rememberLast, let last = lastUsed,
          let i = profiles.firstIndex(where: { $0.dir == last }) else { return 0 }
    return i
}
