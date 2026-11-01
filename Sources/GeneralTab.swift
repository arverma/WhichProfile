import SwiftUI
import AppKit

enum StepStatus { case done, todo, info }

/// One line of the "Get started" checklist.
struct StepRow<Trailing: View>: View {
    let status: StepStatus
    let title: String
    let detail: String
    let trailing: Trailing

    init(status: StepStatus, title: String, detail: String, @ViewBuilder trailing: () -> Trailing) {
        self.status = status
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            switch status {
            case .done: Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .todo: Image(systemName: "circle").foregroundColor(.orange)
            case .info: Image(systemName: "cursorarrow.click").foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.callout).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            trailing
        }
    }
}

struct GeneralTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Get started").font(.headline)

                        StepRow(status: store.isDefault ? .done : .todo,
                                title: "Make \(ProjectInfo.name) your default browser",
                                detail: store.isDefault ? "Done. Links from other apps now ask which profile to use."
                                                        : "Links from other apps only show the picker once this is set.") {
                            if !store.isDefault {
                                Button("Make Default…") { makeDefaultBrowser { store.refreshDefaultBrowser() } }
                            }
                        }

                        let count = store.list.items.count
                        StepRow(status: count > 0 ? .done : .todo,
                                title: "Add your Chrome profiles",
                                detail: count == 0 ? "Choose which profiles should appear in the picker."
                                                   : "\(count) profile\(count == 1 ? "" : "s") ready. You can rename, reorder or remove them.") {
                            Button(count == 0 ? "Add Profiles" : "Edit Profiles") { store.tab = .profiles }
                        }

                        StepRow(status: .info,
                                title: "Click a link in any other app",
                                detail: "The picker appears next to your cursor. Pick a profile, and the link opens there.") { EmptyView() }
                    }
                    .padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Options").font(.headline)

                        VStack(alignment: .leading, spacing: 3) {
                            Toggle("Pre-select the profile I used last", isOn: $store.rememberLast)
                            Text("The picker highlights your previous choice, so pressing Return reopens it.")
                                .font(.callout).foregroundColor(.secondary).padding(.leading, 20)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Toggle("Open at login", isOn: Binding(get: { store.openAtLogin }, set: { store.setOpenAtLogin($0) }))
                                .disabled(!LoginItem.isSupported)
                            Text(LoginItem.isSupported
                                 ? "Starts \(ProjectInfo.name) quietly in the menu bar when you log in, so the picker is instant. Not required: it also starts when you click a link."
                                 : "Needs macOS 13 or later.")
                                .font(.callout).foregroundColor(.secondary).padding(.leading, 20)
                                .fixedSize(horizontal: false, vertical: true)
                            if let note = store.loginNote {
                                Text(note).font(.callout).foregroundColor(.orange).padding(.leading, 20)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Toggle("Remove tracking from links", isOn: $store.cleanLinks)
                            Text("Strips utm_*, fbclid, gclid and similar parameters before opening a link. The picker tells you when it did.")
                                .font(.callout).foregroundColor(.secondary).padding(.leading, 20)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                }

                Button("See everything \(ProjectInfo.name) can do") { store.tab = .features }
                    .buttonStyle(.link)
            }
            .padding(20)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refreshDefaultBrowser()
            store.refreshLoginItem()
        }
    }
}
