import Foundation

// `ProfilePicker --setup`: a small menu for editing your profile list without writing JSON.

/// Input/output seams so the whole flow can be driven by scripted input in tests.
struct SetupIO {
    var read: () -> String?
    var write: (String) -> Void
}

/// A profile directory name is used as `--profile-directory=<dir>`, so keep it to a plain name.
func isValidProfileDir(_ dir: String) -> Bool {
    !dir.isEmpty && dir.count <= 64 && !dir.contains("/") && !dir.contains("..") && !dir.hasPrefix("-")
}

func encodeConfig(_ config: Config) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(config)
}

/// Raised when input ends (Ctrl-D or a closed pipe) so the flow can stop without writing anything.
private struct InputEnded: Error {}

/// Runs the interactive setup. Returns true if a config file was written.
///
/// The list starts from your saved profiles, or from Chrome's own list if that is readable,
/// or empty. Existing `hidden`, `labels` and `order` settings are folded into the list, because
/// the saved list is the single source of truth. Nothing is written until you choose Save.
@discardableResult
func runSetup(io: SetupIO, detect: () -> [Profile]?, path: String = configPath) -> Bool {
    func ask(_ prompt: String) throws -> String {
        io.write(prompt)
        guard let line = io.read() else { throw InputEnded() }
        return line.trimmingCharacters(in: .whitespaces)
    }

    var config = loadConfig(path: path)
    var list: [Profile]
    var dirty = false

    if !config.profiles.isEmpty {
        list = arrange(config.profiles.map { Profile(dir: $0.dir, name: $0.name ?? $0.dir) }, with: config)
    } else if let detected = detect() {
        list = arrange(detected, with: config)
        dirty = true   // found in Chrome but not saved yet
    } else {
        list = []
    }

    func showList() {
        if list.isEmpty {
            io.write("You haven't added any profiles yet.\n")
            return
        }
        io.write("Your Chrome profiles:\n")
        for (i, p) in list.enumerated() {
            io.write("  \(i + 1). \(p.name)\(p.name == p.dir ? "" : "  (\(p.dir))")\n")
        }
    }

    /// Reads "3" from the command's argument or by asking; nil (with a message) if it isn't valid.
    func pickNumber(_ arg: String, _ question: String) throws -> Int? {
        if list.isEmpty { io.write("There are no profiles yet. Press a to add one.\n"); return nil }
        let text = arg.isEmpty ? try ask(question) : arg
        guard let n = Int(text), (1...list.count).contains(n) else {
            io.write("Enter a number from 1 to \(list.count).\n")
            return nil
        }
        return n - 1
    }

    func save() -> Bool {
        config.profiles = list.map { ConfiguredProfile(dir: $0.dir, name: $0.name) }
        config.hidden = []; config.labels = [:]; config.order = []   // now part of the list itself
        guard let json = try? encodeConfig(config) else {
            io.write("Could not encode the configuration.\n")
            return false
        }
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            var backedUp = false
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path + ".bak")
                try fm.copyItem(atPath: path, toPath: path + ".bak")
                backedUp = true
            }
            try (json + Data("\n".utf8)).write(to: URL(fileURLWithPath: path), options: .atomic)
            io.write("\nSaved \(list.count) profile\(list.count == 1 ? "" : "s") to \(path)\n")
            if backedUp { io.write("Your previous settings are in \(path).bak\n") }
            io.write("If you haven't yet, set Profile Picker as your default browser in\nSystem Settings → Desktop & Dock.\n")
            return true
        } catch {
            io.write("Could not write the config: \(error.localizedDescription)\n")
            return false
        }
    }

    do {
        io.write("Profile Picker setup\nChoose which Chrome profiles appear when you click a link.\n\n")
        while true {
            showList()
            io.write("\n  [a] Add   [e] Rename   [d] Delete   [u] Move up   [s] Save   [q] Quit\n")
            let input = try ask("> ")
            let command = input.first.map { String($0).lowercased() } ?? ""
            let arg = String(input.dropFirst()).trimmingCharacters(in: .whitespaces)
            io.write("\n")

            switch command {
            case "a":
                io.write("In Chrome, open the profile and go to chrome://version. The last part of\n")
                io.write("\"Profile Path\" is its directory, for example Default or Profile 3.\n")
                let dir = arg.isEmpty ? try ask("Directory (Return to cancel): ") : arg
                if dir.isEmpty { break }
                if !isValidProfileDir(dir) {
                    io.write("That doesn't look like a profile directory name.\n")
                } else if let existing = list.first(where: { $0.dir == dir }) {
                    io.write("\(dir) is already in the list as \"\(existing.name)\". Use e to rename it.\n")
                } else {
                    let name = try ask("Name to show in the popup (Return to use \"\(dir)\"): ")
                    list.append(Profile(dir: dir, name: name.isEmpty ? dir : name))
                    dirty = true
                }

            case "e":
                if let i = try pickNumber(arg, "Rename which number? ") {
                    let name = try ask("New name for \"\(list[i].name)\" (Return to cancel): ")
                    if !name.isEmpty { list[i].name = name; dirty = true }
                }

            case "d":
                if let i = try pickNumber(arg, "Delete which number? ") {
                    io.write("Deleted \"\(list[i].name)\".\n")
                    list.remove(at: i)
                    dirty = true
                }

            case "u":
                if let i = try pickNumber(arg, "Move which number up? ") {
                    if i == 0 { io.write("It's already first.\n") }
                    else { list.swapAt(i, i - 1); dirty = true }
                }

            case "s":
                if list.isEmpty { io.write("Add at least one profile first.\n") }
                else { return save() }

            case "q":
                if !dirty { return false }
                let answer = try ask("Quit without saving your changes? [y/N] ")
                if answer.lowercased().hasPrefix("y") { return false }

            default:
                io.write("Type a letter from the menu.\n")
            }
            io.write("\n")
        }
    } catch {
        io.write("\nInput ended. Nothing was saved.\n")
        return false
    }
}
