import Foundation

// `ProfilePicker --setup`: an interactive way to create the config file without writing JSON.

/// Input/output seams so the whole flow can be driven by scripted input in tests.
struct SetupIO {
    var read: () -> String?
    var write: (String) -> Void
}

/// A profile directory name is used as `--profile-directory=<dir>`, so keep it to a plain name.
func isValidProfileDir(_ dir: String) -> Bool {
    !dir.isEmpty && dir.count <= 64 && !dir.contains("/") && !dir.contains("..") && !dir.hasPrefix("-")
}

/// Interprets one answer per detected profile: empty keeps the name, "-" hides the profile,
/// anything else becomes its new label.
func applyDetectionAnswers(_ profiles: [Profile], answers: [String]) -> (labels: [String: String], hidden: [String]) {
    var labels: [String: String] = [:]
    var hidden: [String] = []
    for (profile, answer) in zip(profiles, answers) {
        if answer == "-" { hidden.append(profile.dir) }
        else if !answer.isEmpty && answer != profile.name { labels[profile.dir] = answer }
    }
    return (labels, hidden)
}

func encodeConfig(_ config: Config) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(config)
}

private func describe(_ profiles: [ConfiguredProfile]) -> String {
    profiles.map { "  \($0.dir)  →  \($0.name ?? $0.dir)\n" }.joined()
}

/// Runs the interactive setup. Returns true if a config file was written.
@discardableResult
func runSetup(io: SetupIO, detect: () -> [Profile]?, path: String = configPath) -> Bool {
    func ask(_ prompt: String) -> String? {
        io.write(prompt)
        return io.read()?.trimmingCharacters(in: .whitespaces)
    }

    io.write("Profile Picker setup\n\n")
    var config = loadConfig(path: path)   // start from the existing file so other settings are kept
    if FileManager.default.fileExists(atPath: path) {
        io.write("Found an existing config at \(path). Its other settings will be kept.\n\n")
    }

    if let detected = detect() {
        io.write("Found \(detected.count) Chrome profile(s). For each one, press Return to keep the name,\n")
        io.write("type a new name to rename it, or type - to hide it.\n\n")
        var answers: [String] = []
        for profile in detected {
            guard let answer = ask("  [\(profile.dir)] \(profile.name): ") else { return false }
            answers.append(answer)
        }
        let result = applyDetectionAnswers(detected, answers: answers)
        config.profiles = []
        config.labels = result.labels
        config.hidden = result.hidden
    } else {
        io.write("Chrome's profile list can't be read (macOS protects other apps' data), so enter your\n")
        io.write("profiles by hand. To find a profile's directory: open it in Chrome, go to chrome://version,\n")
        io.write("and take the last part of \"Profile Path\" (for example Default or Profile 3).\n\n")

        var entered = config.profiles
        if !entered.isEmpty {
            io.write("Current profiles:\n\(describe(entered))\n")
            guard let keep = ask("Keep these and add more? [Y/n] (n starts over) ") else { return false }
            if keep.lowercased().hasPrefix("n") { entered = [] }
            io.write("\n")
        }
        io.write("Enter a directory to add a profile, or an existing one to rename it.\n")
        io.write("Type -<directory> (for example -Profile 3) to remove one.\n\n")

        while true {
            if !entered.isEmpty { io.write("Profiles so far:\n\(describe(entered))") }
            let hint = entered.isEmpty ? "Profile directory" : "Another profile directory, or Return to finish"
            guard let input = ask("\(hint): ") else { return false }
            if input.isEmpty { break }

            if input.hasPrefix("-") {
                let dir = String(input.dropFirst()).trimmingCharacters(in: .whitespaces)
                if let i = entered.firstIndex(where: { $0.dir == dir }) {
                    entered.remove(at: i)
                    io.write("  Removed \(dir).\n")
                } else {
                    io.write("  No profile \"\(dir)\" to remove.\n")
                }
                continue
            }
            guard isValidProfileDir(input) else {
                io.write("  That doesn't look like a profile directory name; try again.\n")
                continue
            }
            if let i = entered.firstIndex(where: { $0.dir == input }) {
                let current = entered[i].name ?? input
                guard let name = ask("  \(input) is already listed as \"\(current)\". New name (Return to keep): ") else { return false }
                if !name.isEmpty { entered[i].name = name }
            } else {
                guard let name = ask("  Name shown in the popup (Return to use \"\(input)\"): ") else { return false }
                entered.append(ConfiguredProfile(dir: input, name: name.isEmpty ? nil : name))
            }
        }
        if entered.isEmpty {
            io.write("\nNo profiles entered. Nothing was written.\n")
            return false
        }
        config.profiles = entered
    }

    guard let json = try? encodeConfig(config), let text = String(data: json, encoding: .utf8) else {
        io.write("Could not encode the configuration.\n")
        return false
    }
    io.write("\nThis will be written to \(path):\n\n\(text)\n\n")
    guard let confirm = ask("Write it? [Y/n] "), confirm.isEmpty || confirm.lowercased().hasPrefix("y") else {
        io.write("Nothing was written.\n")
        return false
    }

    let fm = FileManager.default
    do {
        try fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        if fm.fileExists(atPath: path) {
            let backup = path + ".bak"
            try? fm.removeItem(atPath: backup)
            try fm.copyItem(atPath: path, toPath: backup)
            io.write("Previous config saved to \(backup)\n")
        }
        try (json + Data("\n".utf8)).write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        io.write("Could not write the config: \(error.localizedDescription)\n")
        return false
    }
    io.write("Saved. Set Profile Picker as your default browser (System Settings → Desktop & Dock) if you haven't yet.\n")
    return true
}
