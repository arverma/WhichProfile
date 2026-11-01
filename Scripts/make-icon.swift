// Generates Resources/AppIcon.icns: a rounded square holding a white popup card with
// three rows, the middle one highlighted. Run via Scripts/make-icon.sh.
import AppKit

func render(size: Int) -> Data {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    // Background squircle with a gradient.
    let bg = NSBezierPath(roundedRect: NSRect(x: s * 0.05, y: s * 0.05, width: s * 0.9, height: s * 0.9),
                          xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(starting: NSColor(red: 0.36, green: 0.40, blue: 0.95, alpha: 1),
               ending: NSColor(red: 0.16, green: 0.55, blue: 0.98, alpha: 1))!.draw(in: bg, angle: -90)

    // Popup card.
    let card = NSRect(x: s * 0.24, y: s * 0.22, width: s * 0.52, height: s * 0.56)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = s * 0.03
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: card, xRadius: s * 0.06, yRadius: s * 0.06).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Rows: the middle one is selected.
    let rowH = card.height / 3
    for i in 0..<3 {
        let r = NSRect(x: card.minX + s * 0.03, y: card.maxY - rowH * CGFloat(i + 1) + s * 0.02,
                       width: card.width - s * 0.06, height: rowH - s * 0.04)
        if i == 1 {
            NSColor(red: 0.20, green: 0.45, blue: 0.97, alpha: 1).setFill()
            NSBezierPath(roundedRect: r, xRadius: s * 0.035, yRadius: s * 0.035).fill()
        }
        (i == 1 ? NSColor.white : NSColor(white: 0.72, alpha: 1)).setFill()
        let dot = NSRect(x: r.minX + s * 0.04, y: r.midY - s * 0.02, width: s * 0.04, height: s * 0.04)
        NSBezierPath(ovalIn: dot).fill()
        NSBezierPath(roundedRect: NSRect(x: dot.maxX + s * 0.03, y: r.midY - s * 0.014,
                                         width: r.width * 0.5, height: s * 0.028),
                     xRadius: s * 0.014, yRadius: s * 0.014).fill()
    }

    img.unlockFocus()
    let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
    return rep.representation(using: .png, properties: [:])!
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon <iconset-dir>\n".utf8))
    exit(1)
}
let dir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)@2x.png"))
}
