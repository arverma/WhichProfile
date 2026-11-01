import AppKit

/// The menu bar icon that shows WhichProfile is running, and its menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private unowned let app: AppDelegate

    init(app: AppDelegate) {
        self.app = app
        super.init()
        if let button = statusItem.button {
            button.image = menuBarIcon()
            button.toolTip = "\(ProjectInfo.name) is running"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// `Resources/icons/menubar.png` (a template image) if present, else an SF Symbol.
    private func menuBarIcon() -> NSImage? {
        let image: NSImage?
        if let url = Bundle.main.url(forResource: "menubar", withExtension: "png", subdirectory: "icons") {
            image = NSImage(contentsOf: url)
            image?.size = NSSize(width: 18, height: 18)
        } else {
            image = NSImage(systemSymbolName: "person.crop.circle.badge.questionmark", accessibilityDescription: ProjectInfo.name)
                ?? NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: ProjectInfo.name)
        }
        image?.isTemplate = true
        return image
    }

    // Rebuilt every time the menu opens, so the default-browser and login-item status are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "\(ProjectInfo.name) \(ProjectInfo.version)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if isDefaultBrowser() {
            let ok = NSMenuItem(title: "✓ Default browser", action: nil, keyEquivalent: "")
            ok.isEnabled = false
            menu.addItem(ok)
        } else {
            menu.addItem(item("Make Default Browser…", #selector(AppDelegate.makeDefaultFromMenu)))
        }
        menu.addItem(.separator())

        menu.addItem(item("Settings…", #selector(AppDelegate.showSettings), key: ","))

        let login: NSMenuItem
        if !LoginItem.isSupported {
            login = NSMenuItem(title: "Open at Login (needs macOS 13)", action: nil, keyEquivalent: "")
            login.isEnabled = false
        } else {
            login = item(LoginItem.needsApproval ? "Open at Login (approve in System Settings)" : "Open at Login",
                         #selector(AppDelegate.toggleLoginItem))
            login.state = LoginItem.isEnabled ? .on : .off
        }
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("About \(ProjectInfo.name)", #selector(AppDelegate.showAbout)))
        let quit = NSMenuItem(title: "Quit \(ProjectInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = app
        return item
    }
}
