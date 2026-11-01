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

    private enum CodingKeys: String, CodingKey { case profiles, hidden, order, labels, rememberLast }

    /// Omits empty and default values so a generated config file stays short.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if !profiles.isEmpty { try c.encode(profiles, forKey: .profiles) }
        if !hidden.isEmpty { try c.encode(hidden, forKey: .hidden) }
        if !order.isEmpty { try c.encode(order, forKey: .order) }
        if !labels.isEmpty { try c.encode(labels, forKey: .labels) }
        if !rememberLast { try c.encode(rememberLast, forKey: .rememberLast) }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decodeIfPresent([ConfiguredProfile].self, forKey: .profiles) ?? []
        hidden = try c.decodeIfPresent([String].self, forKey: .hidden) ?? []
        order = try c.decodeIfPresent([String].self, forKey: .order) ?? []
        labels = try c.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        rememberLast = try c.decodeIfPresent(Bool.self, forKey: .rememberLast) ?? true
    }
}

/// `$PROFILE_PICKER_CONFIG` overrides the location (used for testing without touching your real config).
let configPath = ProcessInfo.processInfo.environment["PROFILE_PICKER_CONFIG"]
    ?? NSHomeDirectory() + "/.config/profile-picker/config.json"

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
    return ([Profile(dir: "Default", name: "Default")], "Add your profiles with Edit profiles…")
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

// MARK: - Saving and editing helpers shared by `--setup` and the settings window

func encodeConfig(_ config: Config) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(config)
}

/// The profile list to start editing from: saved profiles if any, else Chrome's own list if it
/// can be read, else empty. `hidden`, `labels` and `order` are folded in, because once a list is
/// saved it is the single source of truth. `fromChrome` is true when the list isn't saved yet.
func initialProfileList(config: Config, detect: () -> [Profile]?) -> (list: [Profile], fromChrome: Bool) {
    if !config.profiles.isEmpty {
        let saved = config.profiles.map { Profile(dir: $0.dir, name: $0.name ?? $0.dir) }
        return (arrange(saved, with: config), false)
    }
    if let detected = detect() { return (arrange(detected, with: config), true) }
    return ([], false)
}

/// Returns `config` with `list` stored as its profiles (empty names fall back to the directory).
func configByStoring(_ list: [Profile], in config: Config) -> Config {
    var result = config
    result.profiles = list.map { ConfiguredProfile(dir: $0.dir, name: $0.name.isEmpty ? $0.dir : $0.name) }
    result.hidden = []; result.labels = [:]; result.order = []   // already part of the list
    return result
}

/// Writes the config (pretty JSON plus a trailing newline). With `backup`, the previous file is
/// first copied to `<path>.bak`. Returns true if a backup was made.
@discardableResult
func saveConfig(_ config: Config, to path: String, backup: Bool) throws -> Bool {
    let json = try encodeConfig(config)
    let fm = FileManager.default
    try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    var backedUp = false
    if backup && fm.fileExists(atPath: path) {
        try? fm.removeItem(atPath: path + ".bak")
        try fm.copyItem(atPath: path, toPath: path + ".bak")
        backedUp = true
    }
    try (json + Data("\n".utf8)).write(to: URL(fileURLWithPath: path), options: .atomic)
    return backedUp
}
