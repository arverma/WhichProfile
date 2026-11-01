import Foundation

// MARK: - Logging

/// Appends a line to ~/Library/Logs/WhichProfile.log, or to `$WHICHPROFILE_LOG` if set
/// (the tests use this to keep their output out of the real log).
func log(_ msg: String) {
    let path = ProcessInfo.processInfo.environment["WHICHPROFILE_LOG"]
        ?? NSHomeDirectory() + "/Library/Logs/WhichProfile.log"
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

/// Arguments for `/usr/bin/open` that open `url` in the given Chrome profile, optionally in a
/// private (incognito) window. `-n` is required so Chrome receives `--profile-directory` even
/// when it is already running; the new process hands the URL to the running instance and exits.
func chromeLaunchArguments(url: URL, profile: Profile, isPrivate: Bool = false) -> [String] {
    var args = ["-na", "Google Chrome", "--args", "--profile-directory=\(profile.dir)"]
    if isPrivate { args.append("--incognito") }
    args.append(url.absoluteString)
    return args
}

func launch(_ url: URL, in profile: Profile, isPrivate: Bool = false) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = chromeLaunchArguments(url: url, profile: profile, isPrivate: isPrivate)
    do {
        try p.run()
        p.waitUntilExit()
        log("launch \(profile.dir)\(isPrivate ? " (private)" : "") status=\(p.terminationStatus)")
    } catch {
        log("launch \(profile.dir) FAILED: \(error)")
    }
}
