import AppKit

/// The menu bar shown while the settings window is open. The Edit menu matters: without it,
/// ⌘C, ⌘V and ⌘Z do nothing in the rename and Add Profile text fields.
func buildMainMenu(target: AppDelegate) -> NSMenu {
    let main = NSMenu()

    func add(_ menu: NSMenu, _ title: String, _ action: Selector?, _ key: String = "",
             modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = target
        menu.addItem(item)
    }
    func submenu(_ title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        main.addItem(item)
        return menu
    }

    let app = submenu(ProjectInfo.name)
    add(app, "About \(ProjectInfo.name)", #selector(AppDelegate.showAbout), target: target)
    app.addItem(.separator())
    add(app, "Settings…", #selector(AppDelegate.showSettings), ",", target: target)
    app.addItem(.separator())
    add(app, "Hide \(ProjectInfo.name)", #selector(NSApplication.hide(_:)), "h")
    add(app, "Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", modifiers: [.command, .option])
    add(app, "Show All", #selector(NSApplication.unhideAllApplications(_:)))
    app.addItem(.separator())
    add(app, "Quit \(ProjectInfo.name)", #selector(NSApplication.terminate(_:)), "q")

    let edit = submenu("Edit")
    add(edit, "Undo", Selector(("undo:")), "z")
    add(edit, "Redo", Selector(("redo:")), "z", modifiers: [.command, .shift])
    edit.addItem(.separator())
    add(edit, "Cut", #selector(NSText.cut(_:)), "x")
    add(edit, "Copy", #selector(NSText.copy(_:)), "c")
    add(edit, "Paste", #selector(NSText.paste(_:)), "v")
    add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")

    let window = submenu("Window")
    add(window, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
    add(window, "Close", #selector(NSWindow.performClose(_:)), "w")
    NSApp.windowsMenu = window

    let help = submenu("Help")
    add(help, "\(ProjectInfo.name) Help", #selector(AppDelegate.openHelp), "?", target: target)
    add(help, "Release Notes", #selector(AppDelegate.openReleases), target: target)
    add(help, "Report an Issue…", #selector(AppDelegate.openIssues), target: target)
    NSApp.helpMenu = help

    return main
}
