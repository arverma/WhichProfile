import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        // An explicit segmented control instead of TabView, so the tabs are always visible
        // whatever the macOS version's default tab styling does.
        VStack(spacing: 0) {
            Picker("", selection: $store.tab) {
                Text("General").tag(SettingsTab.general)
                Text("Profiles").tag(SettingsTab.profiles)
                Text("Features").tag(SettingsTab.features)
                Text("About").tag(SettingsTab.about)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)

            switch store.tab {
            case .general: GeneralTab(store: store)
            case .profiles: ProfilesTab(store: store)
            case .features: FeaturesTab()
            case .about: AboutTab(store: store)
            }
        }
        .frame(minWidth: 540, minHeight: 580)
    }
}

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let store: SettingsStore
    private let onClose: () -> Void

    init(tab: SettingsTab, onClose: @escaping () -> Void) {
        self.onClose = onClose
        store = SettingsStore(tab: tab, detect: { loadChromeProfiles() })
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = ProjectInfo.name
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.isReleasedWhenClosed = false
        window.center()
        super.init()
        window.delegate = self
    }

    /// Brings the window forward, optionally switching to a tab.
    func show(tab: SettingsTab? = nil) {
        if let tab = tab { store.tab = tab }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) { onClose() }
}
