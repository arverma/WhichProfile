import AppKit

// MARK: - Icons

/// Returns a copy of a template image filled with `color`.
private func tinted(_ image: NSImage, with color: NSColor) -> NSImage {
    let copy = image.copy() as! NSImage
    copy.lockFocus()
    color.set()
    NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
    copy.unlockFocus()
    copy.isTemplate = false
    return copy
}

/// The private-window icon: `Resources/icons/private.png` if present, else an SF Symbol.
private func privateWindowIcon() -> NSImage? {
    if let url = Bundle.main.url(forResource: "private", withExtension: "png", subdirectory: "icons"),
       let image = NSImage(contentsOf: url) {
        image.size = NSSize(width: 15, height: 15)
        return image
    }
    let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
    return NSImage(systemSymbolName: "eyeglasses", accessibilityDescription: "Private window")?
        .withSymbolConfiguration(config)
}

// MARK: - Row

final class RowView: NSView {
    /// 1-based shortcut number, nil when there are more than nine profiles.
    let number: Int?
    let title: String
    var selected = false { didSet { needsDisplay = true } }
    /// True while ⌥ is held: every click opens a private window.
    var privateMode = false { didSet { needsDisplay = true } }
    var onHover: (() -> Void)?
    /// Called with true when the private-window icon was clicked.
    var onPick: ((Bool) -> Void)?

    private var overIcon = false { didSet { needsDisplay = true } }
    private var iconRect: NSRect { NSRect(x: bounds.width - 38, y: (bounds.height - 20) / 2, width: 28, height: 20) }

    init(number: Int?, title: String, frame: NSRect) {
        self.number = number
        self.title = title
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { updateHover(event) }
    override func mouseMoved(with event: NSEvent) { updateHover(event) }
    override func mouseExited(with event: NSEvent) { overIcon = false }
    override func mouseDown(with event: NSEvent) { onPick?(iconRect.contains(convert(event.locationInWindow, from: nil))) }

    private func updateHover(_ event: NSEvent) {
        overIcon = iconRect.contains(convert(event.locationInWindow, from: nil))
        if !selected { onHover?() }
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { "Open in \(title)" }
    override func accessibilityPerformPress() -> Bool { onPick?(false); return true }

    override func draw(_ dirtyRect: NSRect) {
        if selected {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 6, yRadius: 6).fill()
        }
        let fg: NSColor = selected ? .white : .labelColor
        let dim: NSColor = selected ? NSColor.white.withAlphaComponent(0.75) : .secondaryLabelColor
        let font = NSFont.systemFont(ofSize: 13)
        let y = (bounds.height - font.boundingRectForFont.height) / 2
        if let number = number {
            NSAttributedString(string: "\(number)",
                               attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                                            .foregroundColor: dim])
                .draw(at: NSPoint(x: 16, y: y + 1))
        }
        NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: fg])
            .draw(at: NSPoint(x: 38, y: y))

        // Private-window button, always visible, brighter on hover or while ⌥ is held.
        let active = privateMode || overIcon
        if overIcon {
            (selected ? NSColor.white.withAlphaComponent(0.25) : NSColor.controlAccentColor.withAlphaComponent(0.15)).setFill()
            NSBezierPath(roundedRect: iconRect, xRadius: 5, yRadius: 5).fill()
        }
        if let icon = privateWindowIcon() {
            let color: NSColor = active ? (selected ? .white : .controlAccentColor) : dim
            let image = tinted(icon, with: color)
            let size = image.size
            image.draw(at: NSPoint(x: iconRect.midX - size.width / 2, y: iconRect.midY - size.height / 2),
                       from: .zero, operation: .sourceOver, fraction: 1)
        }
    }
}

// MARK: - Footer button

/// A labelled, clickable text button along the bottom edge of the popup.
final class FooterButton: NSView {
    var title: String { didSet { needsDisplay = true } }
    var onPick: (() -> Void)?
    private var hovering = false { didSet { needsDisplay = true } }

    init(title: String, frame: NSRect) {
        self.title = title
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func mouseDown(with event: NSEvent) { onPick?() }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { title }
    override func accessibilityPerformPress() -> Bool { onPick?(); return true }

    override func draw(_ dirtyRect: NSRect) {
        if hovering {
            NSColor.labelColor.withAlphaComponent(0.08).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 2), xRadius: 6, yRadius: 6).fill()
        }
        let font = NSFont.systemFont(ofSize: 12)
        let text = NSAttributedString(string: title, attributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - font.boundingRectForFont.height) / 2))
    }
}

// MARK: - Panel

final class PickerPanel: NSPanel {
    var onKey: ((NSEvent) -> Void)?
    var onFlagsChanged: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { onKey?(event) }
    override func flagsChanged(with event: NSEvent) { onFlagsChanged?() }
}

// MARK: - LinkPicker controller

final class LinkPicker {
    private let profiles: [Profile]
    /// Called once with the chosen profile and whether to use a private window, or nil if dismissed.
    private let onFinish: (Profile?, Bool) -> Void
    private var panel: PickerPanel?
    private var rows: [RowView] = []
    private var header: NSTextField?
    private var host = ""
    private var link: URL?
    private var selected = 0
    private var clickMonitor: Any?

    /// Called when the user chooses "Edit profiles…"; the popup closes first.
    var onSettings: (() -> Void)?

    init(profiles: [Profile], onFinish: @escaping (Profile?, Bool) -> Void) {
        self.profiles = profiles
        self.onFinish = onFinish
    }

    /// `url` is the link as it will be opened (already cleaned); `cleaned` says tracking was removed.
    func show(url: URL, cleaned: Bool = false, preselect: Int, notice: String? = nil) {
        close()
        link = url
        host = url.host ?? url.absoluteString

        let width: CGFloat = 240
        let rowH: CGFloat = 28
        let headerH: CGFloat = cleaned ? 42 : 26
        let captionH: CGFloat = 20
        let noticeH: CGFloat = notice == nil ? 0 : 22
        let footerH: CGFloat = 30
        let pad: CGFloat = 4
        let height = headerH + CGFloat(profiles.count) * rowH + captionH + noticeH + footerH + pad

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .menu
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true

        let headerLabel = NSTextField(labelWithString: "")
        headerLabel.font = .systemFont(ofSize: 11, weight: .medium)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.lineBreakMode = .byTruncatingMiddle
        headerLabel.frame = NSRect(x: 16, y: height - 22, width: width - 32, height: 16)
        effect.addSubview(headerLabel)
        header = headerLabel

        if cleaned {
            let note = NSTextField(labelWithString: "✓ Tracking removed from this link")
            note.font = .systemFont(ofSize: 10)
            note.textColor = .systemGreen
            note.frame = NSRect(x: 16, y: height - 38, width: width - 32, height: 14)
            effect.addSubview(note)
        }

        rows = []
        for (i, profile) in profiles.enumerated() {
            let y = height - headerH - CGFloat(i + 1) * rowH
            let row = RowView(number: i < 9 ? i + 1 : nil, title: profile.name,
                              frame: NSRect(x: 0, y: y, width: width, height: rowH))
            row.onHover = { [weak self] in self?.select(i) }
            row.onPick = { [weak self] viaIcon in self?.pick(i, isPrivate: viaIcon) }
            effect.addSubview(row)
            rows.append(row)
        }

        // Always-visible hint, so the private-window option is never hidden.
        let caption = NSTextField(labelWithString: "⌥-click or the glasses: private window")
        caption.font = .systemFont(ofSize: 10)
        caption.textColor = .tertiaryLabelColor
        caption.lineBreakMode = .byTruncatingTail
        caption.frame = NSRect(x: 16, y: footerH + noticeH + 3, width: width - 32, height: 14)
        effect.addSubview(caption)

        if let notice = notice {
            let label = NSTextField(labelWithString: notice)
            label.font = .systemFont(ofSize: 10)
            label.textColor = .systemOrange
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSRect(x: 16, y: footerH + 4, width: width - 32, height: 14)
            effect.addSubview(label)
        }

        let separator = NSBox(frame: NSRect(x: 12, y: footerH, width: width - 24, height: 1))
        separator.boxType = .separator
        effect.addSubview(separator)

        let half = width / 2
        let copyButton = FooterButton(title: "Copy link", frame: NSRect(x: 0, y: 0, width: half, height: footerH))
        copyButton.onPick = { [weak self, weak copyButton] in self?.copyLink(feedback: copyButton) }
        effect.addSubview(copyButton)
        let editButton = FooterButton(title: "Edit profiles…", frame: NSRect(x: half, y: 0, width: half, height: footerH))
        editButton.onPick = { [weak self] in self?.openSettings() }
        effect.addSubview(editButton)

        // Place the panel next to the cursor (where the link was just clicked), kept on screen.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main!
        let vis = screen.visibleFrame
        var origin = NSPoint(x: mouse.x + 8, y: mouse.y - height - 8)
        if origin.x + width > vis.maxX { origin.x = mouse.x - width - 8 }
        if origin.x < vis.minX { origin.x = vis.minX + 4 }
        if origin.y < vis.minY { origin.y = mouse.y + 8 }
        if origin.y + height > vis.maxY { origin.y = vis.maxY - height - 4 }

        let p = PickerPanel(contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        p.contentView = effect
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.onKey = { [weak self] e in self?.handle(e) }
        p.onFlagsChanged = { [weak self] in self?.refreshPrivateMode() }
        panel = p

        select(min(max(preselect, 0), profiles.count - 1))
        refreshPrivateMode()
        p.makeKeyAndOrderFront(nil)

        // Clicks outside the panel are delivered to other apps, so a global monitor sees them.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.finish(nil, isPrivate: false)
        }
    }

    // MARK: State

    private var optionHeld: Bool { NSEvent.modifierFlags.contains(.option) }

    /// Reflects ⌥ in the header and the icons, so the user can see what a click will do.
    private func refreshPrivateMode() {
        let priv = optionHeld
        header?.stringValue = priv ? "Open \(host) in a private window…" : "Open \(host) in…"
        header?.textColor = priv ? .controlAccentColor : .secondaryLabelColor
        for r in rows { r.privateMode = priv }
    }

    private func select(_ i: Int) {
        selected = i
        for (j, r) in rows.enumerated() { r.selected = (j == i) }
    }

    private func handle(_ e: NSEvent) {
        let command = e.modifierFlags.contains(.command)
        let isPrivate = e.modifierFlags.contains(.option)
        switch e.keyCode {
        case 53: finish(nil, isPrivate: false)                              // esc
        case 36, 76: pick(selected, isPrivate: isPrivate)                   // return / enter
        case 125: select((selected + 1) % rows.count)                       // down
        case 126: select((selected - 1 + rows.count) % rows.count)          // up
        case 43: openSettings()                                             // comma, with or without ⌘
        default:
            guard let c = e.charactersIgnoringModifiers else { return }
            if command && c.lowercased() == "c" { copyLink(feedback: nil); return }
            if let n = Int(c), n >= 1, n <= min(9, profiles.count) { pick(n - 1, isPrivate: isPrivate) }
        }
    }

    // MARK: Actions

    private func pick(_ i: Int, isPrivate: Bool) { finish(profiles[i], isPrivate: isPrivate || optionHeld) }

    private func openSettings() {
        close()
        onSettings?()
    }

    private func copyLink(feedback button: FooterButton?) {
        guard let link = link else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link.absoluteString, forType: .string)
        button?.title = "Copied ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.finish(nil, isPrivate: false)
        }
    }

    private func finish(_ profile: Profile?, isPrivate: Bool) {
        close()
        onFinish(profile, isPrivate)
    }

    /// Tears down the panel without reporting a result (used before re-showing).
    private func close() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
    }
}
