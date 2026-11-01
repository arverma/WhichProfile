# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

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
