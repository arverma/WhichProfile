# Profile Picker

A tiny macOS app that asks **which Chrome profile** to open a link in. When you click a link in any app (Slack, Mail, Notes…), a small popup appears next to your cursor listing your Chrome profiles. Pick one by clicking it, pressing its number, or using the arrow keys and Return.

- Lists your Chrome profiles, detected automatically or declared in a small config file
- Popup appears at the cursor, kept on screen
- Pre-selects the profile you used last, so Return repeats it
- Native Swift/AppKit, no dependencies, no network access, no telemetry
- Quits after every use, so nothing runs in the background

## Requirements

- macOS 12 or later
- Xcode command-line tools (`xcode-select --install`) for `swiftc` and `codesign`; full Xcode is not needed
- Google Chrome

## Build and install

```bash
./build.sh
```

This builds the app, signs it ad hoc, and installs it to `~/Applications/ProfilePicker.app`.

Then set it as your default browser: System Settings → Desktop & Dock → Default web browser → **Profile Picker**.

If macOS blocks the first launch, run:

```bash
xattr -d com.apple.quarantine ~/Applications/ProfilePicker.app
```

## Usage

Click a link in any app other than Chrome. The popup appears at the cursor:

| Action | Key |
|---|---|
| Open in profile *n* (first nine) | `1`–`9` |
| Move selection | `↑` / `↓` or hover |
| Open selected | `Return` or click |
| Edit your profiles | click **Edit profiles…** or press `,` |
| Dismiss | `Esc` or click elsewhere |

Links clicked inside Chrome itself never go through the default browser, so they are not intercepted.

## Settings window

Open **Profile Picker** like any app (Spotlight, Finder, Launchpad), or choose **Edit profiles…** in the popup. There you can:

- **Rename** a profile by double-clicking its name (or the pencil next to it; Return saves, Esc cancels), **reorder** by dragging, and **remove** it with the trash icon at the end of its row (or the Delete key on a selected row)
- **Add Profile…** by entering its directory (the dialog explains where to find it) and a name
- **Detect from Chrome** to import your profiles automatically. If macOS blocks reading Chrome's data, you are asked to select Chrome's data folder (`~/Library/Application Support/Google/Chrome`), which grants access
- Choose whether the **last used profile is pre-selected**
- See whether Profile Picker is your **default browser** and fix it with one button

Changes are saved automatically to the config file described below, so there is no Save button.

## Profiles: detection and config

The picker first tries to read your profiles from Chrome's `Local State` file. **Recent macOS versions block apps from reading other apps' data**, so on many Macs this fails. When it does, the popup shows only "Default" with an orange "Can't read Chrome profiles" note.

You have two ways to fix that:

1. **Declare your profiles** (recommended, needs no special permission). The easy way is the interactive setup:

   ```bash
   ~/Applications/ProfilePicker.app/Contents/MacOS/ProfilePicker --setup
   ```

   It shows your profiles as a numbered list with a one-line menu:

   ```
   [a] Add   [e] Rename   [d] Delete   [u] Move up   [s] Save   [q] Quit
   ```

   Pick a letter, optionally followed by a number or directory (`d 2`, `a Profile 3`), or just press the letter and answer the question. Nothing is written until you press `s`, and `q` asks before discarding changes. The list starts from your saved profiles (or from Chrome's own list if it can be read), so running setup again edits what you have rather than starting over. The previous config is saved as `config.json.bak` and other settings are kept.

   Or edit `~/.config/profile-picker/config.json` by hand:

   ```json
   {
     "profiles": [
       { "dir": "Default",   "name": "Personal" },
       { "dir": "Profile 3", "name": "Work" }
     ]
   }
   ```

   `dir` is Chrome's profile directory name. To find it, open `chrome://version` in that profile and read the last part of "Profile Path". When `profiles` is set, auto-detection is skipped.

2. **Grant Full Disk Access** to `~/Applications/ProfilePicker.app` in System Settings → Privacy & Security → Full Disk Access. Profiles are then detected automatically, including new ones. This is a broad permission, so only do it if you're comfortable with that.

## Configuration (optional)

Besides `profiles`, the config file supports the keys below. Every key is optional:

```json
{
  "hidden": ["Profile 5"],
  "order": ["Profile 3", "Default"],
  "labels": { "Profile 3": "Work" },
  "rememberLast": true
}
```

| Key | Meaning |
|---|---|
| `profiles` | Profiles declared by hand, replacing auto-detection |
| `hidden` | Profiles to leave out of the popup |
| `order` | Profiles to list first, in this order; the rest follow in Chrome's order |
| `labels` | Override the display name of a profile |
| `rememberLast` | Pre-select the last-used profile (default `true`) |

Keys are Chrome profile directory names (`Default`, `Profile 1`, `Profile 2`, …). To see the list the picker would show:

```bash
~/Applications/ProfilePicker.app/Contents/MacOS/ProfilePicker --list-profiles
```

It prints `directory<TAB>name` for each profile the picker would show. An invalid config file is ignored and logged.

## How it works

The app registers for `http` and `https` links. Profiles come from the `profile.info_cache` section of Chrome's `Local State` file. On a link it shows the popup at the mouse position, then runs:

```bash
open -na "Google Chrome" --args --profile-directory="Profile 3" "<url>"
```

The `-n` flag is needed so Chrome receives `--profile-directory` even when it is already running.

## Project layout

```
Sources/      app code (profile list and config, launcher, popup, settings window, --setup)
Resources/    Info.plist, the app icon and the settings window icons (icons/)
Scripts/      icon generator
Tests/        dependency-free tests, run with Tests/run.sh
build.sh      build and install
```

## Tests

```bash
./Tests/run.sh
```

Covers profile parsing, config handling, the editable profile list, `--setup` flows, last-used selection and the launch command. The UI itself (popup and settings window) is not covered by automated tests.

## Command line

```
ProfilePicker --setup           interactively create the config file
ProfilePicker --list-profiles   print the profiles the picker would show
ProfilePicker --help            show usage
```

## Debugging

Actions are logged to `~/Library/Logs/ProfilePicker.log`. URLs are not logged.

Two environment variables help when developing or testing without touching your real files:

| Variable | Effect |
|---|---|
| `PROFILE_PICKER_CONFIG` | Use this config file path instead of `~/.config/profile-picker/config.json` |
| `PROFILE_PICKER_LOG` | Write the log here instead of `~/Library/Logs/ProfilePicker.log` |

## Known limitations

- Chrome only; other Chromium browsers are not supported yet
- Ad-hoc signed, so other Macs will need the `xattr` step above
- Only the first nine profiles get number shortcuts

## License

MIT, see [LICENSE](LICENSE).
