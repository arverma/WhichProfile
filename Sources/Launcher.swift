import Foundation

// MARK: - Logging

/// Appends a line to ~/Library/Logs/ProfilePicker.log.
func log(_ msg: String) {
    let path = NSHomeDirectory() + "/Library/Logs/ProfilePicker.log"
    let line = "\(Date()) \(msg)\n"
    if let h = FileHandle(forWritingAtPath: path) {
        h.seekToEndOfFile()
        h.write(Data(line.utf8))
        try? h.close()
    } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - Launching

/// Arguments for `/usr/bin/open` that open `url` in the given Chrome profile.
/// `-n` is required so Chrome receives `--profile-directory` even when it is already
/// running; the new process hands the URL to the running instance and exits.
func chromeLaunchArguments(url: URL, profile: Profile) -> [String] {
    ["-na", "Google Chrome", "--args", "--profile-directory=\(profile.dir)", url.absoluteString]
}

func launch(_ url: URL, in profile: Profile) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = chromeLaunchArguments(url: url, profile: profile)
    do {
        try p.run()
        p.waitUntilExit()
        log("launch \(profile.dir) status=\(p.terminationStatus)")
    } catch {
        log("launch \(profile.dir) FAILED: \(error)")
    }
}
