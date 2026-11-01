import SwiftUI
import AppKit

// MARK: - Store

/// Holds the settings being edited and saves them to the config file after every change.
final class SettingsStore: ObservableObject {
    @Published var list: ProfileList
    @Published var rememberLast: Bool
    @Published var status: String?

    // View state lives here rather than in @State: on machines with only the command-line tools
    // installed, @State is a macro whose plugin is missing, so it would not compile.
    @Published var selection = Set<String>()
    @Published var showingAdd = false
    @Published var isDefault = isDefaultBrowser()
    let addModel = AddProfileModel()

    private var config: Config
    private let path: String
    private var savedOnce = false

    init(path: String = configPath, detect: () -> [Profile]?) {
        self.path = path
        let config = loadConfig(path: path)
        self.config = config
        self.list = ProfileList(items: initialProfileList(config: config, detect: detect).list)
        self.rememberLast = config.rememberLast
    }

    func save() {
        var updated = configByStoring(list.items, in: config)
        updated.rememberLast = rememberLast
        do {
            // Back up the file as it was when the window opened, once, not on every keystroke.
            try saveConfig(updated, to: path, backup: !savedOnce)
            savedOnce = true
            config = updated
        } catch {
            status = "Couldn't save your changes: \(error.localizedDescription)"
        }
    }
}

// MARK: - Reading Chrome's profile list

/// Lets the user point at Chrome's data folder, which also grants this app permission to read it.
private func profilesFromChosenFolder() -> [Profile]? {
    let panel = NSOpenPanel()
    panel.message = "To list your profiles, select Chrome's data folder (Google/Chrome) and click Open."
    panel.prompt = "Open"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.showsHiddenFiles = true
    panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Google")
    guard panel.runModal() == .OK, let folder = panel.url else { return nil }
    guard let data = try? Data(contentsOf: folder.appendingPathComponent("Local State")) else { return nil }
    let profiles = parseLocalState(data)
    return profiles.isEmpty ? nil : profiles
}

// MARK: - Views

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chrome profiles").font(.headline)
                Text("These appear when you click a link. Click a name to rename it, and drag to change the order.")
                    .font(.callout).foregroundColor(.secondary)
            }

            ZStack {
                List(selection: $store.selection) {
                    ForEach($store.list.items) { $profile in
                        HStack {
                            TextField("Name", text: $profile.name)
                                .textFieldStyle(.plain)
                            Spacer()
                            Text(profile.dir).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                    .onMove { store.list.move(from: $0, to: $1) }
                }
                .onDeleteCommand(perform: removeSelected)

                if store.list.items.isEmpty {
                    Text("No profiles yet.\nClick “Detect from Chrome” or “Add Profile…”.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 200)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))

            HStack {
                Button("Add Profile…") { store.addModel.reset(); store.showingAdd = true }
                Button("Detect from Chrome", action: detect)
                Spacer()
                Button("Remove", action: removeSelected).disabled(store.selection.isEmpty)
            }

            if let status = store.status {
                Text(status).font(.callout).foregroundColor(.secondary)
            }

            Toggle("Pre-select the profile I used last", isOn: $store.rememberLast)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: store.isDefault ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(store.isDefault ? .green : .orange)
                Text(store.isDefault ? "Profile Picker is your default browser."
                               : "Profile Picker isn't your default browser yet, so links won't show the picker.")
                    .font(.callout)
                Spacer()
                if !store.isDefault {
                    Button("Make Default…") { makeDefaultBrowser { store.isDefault = isDefaultBrowser() } }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
        .onChange(of: store.list) { _ in store.save() }
        .onChange(of: store.rememberLast) { _ in store.save() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.isDefault = isDefaultBrowser()
        }
        .sheet(isPresented: $store.showingAdd) {
            AddProfileSheet(model: store.addModel, isPresented: $store.showingAdd) { dir, name in
                do { try store.list.add(dir: dir, name: name); return nil }
                catch { return (error as? ProfileListError)?.message ?? "Couldn't add that profile." }
            }
        }
    }

    private func removeSelected() {
        guard !store.selection.isEmpty else { return }
        store.list.remove(ids: store.selection)
        store.selection = []
    }

    private func detect() {
        let found = loadChromeProfiles() ?? profilesFromChosenFolder()
        guard let profiles = found else {
            store.status = "Couldn't read Chrome's profile list. Use “Add Profile…” to enter your profiles instead."
            return
        }
        let added = store.list.merge(profiles)
        store.status = added == 0 ? "No new profiles found." : "Added \(added) profile\(added == 1 ? "" : "s") from Chrome."
    }
}

final class AddProfileModel: ObservableObject {
    @Published var dir = ""
    @Published var name = ""
    @Published var error: String?

    func reset() { dir = ""; name = ""; error = nil }
}

struct AddProfileSheet: View {
    @ObservedObject var model: AddProfileModel
    let isPresented: Binding<Bool>
    /// Returns an error message, or nil if the profile was added.
    let onAdd: (String, String) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a Chrome profile").font(.headline)
            Text("In Chrome, switch to the profile and open chrome://version. Copy the last part of “Profile Path”, for example Default or Profile 3.")
                .font(.callout).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Directory, e.g. Profile 3", text: $model.dir)
            TextField("Name to show (optional)", text: $model.name)
            if let error = model.error { Text(error).font(.callout).foregroundColor(.red) }
            HStack {
                Spacer()
                Button("Cancel") { isPresented.wrappedValue = false }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    if let message = onAdd(model.dir, model.name) { model.error = message }
                    else { isPresented.wrappedValue = false }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.dir.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
        .frame(width: 400)
    }
}

// MARK: - Window

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        let store = SettingsStore(detect: { loadChromeProfiles() })
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Profile Picker"
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.isReleasedWhenClosed = false
        window.center()
        super.init()
        window.delegate = self
    }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { onClose() }
}
