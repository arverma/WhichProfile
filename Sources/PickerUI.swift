import AppKit

// MARK: - Row

final class RowView: NSView {
    /// 1-based shortcut number, nil when there are more than nine profiles.
    let number: Int?
    let title: String
    var selected = false { didSet { needsDisplay = true } }
    var onHover: (() -> Void)?
    var onPick: (() -> Void)?

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
    override func mouseEntered(with event: NSEvent) { onHover?() }
    override func mouseMoved(with event: NSEvent) { if !selected { onHover?() } }
    override func mouseDown(with event: NSEvent) { onPick?() }

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
    }
}

// MARK: - Panel

final class PickerPanel: NSPanel {
    var onKey: ((NSEvent) -> Void)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { onKey?(event) }
}

// MARK: - Picker controller

final class Picker {
    private let profiles: [Profile]
    private let onFinish: (Profile?) -> Void
    private var panel: PickerPanel?
    private var rows: [RowView] = []
    private var selected = 0
    private var clickMonitor: Any?

    /// `onFinish` is called once with the chosen profile, or nil if dismissed.
    init(profiles: [Profile], onFinish: @escaping (Profile?) -> Void) {
        self.profiles = profiles
        self.onFinish = onFinish
    }

    func show(url: URL, preselect: Int, notice: String? = nil) {
        close()

        let width: CGFloat = 220
        let rowH: CGFloat = 28
        let headerH: CGFloat = 26
        let pad: CGFloat = 6
        let noticeH: CGFloat = notice == nil ? 0 : 22
        let height = headerH + CGFloat(profiles.count) * rowH + pad + noticeH

        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        effect.material = .menu
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true

        let header = NSTextField(labelWithString: "Open \(url.host ?? url.absoluteString) in…")
        header.font = .systemFont(ofSize: 11, weight: .medium)
        header.textColor = .secondaryLabelColor
        header.lineBreakMode = .byTruncatingMiddle
        header.frame = NSRect(x: 16, y: height - headerH + 4, width: width - 32, height: 16)
        effect.addSubview(header)

        rows = []
        for (i, profile) in profiles.enumerated() {
            let y = height - headerH - CGFloat(i + 1) * rowH
            let row = RowView(number: i < 9 ? i + 1 : nil, title: profile.name,
                              frame: NSRect(x: 0, y: y, width: width, height: rowH))
            row.onHover = { [weak self] in self?.select(i) }
            row.onPick = { [weak self] in self?.pick(i) }
            effect.addSubview(row)
            rows.append(row)
        }

        if let notice = notice {
            let label = NSTextField(labelWithString: notice)
            label.font = .systemFont(ofSize: 10)
            label.textColor = .systemOrange
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSRect(x: 16, y: 6, width: width - 32, height: 14)
            effect.addSubview(label)
        }

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
        panel = p

        select(min(max(preselect, 0), profiles.count - 1))
        p.makeKeyAndOrderFront(nil)

        // Clicks outside the panel are delivered to other apps, so a global monitor sees them.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.finish(nil)
        }
    }

    private func select(_ i: Int) {
        selected = i
        for (j, r) in rows.enumerated() { r.selected = (j == i) }
    }

    private func handle(_ e: NSEvent) {
        switch e.keyCode {
        case 53: finish(nil)                                              // esc
        case 36, 76: pick(selected)                                       // return / enter
        case 125: select((selected + 1) % rows.count)                     // down
        case 126: select((selected - 1 + rows.count) % rows.count)        // up
        default:
            if let c = e.charactersIgnoringModifiers, let n = Int(c), n >= 1, n <= min(9, profiles.count) {
                pick(n - 1)
            }
        }
    }

    private func pick(_ i: Int) { finish(profiles[i]) }

    private func finish(_ profile: Profile?) {
        close()
        onFinish(profile)
    }

    /// Tears down the panel without reporting a result (used before re-showing).
    private func close() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        panel?.orderOut(nil)
        panel = nil
    }
}
