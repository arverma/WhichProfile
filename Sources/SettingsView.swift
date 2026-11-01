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
    @Published var editingID: String?   // the profile whose name is being edited
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

// MARK: - Icons

/// A bundled icon drawn as a template image, so it follows light/dark mode. Falls back to an SF
/// Symbol if the file is missing (for example when running outside the app bundle).
private func icon(_ name: String, fallback: String) -> Image {
    if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "icons"),
       let image = NSImage(contentsOf: url) {
        image.size = NSSize(width: 15, height: 15)
        image.isTemplate = true
        return Image(nsImage: image).renderingMode(.template)
    }
    return Image(systemName: fallback)
}

// MARK: - Views

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chrome profiles").font(.headline)
                Text("These appear when you click a link. Double-click a name (or click the pencil) to rename it. Drag a row to change the order.")
                    .font(.callout).foregroundColor(.secondary)
            }

            ZStack {
                List(selection: $store.selection) {
                    ForEach($store.list.items) { $profile in
                        HStack(spacing: 8) {
                            icon("drag", fallback: "line.3.horizontal")
                                .foregroundColor(.secondary)
                                .help("Drag to reorder")
                            if store.editingID == profile.id {
                                RenameField(text: $profile.name) { store.editingID = nil }
                            } else {
                                Text(profile.name)
                                    .help("Double-click to rename")
                                    .simultaneousGesture(TapGesture(count: 2).onEnded { store.editingID = profile.id })
                                Button { store.editingID = profile.id } label: { icon("edit", fallback: "pencil") }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.secondary)
                                    .help("Rename")
                            }
                            Spacer()
                            Text(profile.dir).font(.caption).foregroundColor(.secondary)
                            Button { remove(profile.id) } label: { icon("delete", fallback: "trash") }
                                .buttonStyle(.borderless)
                                .foregroundColor(.secondary)
                                .help("Remove \(profile.name)")
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

    private func remove(_ id: String) {
        store.list.remove(ids: [id])
        store.selection.remove(id)
        if store.editingID == id { store.editingID = nil }
    }

    /// Delete key on the selected rows.
    private func removeSelected() {
        for id in store.selection { remove(id) }
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

// MARK: - Inline rename field

/// A text field that takes focus as soon as it appears. Return keeps the new name, Esc restores
/// the old one, and clicking elsewhere keeps what was typed. An empty name is restored.
struct RenameField: NSViewRepresentable {
    let text: Binding<String>
    let onDone: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text.wrappedValue)
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        context.coordinator.original = text.wrappedValue
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) { context.coordinator.parent = self }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RenameField
        var original = ""
        private var finished = false

        init(_ parent: RenameField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text.wrappedValue = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if parent.text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                parent.text.wrappedValue = original
            }
            finish()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
            parent.text.wrappedValue = original
            finish()
            return true
        }

        private func finish() {
            guard !finished else { return }
            finished = true
            DispatchQueue.main.async { self.parent.onDone() }
        }
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
