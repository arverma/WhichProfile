import SwiftUI
import AppKit

enum SettingsTab: Hashable { case general, profiles, features, about }

final class AddProfileModel: ObservableObject {
    @Published var dir = ""
    @Published var name = ""
    @Published var error: String?

    func reset() { dir = ""; name = ""; error = nil }
}

/// Holds everything the settings window edits and saves it to the config file after every change.
///
/// View state lives here rather than in `@State`: on machines with only the command-line tools
/// installed, `@State` is a macro whose plugin is missing, so it would not compile.
final class SettingsStore: ObservableObject {
    // Saved settings. Each change is written to disk immediately.
    @Published var list: ProfileList { didSet { save() } }
    @Published var rememberLast: Bool { didSet { save() } }
    @Published var cleanLinks: Bool { didSet { save() } }

    // View state.
    @Published var tab: SettingsTab
    @Published var status: String?
    @Published var selection = Set<String>()
    @Published var showingAdd = false
    @Published var editingID: String?          // the profile whose name is being edited
    @Published var isDefault = isDefaultBrowser()
    @Published var diagnosticsCopied = false
    @Published var openAtLogin = LoginItem.isEnabled
    @Published var loginNote: String?
    let addModel = AddProfileModel()

    private var config: Config
    private let path: String
    private var savedOnce = false

    init(path: String = configPath, tab: SettingsTab = .general, detect: () -> [Profile]?) {
        self.path = path
        let config = loadConfig(path: path)
        self.config = config
        self.tab = tab
        self.list = ProfileList(items: initialProfileList(config: config, detect: detect).list)
        self.rememberLast = config.rememberLast
        self.cleanLinks = config.cleanLinks
    }

    func save() {
        var updated = configByStoring(list.items, in: config)
        updated.rememberLast = rememberLast
        updated.cleanLinks = cleanLinks
        do {
            // Back up the file as it was when the window opened, once, not on every keystroke.
            try saveConfig(updated, to: path, backup: !savedOnce)
            savedOnce = true
            config = updated
        } catch {
            status = "Couldn't save your changes: \(error.localizedDescription)"
        }
    }

    func refreshDefaultBrowser() { isDefault = isDefaultBrowser() }

    func refreshLoginItem() {
        openAtLogin = LoginItem.isEnabled
        loginNote = LoginItem.needsApproval ? "Approve \(ProjectInfo.name) in System Settings → General → Login Items." : nil
    }

    func setOpenAtLogin(_ on: Bool) {
        do { try LoginItem.setEnabled(on) }
        catch { log("could not change the login item: \(error.localizedDescription)") ; loginNote = "Couldn't change this setting: \(error.localizedDescription)"; openAtLogin = LoginItem.isEnabled; return }
        refreshLoginItem()
    }

    func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(ProjectInfo.diagnostics(profileCount: list.items.count, isDefaultBrowser: isDefault),
                                       forType: .string)
        diagnosticsCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.diagnosticsCopied = false }
    }
}

// MARK: - Reading Chrome's profile list

/// Lets the user point at Chrome's data folder, which also grants this app permission to read it.
func profilesFromChosenFolder() -> [Profile]? {
    let panel = NSOpenPanel()
    panel.message = "To list your profiles, select Chrome's data folder (Google/Chrome) and click Open."
    panel.prompt = "Open"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.showsHiddenFiles = true
    panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Google")
    guard panel.runModal() == .OK, let folder = panel.url else {
        log("detect: folder picker cancelled")
        return nil
    }
    let file = folder.appendingPathComponent("Local State")
    let data: Data
    do { data = try Data(contentsOf: file) }
    catch {
        log("detect: could not read \(file.path) after the folder was chosen: \(error.localizedDescription)")
        return nil
    }
    let profiles = parseLocalState(data)
    log("detect: read \(profiles.count) profile(s) from the chosen folder")
    return profiles.isEmpty ? nil : profiles
}
