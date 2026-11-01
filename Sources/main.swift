import AppKit

private let lastProfileKey = "lastProfile"

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var picker: LinkPicker?
    private var settings: SettingsWindowController?
    /// The link waiting for a choice, kept while the settings window is open so the popup can return.
    private var pendingURL: URL?
    private var gotURL = false
    private var statusItem: StatusItemController?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        gotURL = true
        showPicker(for: url)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMainMenu(target: self)
        statusItem = StatusItemController(app: self)

        // Open the settings window only when the user started the app by hand. A launch caused by a
        // link, by login, or by --background stays quiet: the menu bar icon is all that appears.
        let loginLaunch = isLoginLaunch(appleEventSaysLoginItem: launchedAsLoginItem(),
                                        systemUptime: ProcessInfo.processInfo.systemUptime)
        let background = CommandLine.arguments.contains("--background")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            if shouldShowSettingsOnLaunch(receivedLink: gotURL, loginLaunch: loginLaunch, backgroundFlag: background) {
                openSettings()
            }
        }
    }

    /// Opening the app again from Spotlight or Finder while it runs shows the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    /// macOS tags login launches with an Apple event property ('prdt' = 'lgit').
    private func launchedAsLoginItem() -> Bool {
        guard let property = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: 0x7072_6474) else { return false }
        return property.enumCodeValue == 0x6C67_6974
    }

    private func showPicker(for url: URL) {
        pendingURL = url
        let config = loadConfig()
        let resolved = resolveProfiles(config: config, detect: { loadChromeProfiles() })
        let profiles = arrange(resolved.profiles, with: config)
        let last = UserDefaults.standard.string(forKey: lastProfileKey)
        let preselect = initialSelection(in: profiles, lastUsed: last, config: config)
        let link = prepareLink(url, config: config)

        picker = LinkPicker(profiles: profiles) { [weak self] chosen, isPrivate in
            if let chosen = chosen {
                UserDefaults.standard.set(chosen.dir, forKey: lastProfileKey)
                launch(link.url, in: chosen, isPrivate: isPrivate)
            }
            self?.linkFinished()
        }
        picker?.onSettings = { [weak self] in self?.openSettings(tab: .profiles) }
        picker?.show(url: link.url, cleaned: !link.removed.isEmpty, preselect: preselect, notice: resolved.warning)
    }

    /// The link was opened or dismissed. The app keeps running in the menu bar.
    private func linkFinished() {
        pendingURL = nil
        picker = nil
    }

    private func openSettings(tab: SettingsTab = .general) {
        picker?.dismiss()
        picker = nil
        if let existing = settings {
            existing.show(tab: tab)
            return
        }
        let controller = SettingsWindowController(tab: tab, onClose: { [weak self] in self?.settingsClosed() })
        settings = controller
        controller.show()
    }

    // Menu bar actions (see MainMenu.swift).
    @objc func showAbout() { openSettings(tab: .about) }
    @objc func showSettings() { openSettings(tab: .general) }
    @objc func openHelp() { openExternalLink(ProjectInfo.repository) }
    @objc func openReleases() { openExternalLink(ProjectInfo.releases) }
    @objc func openIssues() { openExternalLink(ProjectInfo.issues) }

    @objc func makeDefaultFromMenu() { makeDefaultBrowser {} }

    @objc func toggleLoginItem() {
        do { try LoginItem.setEnabled(!LoginItem.isEnabled) }
        catch {
            log("could not change the login item: \(error.localizedDescription)")
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Couldn't change Open at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func settingsClosed() {
        settings = nil
        if let url = pendingURL {
            // Back to the link that was waiting, now with the edited profile list.
            showPicker(for: url)
        }
    }
}

// Carry over a config saved under the app's old name (skipped when a test path is set).
if ProcessInfo.processInfo.environment["WHICHPROFILE_CONFIG"] == nil { migrateLegacyConfig() }

if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
    print("""
    WhichProfile: choose which Chrome profile opens a link.

    Usage: WhichProfile [option]
      --setup           interactively create ~/.config/whichprofile/config.json
      --list-profiles   print the profiles the picker would show
      --background      start in the menu bar without opening the settings window
      --help            show this help
    """)
    exit(0)
}

// `WhichProfile --setup` walks through creating the config file.
if CommandLine.arguments.contains("--setup") {
    let io = SetupIO(read: { readLine() }, write: { print($0, terminator: ""); fflush(stdout) })
    exit(runSetup(io: io, detect: { loadChromeProfiles() }) ? 0 : 1)
}

// `WhichProfile --list-profiles` prints the profiles the picker would show, for debugging.
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
