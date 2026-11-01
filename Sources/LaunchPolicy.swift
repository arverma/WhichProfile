import Foundation

/// WhichProfile now stays running in the menu bar. When it starts it must decide whether to open
/// the settings window: yes if the user launched it by hand, no if it started because of a link,
/// at login, or with `--background`.

/// True if the app was probably started automatically at login. macOS marks login launches with an
/// Apple event property (`keyAELaunchedAsLogInItem`), but that is not reliable for every kind of
/// login item, so a launch within two minutes of boot is also treated as a login launch.
func isLoginLaunch(appleEventSaysLoginItem: Bool, systemUptime: TimeInterval) -> Bool {
    appleEventSaysLoginItem || systemUptime < 120
}

func shouldShowSettingsOnLaunch(receivedLink: Bool, loginLaunch: Bool, backgroundFlag: Bool) -> Bool {
    !receivedLink && !loginLaunch && !backgroundFlag
}
