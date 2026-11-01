import SwiftUI
import AppKit

// MARK: - Features

private struct FeatureInfo {
    let symbol: String
    let title: String
    let text: String
}

private let features: [FeatureInfo] = [
    FeatureInfo(symbol: "person.2", title: "Pick a profile for every link",
                text: "Click a link in any app and a small popup appears next to your cursor. Choose the Chrome profile it should open in. Links clicked inside Chrome itself stay where they are."),
    FeatureInfo(symbol: "eyeglasses", title: "Private windows",
                text: "Click the glasses on a row, or hold ⌥ while you choose, to open the link in a private window of that profile. Chrome profiles managed by an organisation may block private windows."),
    FeatureInfo(symbol: "doc.on.doc", title: "Copy link",
                text: "Copies the link to the clipboard instead of opening it. Use the Copy link button or press ⌘C."),
    FeatureInfo(symbol: "shield", title: "Remove tracking",
                text: "Strips tracking parameters such as utm_*, fbclid and gclid before a link opens. The picker shows a green note when it did, and you can turn this off in General."),
    FeatureInfo(symbol: "clock.arrow.circlepath", title: "Remembers your last choice",
                text: "The profile you used last is highlighted, so pressing Return reopens it."),
    FeatureInfo(symbol: "menubar.rectangle", title: "Lives in your menu bar",
                text: "WhichProfile runs quietly with an icon in the menu bar and no Dock icon. Click the icon to open Settings, check that it is your default browser, turn on Open at login, or quit. If you quit, it starts again the next time you click a link."),
    FeatureInfo(symbol: "slider.horizontal.3", title: "Easy to customise",
                text: "Rename, reorder, add and remove profiles in the Profiles tab, or detect them from Chrome. Changes save automatically."),
    FeatureInfo(symbol: "lock.shield", title: "Private by design", text: ProjectInfo.privacyStatement),
]

private let shortcuts: [(keys: String, meaning: String)] = [
    ("1 – 9", "Open in that profile"),
    ("↑  ↓", "Move the selection"),
    ("Return", "Open in the selected profile"),
    ("⌥", "Hold with any of the above for a private window"),
    ("⌘C", "Copy link"),
    (",", "Edit profiles"),
    ("Esc", "Dismiss the picker"),
]

struct FeaturesTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("What \(ProjectInfo.name) can do").font(.headline)

                ForEach(features, id: \.title) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 18))
                            .foregroundColor(.accentColor)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title).fontWeight(.semibold)
                            Text(feature.text).font(.callout).foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Divider()

                Text("Keyboard shortcuts in the picker").font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(shortcuts, id: \.keys) { shortcut in
                        HStack(spacing: 12) {
                            Text(shortcut.keys)
                                .font(.system(.callout, design: .monospaced))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(5)
                                .frame(width: 80, alignment: .leading)
                            Text(shortcut.meaning).font(.callout)
                        }
                    }
                }

                Divider()

                Text("Command line").font(.headline)
                Text("For advanced use: run the app's executable with --list-profiles to print the profiles it would show, --setup to edit them in Terminal, or --help.")
                    .font(.callout).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - About

struct AboutTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text(ProjectInfo.name).font(.title).fontWeight(.bold)
                Text(ProjectInfo.versionDescription).foregroundColor(.secondary)
                Text(ProjectInfo.tagline)

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Privacy", systemImage: "lock.shield").font(.headline)
                        Text(ProjectInfo.privacyStatement).font(.callout).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                // Buttons, not Link: a Link would hand the URL to the system, which sends it back to this app.
                HStack(spacing: 18) {
                    Button("Source code") { openExternalLink(ProjectInfo.repository) }
                    Button("Release notes") { openExternalLink(ProjectInfo.releases) }
                    Button("Report an issue") { openExternalLink(ProjectInfo.issues) }
                    Button("License") { openExternalLink(ProjectInfo.license) }
                }
                .buttonStyle(.link)

                Button(store.diagnosticsCopied ? "Copied ✓" : "Copy diagnostics for a bug report") { store.copyDiagnostics() }
                Text("The diagnostics contain the version, macOS version and profile count. No links or names.")
                    .font(.footnote).foregroundColor(.secondary)

                Divider()

                Text("Made by \(ProjectInfo.author). Released under the MIT License.")
                    .font(.footnote).foregroundColor(.secondary)
                Text("Chrome is a trademark of Google LLC. \(ProjectInfo.name) is an independent project and is not affiliated with or endorsed by Google.")
                    .font(.footnote).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
    }
}
