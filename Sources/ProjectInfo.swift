import Foundation

/// Facts about the app shown in the About tab and the menus, in one place.
enum ProjectInfo {
    static let name = "WhichProfile"
    static let tagline = "Choose which Chrome profile opens a link."
    static let author = "Aman Ranjan Verma"
    static let repository = URL(string: "https://github.com/arverma/WhichProfile")!
    static var issues: URL { repository.appendingPathComponent("issues") }
    static var releases: URL { repository.appendingPathComponent("releases") }
    static var license: URL { repository.appendingPathComponent("blob/main/LICENSE") }

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
    static var versionDescription: String { "Version \(version) (\(build))" }

    static let privacyStatement = """
        WhichProfile runs entirely on your Mac. It has no network access, no accounts, no analytics \
        and no tracking. The links you click are handed to Chrome and are never stored, and its log \
        records which profile was used, never the link.
        """

    /// Text a user can paste into a bug report. Contains no links, names or personal data.
    static func diagnostics(profileCount: Int, isDefaultBrowser: Bool) -> String {
        """
        \(name) \(version) (\(build))
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Profiles configured: \(profileCount)
        Default browser: \(isDefaultBrowser ? "yes" : "no")
        """
    }
}
