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
    private var keyMonitor: Any?

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
        // The app has no Dock icon (it lives in the menu bar), so it must be activated explicitly.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func windowWillClose(_ notification: Notification) {
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
        onClose()
    }

    /// An app without a Dock icon shows no menu bar of its own, so the standard editing shortcuts
    /// are routed by hand: without this, copy and paste would not work in the text fields.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if NSApp.keyWindow is PickerPanel { return event }   // the popup handles its own keys
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == .command || flags == [.command, .shift],
                  let key = event.charactersIgnoringModifiers?.lowercased() else { return event }
            let shift = flags.contains(.shift)
            let action: Selector?
            switch (key, shift) {
            case ("x", false): action = #selector(NSText.cut(_:))
            case ("c", false): action = #selector(NSText.copy(_:))
            case ("v", false): action = #selector(NSText.paste(_:))
            case ("a", false): action = #selector(NSText.selectAll(_:))
            case ("z", false): action = Selector(("undo:"))
            case ("z", true): action = Selector(("redo:"))
            case ("w", false): action = #selector(NSWindow.performClose(_:))
            case ("q", false): action = #selector(NSApplication.terminate(_:))
            default: action = nil
            }
            guard let selector = action, NSApp.sendAction(selector, to: nil, from: nil) else { return event }
            return nil
        }
    }
}
