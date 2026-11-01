import Foundation

extension Profile: Identifiable {
    var id: String { dir }
}

enum ProfileListError: Error, Equatable {
    case invalidDirectory
    case duplicate(existingName: String)

    var message: String {
        switch self {
        case .invalidDirectory:
            return "That doesn't look like a profile directory. Use something like Default or Profile 3."
        case .duplicate(let name):
            return "That profile is already in the list as \"\(name)\"."
        }
    }
}

/// The editable list behind the settings window. Pure value logic, so it is easy to test.
struct ProfileList: Equatable {
    var items: [Profile]

    /// Adds a profile. An empty name falls back to the directory.
    mutating func add(dir rawDir: String, name rawName: String) throws {
        let dir = rawDir.trimmingCharacters(in: .whitespaces)
        let name = rawName.trimmingCharacters(in: .whitespaces)
        guard isValidProfileDir(dir) else { throw ProfileListError.invalidDirectory }
        if let existing = items.first(where: { $0.dir == dir }) {
            throw ProfileListError.duplicate(existingName: existing.name)
        }
        items.append(Profile(dir: dir, name: name.isEmpty ? dir : name))
    }

    /// Appends profiles that aren't in the list yet (existing names are never overwritten).
    /// Returns how many were added.
    @discardableResult
    mutating func merge(_ detected: [Profile]) -> Int {
        var added = 0
        for profile in detected where !items.contains(where: { $0.dir == profile.dir }) {
            items.append(profile)
            added += 1
        }
        return added
    }

    mutating func remove(ids: Set<String>) {
        items.removeAll { ids.contains($0.dir) }
    }

    /// Same contract as SwiftUI's `onMove`: `destination` is an index in the list before the move.
    mutating func move(from source: IndexSet, to destination: Int) {
        let moving = source.map { items[$0] }
        let insertAt = destination - source.filter { $0 < destination }.count
        items = items.enumerated().filter { !source.contains($0.offset) }.map { $0.element }
        items.insert(contentsOf: moving, at: insertAt)
    }
}

/// Wording for the "remove?" confirmation. There is no undo, so the message says what to do instead.
func removalPrompt(for names: [String]) -> (title: String, message: String) {
    let readdHint = "You can add it back later with Add Profile… or Detect from Chrome."
    if names.count == 1 {
        return ("Remove “\(names[0])”?", "It will no longer appear when you click a link. " + readdHint)
    }
    return ("Remove \(names.count) profiles?",
            "They will no longer appear when you click a link. You can add them back later with Add Profile… or Detect from Chrome.")
}

// MARK: - Avatars

/// The letter shown in a profile's avatar: its first letter or digit, uppercased, else "?".
func profileInitial(_ name: String) -> String {
    guard let first = name.first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
    return String(first).uppercased()
}

/// A stable index into an avatar colour palette, derived from `seed` (a profile's directory).
/// Swift's own `hashValue` changes between launches, so this sums the characters instead:
/// a profile keeps the same colour every time.
func avatarPaletteIndex(for seed: String, count: Int) -> Int {
    guard count > 0 else { return 0 }
    return seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1_000_003 } % count
}
