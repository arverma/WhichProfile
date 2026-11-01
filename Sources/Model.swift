import Foundation

/// A Chrome profile the user can open a link in.
struct Profile: Equatable {
    /// Chrome's directory name, e.g. "Default" or "Profile 3". Passed to `--profile-directory`.
    let dir: String
    /// Name shown in the picker.
    var name: String
}
