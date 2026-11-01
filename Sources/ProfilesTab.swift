import SwiftUI
import AppKit

// MARK: - Icons

/// A bundled icon drawn as a template image, so it follows light/dark mode. Falls back to an SF
/// Symbol if the file is missing (for example when running outside the app bundle).
func icon(_ name: String, fallback: String) -> Image {
    if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "icons"),
       let image = NSImage(contentsOf: url) {
        image.size = NSSize(width: 15, height: 15)
        image.isTemplate = true
        return Image(nsImage: image).renderingMode(.template)
    }
    return Image(systemName: fallback)
}

// MARK: - Avatar

private let avatarPalette: [Color] = [
    Color(nsColor: .systemBlue), Color(nsColor: .systemGreen), Color(nsColor: .systemOrange), Color(nsColor: .systemPurple),
    Color(nsColor: .systemPink), Color(nsColor: .systemTeal), Color(nsColor: .systemIndigo), Color(nsColor: .systemRed),
]

/// A round, coloured badge with the profile's initial, like Chrome's own profile avatars.
private struct ProfileAvatar: View {
    let name: String
    let seed: String

    var body: some View {
        ZStack {
            Circle().fill(avatarPalette[avatarPaletteIndex(for: seed, count: avatarPalette.count)])
            Text(profileInitial(name))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}

// MARK: - Transparent list background

/// SwiftUI's List draws an opaque white background on the macOS versions this app supports, which
/// clashes with the grey cards used on the other tabs. This clears it so the card shows through.
private struct ClearListBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        // The list's views may not exist yet on the first pass, so try a few times.
        for delay in [0.0, 0.15, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { clear(from: view) }
        }
    }

    private func clear(from view: NSView) {
        var ancestor: NSView? = view.superview
        while let current = ancestor {
            if let scrollView = firstScrollView(in: current) {
                scrollView.drawsBackground = false
                scrollView.backgroundColor = .clear
                scrollView.contentView.drawsBackground = false
                scrollView.wantsLayer = true
                scrollView.layer?.backgroundColor = NSColor.clear.cgColor
                if let table = scrollView.documentView as? NSTableView {
                    table.backgroundColor = .clear
                    table.usesAlternatingRowBackgroundColors = false
                }
                return
            }
            ancestor = current.superview
        }
    }

    private func firstScrollView(in root: NSView) -> NSScrollView? {
        if let scroll = root as? NSScrollView { return scroll }
        for child in root.subviews { if let found = firstScrollView(in: child) { return found } }
        return nil
    }
}

// MARK: - Tab

struct ProfilesTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Chrome profiles").font(.headline)
                    Spacer()
                    Button("Detect from Chrome", action: detect)
                    Button("Add Profile…") { addProfile() }
                        .buttonStyle(.borderedProminent)
                }
                Text("These appear when you click a link, in this order. Double-click a name (or click the pencil) to rename it, and drag a row to reorder.")
                    .font(.callout).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            GroupBox {
                ZStack {
                    List(selection: $store.selection) {
                        ForEach($store.list.items) { $profile in
                            row($profile)
                        }
                        .onMove { store.list.move(from: $0, to: $1) }
                    }
                    .listStyle(.plain)
                    .background(ClearListBackground())
                    .onDeleteCommand(perform: removeSelected)

                    if store.list.items.isEmpty { emptyState }
                }
                .frame(minHeight: 240, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            if let status = store.status {
                Text(status).font(.callout).foregroundColor(.secondary)
            }

            let count = store.list.items.count
            Text(count == 0 ? "" : "\(count) profile\(count == 1 ? "" : "s"). In the picker, press 1–9 to choose one quickly.")
                .font(.footnote).foregroundColor(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $store.showingAdd) {
            AddProfileSheet(model: store.addModel, isPresented: $store.showingAdd) { dir, name in
                do { try store.list.add(dir: dir, name: name); return nil }
                catch { return (error as? ProfileListError)?.message ?? "Couldn't add that profile." }
            }
        }
    }

    // MARK: Rows

    private func row(_ profile: Binding<Profile>) -> some View {
        let item = profile.wrappedValue
        let position = store.list.items.firstIndex(where: { $0.id == item.id }).map { $0 + 1 }
        return HStack(spacing: 12) {
            icon("drag", fallback: "line.3.horizontal")
                .foregroundColor(.secondary)
                .help("Drag to reorder")

            ProfileAvatar(name: item.name, seed: item.dir)

            VStack(alignment: .leading, spacing: 1) {
                if store.editingID == item.id {
                    RenameField(text: profile.name) { store.editingID = nil }
                        .frame(maxWidth: 220)
                } else {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .fontWeight(.medium)
                            .help("Double-click to rename")
                            .simultaneousGesture(TapGesture(count: 2).onEnded { store.editingID = item.id })
                        Button { store.editingID = item.id } label: { icon("edit", fallback: "pencil") }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                            .help("Rename")
                            .accessibilityLabel("Rename \(item.name)")
                    }
                }
                Text(item.dir).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            if let position = position, position <= 9 {
                Text("\(position)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 22)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(5)
                    .help("Press \(position) in the picker to open this profile")
                    .accessibilityLabel("Shortcut \(position)")
            }

            Button { confirmRemoval(of: [item.id]) } label: { icon("delete", fallback: "trash") }
                .buttonStyle(.borderless)
                .foregroundColor(.secondary)
                .help("Remove \(item.name)")
                .accessibilityLabel("Remove \(item.name)")
        }
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 38))
                .foregroundColor(.secondary)
            Text("No profiles yet").font(.headline)
            Text("Click “Detect from Chrome” or “Add Profile…” above to get started.")
                .font(.callout).foregroundColor(.secondary)
        }
    }

    private func addProfile() {
        store.addModel.reset()
        store.showingAdd = true
    }

    /// Asks before removing, since there is no undo. Cancel is the default button so that
    /// pressing Return by accident does not delete anything.
    private func confirmRemoval(of ids: Set<String>) {
        let names = store.list.items.filter { ids.contains($0.id) }.map(\.name)
        guard !names.isEmpty else { return }
        let prompt = removalPrompt(for: names)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = prompt.title
        alert.informativeText = prompt.message
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Remove")
        alert.buttons[1].hasDestructiveAction = true

        let finish: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .alertSecondButtonReturn else { return }
            store.list.remove(ids: ids)
            store.selection.subtract(ids)
            if let editing = store.editingID, ids.contains(editing) { store.editingID = nil }
        }
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(alert.runModal())
        }
    }

    /// Delete key on the selected rows.
    private func removeSelected() { confirmRemoval(of: store.selection) }

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

// MARK: - Add profile sheet

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
