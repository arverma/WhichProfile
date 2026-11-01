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

// MARK: - Tab

struct ProfilesTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chrome profiles").font(.headline)
                Text("These appear when you click a link. Double-click a name (or click the pencil) to rename it. Drag a row to change the order.")
                    .font(.callout).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                                    .accessibilityLabel("Rename \(profile.name)")
                            }
                            Spacer()
                            Text(profile.dir).font(.caption).foregroundColor(.secondary)
                            Button { confirmRemoval(of: [profile.id]) } label: { icon("delete", fallback: "trash") }
                                .buttonStyle(.borderless)
                                .foregroundColor(.secondary)
                                .help("Remove \(profile.name)")
                                .accessibilityLabel("Remove \(profile.name)")
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
        }
        .padding(20)
        .sheet(isPresented: $store.showingAdd) {
            AddProfileSheet(model: store.addModel, isPresented: $store.showingAdd) { dir, name in
                do { try store.list.add(dir: dir, name: name); return nil }
                catch { return (error as? ProfileListError)?.message ?? "Couldn't add that profile." }
            }
        }
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
