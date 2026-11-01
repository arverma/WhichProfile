import AppKit

private let lastProfileKey = "lastProfile"

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var picker: Picker?
    private var gotURL = false

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        gotURL = true

        let config = loadConfig()
        let resolved = resolveProfiles(config: config, detect: { loadChromeProfiles() })
        let profiles = arrange(resolved.profiles, with: config)
        let last = UserDefaults.standard.string(forKey: lastProfileKey)
        let preselect = initialSelection(in: profiles, lastUsed: last, config: config)

        picker = Picker(profiles: profiles) { chosen in
            if let chosen = chosen {
                UserDefaults.standard.set(chosen.dir, forKey: lastProfileKey)
                launch(url, in: chosen)
            }
            // The app is single-shot: quit after every use so nothing lingers.
            NSApp.terminate(nil)
        }
        picker?.show(url: url, preselect: preselect, notice: resolved.warning)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launched by hand (no link): explain, then quit so nothing lingers.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            guard !gotURL else { return }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Profile Picker is installed"
            alert.informativeText = "Set it as your default web browser in System Settings → Desktop & Dock. After that, clicking any link shows a profile chooser next to the cursor."
            alert.runModal()
            NSApp.terminate(nil)
        }
    }
}

if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
    print("""
    Profile Picker: choose which Chrome profile opens a link.

    Usage: ProfilePicker [option]
      --setup           interactively create ~/.config/profile-picker/config.json
      --list-profiles   print the profiles the picker would show
      --help            show this help
    """)
    exit(0)
}

// `ProfilePicker --setup` walks through creating the config file.
if CommandLine.arguments.contains("--setup") {
    let io = SetupIO(read: { readLine() }, write: { print($0, terminator: ""); fflush(stdout) })
    exit(runSetup(io: io, detect: { loadChromeProfiles() }) ? 0 : 1)
}

// `ProfilePicker --list-profiles` prints the profiles the picker would show, for debugging.
if CommandLine.arguments.contains("--list-profiles") {
    let config = loadConfig()
    let resolved = resolveProfiles(config: config, detect: { loadChromeProfiles() })
    if let w = resolved.warning { FileHandle.standardError.write(Data((w + "\n").utf8)) }
    for p in arrange(resolved.profiles, with: config) { print("\(p.dir)\t\(p.name)") }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
