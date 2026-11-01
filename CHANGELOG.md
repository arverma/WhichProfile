# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Menu bar icon with a menu: Settings, default-browser status, Open at login, About and Quit.
- **Open at login** option in General and in the menu bar menu (macOS 13 or later).
- `--background` option to start in the menu bar without opening the settings window.

### Changed
- WhichProfile now stays running in the menu bar instead of quitting after each link, and has no Dock icon.
- Opening the app again from Spotlight or Finder shows the settings window. A start caused by a link or by login stays quiet.
- `build.sh` stops the running copy and restarts the new one quietly.

### Fixed
- Links in the About tab and Help menu opened WhichProfile's own picker and then quit the app, because WhichProfile is the default browser. They now open directly in Chrome (or Safari).
- A link arriving from another app while the settings window was open closed the window after you picked a profile. The window now stays open.

## [1.0.0] - 2026-11-01

First release.

### Added
- Popup next to the cursor to choose which Chrome profile opens a link, with mouse, number-key and arrow-key selection.
- Private-window support: click the glasses on a row, or hold ⌥ while choosing.
- Copy link button (⌘C).
- Removal of tracking parameters (`utm_*`, `fbclid`, `gclid` and similar), with a visible note and a setting to turn it off.
- Remembers the last-used profile and pre-selects it.
- Settings window with General, Profiles, Features and About tabs: setup checklist, inline rename, drag to reorder, remove with confirmation, add profile, detect from Chrome, default-browser status and button.
- Menu bar while the settings window is open, including an Edit menu so copy and paste work.
- `--setup`, `--list-profiles` and `--help` command-line options.
- Automatic migration of a config saved under the app's earlier name.
