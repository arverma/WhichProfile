# Contributing to WhichProfile

Thanks for helping. WhichProfile aims to stay **small, simple and private**, so the best contributions fix bugs, improve clarity and polish what is already there.

## Build and test

You need a Mac with the Xcode command-line tools (`xcode-select --install`). Full Xcode is not required, and the project must keep building without it.

```bash
./Tests/run.sh   # runs the logic tests
./build.sh       # builds and installs ~/Applications/WhichProfile.app
```

`Tests/run.sh` compiles the non-UI sources with a small dependency-free test runner (XCTest is not available with only the command-line tools).

## Guidelines

- **Test the logic.** New behaviour in profile handling, config, link cleaning or launching needs a test, and the test should fail without your change.
- **Try the UI by hand.** The popup and settings window are not covered by automated tests. Describe what you checked in your pull request, in light and dark mode if you changed layout.
- **Do not use `@State`.** On machines with only the command-line tools its macro plugin is missing and the project will not compile. Keep view state in an `ObservableObject` (see `SettingsStore`).
- **Keep features visible.** Anything the app can do needs a labelled control. Keyboard shortcuts are shortcuts, never the only way in.
- **Stay private.** No network access, no analytics, and never write links to disk or the log.
- **Match the surrounding code**: naming, comment density and idiom.

## What this project will not become

To keep it simple, these are out of scope: per-site routing rules or a rules engine, scripting, other browsers, and auto-updating. If you need those, apps such as Finicky or Choosy are a better fit.

## Pull requests

1. Open an issue first for anything bigger than a small fix.
2. Keep each pull request to one change, and update `CHANGELOG.md` under an "Unreleased" heading.
3. Make sure `./Tests/run.sh` passes.

## Reporting bugs

Use the issue templates, and paste **About → Copy diagnostics**. It contains the version, macOS version and profile count, but no links or names.
