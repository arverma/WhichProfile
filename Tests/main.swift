// Minimal dependency-free test runner (XCTest isn't available with just the command-line tools).
// Run with Tests/run.sh.
import Foundation

var failures = 0

func check(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition {
        failures += 1
        print("FAIL (line \(line)): \(message)")
    }
}

func profile(_ dir: String, _ name: String? = nil) -> Profile { Profile(dir: dir, name: name ?? dir) }

// MARK: - parseLocalState

let localState = """
{
  "profile": {
    "info_cache": {
      "Profile 10": { "name": "Ten" },
      "Profile 3":  { "name": "QuillBot" },
      "Default":    { "name": "Aman" },
      "Profile 2":  { "name": "" },
      "Guest Profile": { "name": "Guest" }
    }
  }
}
""".data(using: .utf8)!

let parsed = parseLocalState(localState)
check(parsed.map(\.dir) == ["Default", "Profile 2", "Profile 3", "Profile 10", "Guest Profile"],
      "profiles sort Default, then numerically, then others; got \(parsed.map(\.dir))")
check(parsed.first(where: { $0.dir == "Profile 3" })?.name == "QuillBot", "uses display name")
check(parsed.first(where: { $0.dir == "Profile 2" })?.name == "Profile 2", "empty name falls back to dir")
check(parseLocalState(Data("not json".utf8)).isEmpty, "invalid JSON yields no profiles")
check(parseLocalState(Data("{}".utf8)).isEmpty, "missing info_cache yields no profiles")

// MARK: - arrange

let base = [profile("Default"), profile("Profile 1", "One"), profile("Profile 2", "Two")]

check(arrange(base, with: Config()) == base, "empty config leaves list unchanged")

var hide = Config(); hide.hidden = ["Profile 1"]
check(arrange(base, with: hide).map(\.dir) == ["Default", "Profile 2"], "hidden profiles are removed")

var hideAll = Config(); hideAll.hidden = ["Default", "Profile 1", "Profile 2"]
check(arrange(base, with: hideAll) == base, "hiding everything falls back to the full list")

var order = Config(); order.order = ["Profile 2", "Missing", "Default"]
check(arrange(base, with: order).map(\.dir) == ["Profile 2", "Default", "Profile 1"],
      "order is applied, unknown entries ignored, rest keep original order")

var dupOrder = Config(); dupOrder.order = ["Profile 1", "Profile 1"]
check(arrange(base, with: dupOrder).map(\.dir) == ["Profile 1", "Default", "Profile 2"], "duplicate order entries are not repeated")

var labels = Config(); labels.labels = ["Profile 1": "Work", "Profile 2": ""]
let labelled = arrange(base, with: labels)
check(labelled.first(where: { $0.dir == "Profile 1" })?.name == "Work", "labels rename profiles")
check(labelled.first(where: { $0.dir == "Profile 2" })?.name == "Two", "empty label is ignored")

// MARK: - loadConfig

let tmp = NSTemporaryDirectory() + "whichprofile-test-\(UUID().uuidString).json"
defer { try? FileManager.default.removeItem(atPath: tmp) }

check(loadConfig(path: tmp) == Config(), "missing config file gives defaults")

try? #"{ "hidden": ["Profile 5"], "rememberLast": false }"#.write(toFile: tmp, atomically: true, encoding: .utf8)
let loaded = loadConfig(path: tmp)
check(loaded.hidden == ["Profile 5"] && loaded.rememberLast == false && loaded.order.isEmpty,
      "partial config decodes with defaults for missing keys")

try? "{ broken".write(toFile: tmp, atomically: true, encoding: .utf8)
check(loadConfig(path: tmp) == Config(), "invalid config gives defaults")

// MARK: - initialSelection

check(initialSelection(in: base, lastUsed: "Profile 2", config: Config()) == 2, "preselects last used")
check(initialSelection(in: base, lastUsed: "Gone", config: Config()) == 0, "unknown last used falls back to first")
check(initialSelection(in: base, lastUsed: nil, config: Config()) == 0, "no last used selects first")
var noRemember = Config(); noRemember.rememberLast = false
check(initialSelection(in: base, lastUsed: "Profile 2", config: noRemember) == 0, "rememberLast=false selects first")

// MARK: - resolveProfiles

var explicit = Config(); explicit.profiles = [ConfiguredProfile(dir: "Profile 3", name: "Work"), ConfiguredProfile(dir: "Profile 7", name: nil)]
var detectCalled = false
let fromConfig = resolveProfiles(config: explicit, detect: { detectCalled = true; return base })
check(fromConfig.profiles == [profile("Profile 3", "Work"), profile("Profile 7")], "configured profiles are used, name defaults to dir")
check(!detectCalled && fromConfig.warning == nil, "configured profiles skip detection")

let fromDetect = resolveProfiles(config: Config(), detect: { base })
check(fromDetect.profiles == base && fromDetect.warning == nil, "detected profiles are used when no config")

let fallback = resolveProfiles(config: Config(), detect: { nil })
check(fallback.profiles == [profile("Default")] && fallback.warning != nil, "failed detection falls back to Default with a warning")

try? #"{ "profiles": [{ "dir": "Profile 3", "name": "Work" }, { "dir": "Default" }] }"#.write(toFile: tmp, atomically: true, encoding: .utf8)
check(loadConfig(path: tmp).profiles == [ConfiguredProfile(dir: "Profile 3", name: "Work"), ConfiguredProfile(dir: "Default", name: nil)],
      "profiles decode from config JSON")

// MARK: - link cleaning

func cleaned(_ s: String) -> String { cleanLink(URL(string: s)!).url.absoluteString }
func removedNames(_ s: String) -> [String] { cleanLink(URL(string: s)!).removed }

check(cleaned("https://example.com/a?utm_source=x&utm_medium=y&id=5") == "https://example.com/a?id=5", "utm_* removed, other parameters kept")
check(cleaned("https://example.com/a?id=5&fbclid=abc&page=2") == "https://example.com/a?id=5&page=2", "fbclid removed from the middle, order kept")
check(cleaned("https://example.com/a?gclid=1") == "https://example.com/a", "a query of only trackers disappears, including the ?")
check(cleaned("https://example.com/?utm_campaign=x#section") == "https://example.com/#section", "fragment is kept")
check(cleaned("https://example.com/a?q=caf%C3%A9&utm_source=x") == "https://example.com/a?q=caf%C3%A9", "kept parameters are not re-encoded")
check(cleaned("https://example.com/a?UTM_Source=x&FBCLID=1&x=1") == "https://example.com/a?x=1", "matching ignores case")
check(cleaned("https://example.com/a?utm%5Fsource=x&x=1") == "https://example.com/a?x=1", "percent-encoded names are recognised")
check(cleaned("https://example.com/a?x=1&&y=2&utm_term=z") == "https://example.com/a?x=1&y=2", "empty pairs are dropped when rewriting")
check(removedNames("https://example.com/?utm_source=a&gclid=b&q=1") == ["utm_source", "gclid"], "reports which parameters were removed")

// links that must not change
for untouched in ["https://example.com/a?id=5&ref=home&token=abc&si=xyz",
                  "https://example.com/a",
                  "https://example.com/#/route?utm_source=x",
                  "mailto:me@example.com?subject=x&utm_source=y",
                  "file:///tmp/a.html?utm_source=x"] {
    check(cleaned(untouched) == untouched && removedNames(untouched).isEmpty, "unchanged: \(untouched)")
}
check(cleaned("https://example.com/a?utm_source") == "https://example.com/a", "a tracker name without a value is removed")

var cleanOff = Config(); cleanOff.cleanLinks = false
check(prepareLink(URL(string: "https://e.com/?utm_source=x")!, config: cleanOff).url.absoluteString == "https://e.com/?utm_source=x", "cleaning can be switched off")
check(prepareLink(URL(string: "https://e.com/?utm_source=x")!, config: Config()).url.absoluteString == "https://e.com/", "cleaning is on by default")
check(!String(data: try! encodeConfig(Config()), encoding: .utf8)!.contains("cleanLinks"), "default cleanLinks is omitted from generated JSON")
check(String(data: try! encodeConfig(cleanOff), encoding: .utf8)!.contains("\"cleanLinks\" : false"), "cleanLinks=false is written")
try? #"{ "cleanLinks": false }"#.write(toFile: tmp, atomically: true, encoding: .utf8)
check(loadConfig(path: tmp).cleanLinks == false, "cleanLinks decodes from config")

// MARK: - launch arguments

check(chromeLaunchArguments(url: URL(string: "https://example.com")!, profile: profile("Profile 3"), isPrivate: true) ==
      ["-na", "Google Chrome", "--args", "--profile-directory=Profile 3", "--incognito", "https://example.com"],
      "private mode adds --incognito before the URL")
check(!chromeLaunchArguments(url: URL(string: "https://example.com")!, profile: profile("Default")).contains("--incognito"),
      "normal mode has no --incognito")


let url = URL(string: "https://example.com/a?b=c")!
check(chromeLaunchArguments(url: url, profile: profile("Profile 3")) ==
      ["-na", "Google Chrome", "--args", "--profile-directory=Profile 3", "https://example.com/a?b=c"],
      "launch arguments target the right profile and URL")

// MARK: - setup

/// Runs setup with scripted answers against a temp config path. Returns (wrote, output, path).
func runScripted(_ inputs: [String], detect: [Profile]?, existing: String? = nil) -> (Bool, String, String) {
    let path = NSTemporaryDirectory() + "pp-setup-\(UUID().uuidString)/config.json"
    if let existing = existing {
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try? existing.write(toFile: path, atomically: true, encoding: .utf8)
    }
    var remaining = inputs
    var output = ""
    let io = SetupIO(read: { remaining.isEmpty ? nil : remaining.removeFirst() }, write: { output += $0 })
    let wrote = runSetup(io: io, detect: { detect }, path: path)
    return (wrote, output, path)
}

func saved(_ r: (Bool, String, String)) -> [ConfiguredProfile] { loadConfig(path: r.2).profiles }
func cp(_ dir: String, _ name: String) -> ConfiguredProfile { ConfiguredProfile(dir: dir, name: name) }

check(isValidProfileDir("Profile 3") && isValidProfileDir("Default"), "normal profile dirs are valid")
check(!isValidProfileDir("") && !isValidProfileDir("../x") && !isValidProfileDir("a/b") && !isValidProfileDir("-flag"),
      "empty, traversal, slash and leading dash are rejected")

let two = #"{ "profiles": [{ "dir": "Profile 3", "name": "Work" }, { "dir": "Default", "name": "Home" }] }"#

// adding, with the directory inline or asked for
let added = runScripted(["a Profile 3", "Work", "a", "Default", "", "s"], detect: nil)
check(added.0 && saved(added) == [cp("Profile 3", "Work"), cp("Default", "Default")], "add profiles inline and by prompt; got \(saved(added))")
check(added.1.contains("chrome://version"), "adding explains where to find the directory")

let invalid = runScripted(["a ../x", "a Profile 3", "", "s"], detect: nil)
check(saved(invalid) == [cp("Profile 3", "Profile 3")] && invalid.1.contains("doesn't look like"), "invalid directories are rejected")

let dup = runScripted(["a Profile 3", "s"], detect: nil, existing: two)
check(saved(dup).count == 2 && dup.1.contains("already in the list"), "adding an existing directory is refused")

let cancelAdd = runScripted(["a", "", "s"], detect: nil, existing: two)
check(saved(cancelAdd).count == 2, "empty directory cancels adding")

// editing an existing list
let renamed = runScripted(["e 1", "Work2", "s"], detect: nil, existing: two)
check(saved(renamed) == [cp("Profile 3", "Work2"), cp("Default", "Home")], "rename by number")

let renamedAsked = runScripted(["e", "2", "Casa", "s"], detect: nil, existing: two)
check(saved(renamedAsked) == [cp("Profile 3", "Work"), cp("Default", "Casa")], "rename asks for the number when omitted")

let deleted = runScripted(["d 2", "s"], detect: nil, existing: two)
check(saved(deleted) == [cp("Profile 3", "Work")], "delete by number")

let moved = runScripted(["u 2", "s"], detect: nil, existing: two)
check(saved(moved) == [cp("Default", "Home"), cp("Profile 3", "Work")], "move up swaps with the previous profile")

let badNumber = runScripted(["d 9", "d x", "s"], detect: nil, existing: two)
check(saved(badNumber).count == 2 && badNumber.1.contains("Enter a number from 1 to 2"), "bad numbers are rejected without changes")

let unknown = runScripted(["zzz", "s"], detect: nil, existing: two)
check(unknown.1.contains("Type a letter") && saved(unknown).count == 2, "unknown commands are explained")

// saving and quitting
let emptySave = runScripted(["s", "q"], detect: nil)
check(!emptySave.0 && !FileManager.default.fileExists(atPath: emptySave.2) && emptySave.1.contains("Add at least one"),
      "saving an empty list is refused and writes nothing")

let quitClean = runScripted(["q"], detect: nil, existing: two)
check(!quitClean.0 && !FileManager.default.fileExists(atPath: quitClean.2 + ".bak"), "quitting with no changes writes nothing")

let quitDiscard = runScripted(["d 1", "q", "y"], detect: nil, existing: two)
check(!quitDiscard.0 && loadConfig(path: quitDiscard.2).profiles.count == 2, "quitting with changes asks, and discards on y")

let quitKeep = runScripted(["d 1", "q", "n", "s"], detect: nil, existing: two)
check(quitKeep.0 && saved(quitKeep) == [cp("Default", "Home")], "answering n keeps editing")

let eof = runScripted(["a Profile 3"], detect: nil)
check(!eof.0 && !FileManager.default.fileExists(atPath: eof.2), "input ending mid-flow writes nothing")

// seeding and settings
let fromChrome = runScripted(["s"], detect: [profile("Default", "Aman"), profile("Profile 1", "Work")])
check(fromChrome.0 && saved(fromChrome) == [cp("Default", "Aman"), cp("Profile 1", "Work")], "starts from Chrome's profiles when readable")

let chromeQuit = runScripted(["q", "y"], detect: [profile("Default")])
check(!chromeQuit.0 && !FileManager.default.fileExists(atPath: chromeQuit.2), "unsaved Chrome-detected profiles ask before quitting")

let baked = runScripted(["s"], detect: nil, existing: #"{ "profiles": [{ "dir": "A" }, { "dir": "B" }, { "dir": "C" }], "hidden": ["B"], "labels": { "A": "Alpha" }, "order": ["C"], "rememberLast": false }"#)
let bakedConfig = loadConfig(path: baked.2)
check(bakedConfig.profiles == [cp("C", "C"), cp("A", "Alpha")] && bakedConfig.hidden.isEmpty && bakedConfig.labels.isEmpty && bakedConfig.order.isEmpty,
      "hidden, labels and order are folded into the saved list; got \(bakedConfig.profiles)")
check(bakedConfig.rememberLast == false, "other settings survive")
check(FileManager.default.fileExists(atPath: baked.2 + ".bak"), "previous config is backed up")

// generated config stays short
let encoded = String(data: try! encodeConfig(Config()), encoding: .utf8)!
check(!encoded.contains("hidden") && !encoded.contains("rememberLast"), "default values are omitted from generated JSON")

// MARK: - ProfileList (settings window model)

var pl = ProfileList(items: [profile("Default", "Home"), profile("Profile 3", "Work")])

do { try pl.add(dir: " Profile 7 ", name: "  School "); check(pl.items.last == profile("Profile 7", "School"), "add trims and names the profile") }
catch { check(false, "add should succeed: \(error)") }
do { try pl.add(dir: "Profile 8", name: ""); check(pl.items.last == profile("Profile 8"), "empty name falls back to the directory") }
catch { check(false, "add with empty name should succeed") }

let before = pl
do { try pl.add(dir: "Profile 3", name: "x"); check(false, "duplicate should throw") }
catch { check(error as? ProfileListError == .duplicate(existingName: "Work"), "duplicate error names the existing profile") }
do { try pl.add(dir: "../x", name: ""); check(false, "invalid should throw") }
catch { check(error as? ProfileListError == .invalidDirectory, "invalid directory is rejected") }
check(pl == before, "failed adds leave the list unchanged")

check(pl.merge([profile("Default", "Renamed elsewhere"), profile("Profile 9", "New")]) == 1
      && pl.items.first(where: { $0.dir == "Default" })?.name == "Home"
      && pl.items.last == profile("Profile 9", "New"),
      "merge adds only new profiles and never overwrites names")

pl.remove(ids: ["Profile 3", "Nope"])
check(pl.items.map(\.dir) == ["Default", "Profile 7", "Profile 8", "Profile 9"], "remove deletes by id and ignores unknown ids")

var mv = ProfileList(items: ["a", "b", "c", "d"].map { profile($0) })
mv.move(from: IndexSet(integer: 0), to: 3)
check(mv.items.map(\.dir) == ["b", "c", "a", "d"], "move forward follows SwiftUI onMove semantics; got \(mv.items.map(\.dir))")
mv.move(from: IndexSet(integer: 3), to: 0)
check(mv.items.map(\.dir) == ["d", "b", "c", "a"], "move to the front")
mv.move(from: IndexSet([0, 1]), to: 4)
check(mv.items.map(\.dir) == ["c", "a", "d", "b"], "moving several items keeps their order; got \(mv.items.map(\.dir))")

let one = removalPrompt(for: ["Work"])
check(one.title == "Remove “Work”?" && one.message.contains("add it back"), "single removal names the profile and says how to restore it")
let many = removalPrompt(for: ["A", "B", "C"])
check(many.title == "Remove 3 profiles?" && many.message.contains("add them back"), "multiple removal uses plural wording")

// MARK: - legacy config migration

let migDir = NSTemporaryDirectory() + "wp-mig-\(UUID().uuidString)"
let legacyFile = migDir + "/old/config.json", newFile = migDir + "/new/config.json"
try? FileManager.default.createDirectory(atPath: migDir + "/old", withIntermediateDirectories: true)
try? #"{ "rememberLast": false }"#.write(toFile: legacyFile, atomically: true, encoding: .utf8)
check(migrateLegacyConfig(to: newFile, from: legacyFile) && loadConfig(path: newFile).rememberLast == false, "legacy config is copied to the new location")
try? #"{ "rememberLast": true }"#.write(toFile: newFile, atomically: true, encoding: .utf8)
check(!migrateLegacyConfig(to: newFile, from: legacyFile) && loadConfig(path: newFile).rememberLast == true, "an existing new config is never overwritten")
check(!migrateLegacyConfig(to: migDir + "/x/config.json", from: migDir + "/missing.json"), "nothing is copied when there is no legacy file")

// MARK: - project info

let diag = ProjectInfo.diagnostics(profileCount: 4, isDefaultBrowser: true)
check(diag.contains("WhichProfile") && diag.contains("Profiles configured: 4") && diag.contains("Default browser: yes"), "diagnostics list version, profile count and default-browser status")
check(!diag.contains("http") && !diag.contains("@"), "diagnostics contain no links or addresses")
check(ProjectInfo.repository.absoluteString == "https://github.com/arverma/WhichProfile" && ProjectInfo.issues.absoluteString.hasSuffix("/issues"), "project links point at the repository")

// MARK: - external links (the app's own links must never route back into the app)

let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
let safariURL = URL(fileURLWithPath: "/Applications/Safari.app")
check(chooseExternalBrowser(lookup: { $0 == "com.google.Chrome" ? chromeURL : $0 == "com.apple.Safari" ? safariURL : nil }) == chromeURL, "Chrome is preferred for the app's own links")
check(chooseExternalBrowser(lookup: { $0 == "com.apple.Safari" ? safariURL : nil }) == safariURL, "Safari is used when Chrome is missing")
check(chooseExternalBrowser(lookup: { _ in nil }) == nil, "no browser found gives nil")
check(!externalBrowserIdentifiers.contains("io.github.arverma.whichprofile"), "the app never picks itself for its own links")

// MARK: - launch policy

check(isLoginLaunch(appleEventSaysLoginItem: true, systemUptime: 99999), "the login-item Apple event marks a login launch")
check(isLoginLaunch(appleEventSaysLoginItem: false, systemUptime: 30), "a launch just after boot counts as a login launch")
check(!isLoginLaunch(appleEventSaysLoginItem: false, systemUptime: 3600), "a launch long after boot is a manual launch")
check(shouldShowSettingsOnLaunch(receivedLink: false, loginLaunch: false, backgroundFlag: false), "a manual launch opens settings")
check(!shouldShowSettingsOnLaunch(receivedLink: true, loginLaunch: false, backgroundFlag: false), "a launch caused by a link stays quiet")
check(!shouldShowSettingsOnLaunch(receivedLink: false, loginLaunch: true, backgroundFlag: false), "a login launch stays quiet")
check(!shouldShowSettingsOnLaunch(receivedLink: false, loginLaunch: false, backgroundFlag: true), "--background stays quiet")

// MARK: - shared config helpers

let storedConfig = configByStoring([profile("A", "Alpha"), profile("B", "")],
                                   in: { var c = Config(); c.hidden = ["Z"]; c.labels = ["A": "x"]; c.order = ["B"]; c.rememberLast = false; return c }())
check(storedConfig.profiles == [cp("A", "Alpha"), cp("B", "B")], "stored profiles use the directory for empty names")
check(storedConfig.hidden.isEmpty && storedConfig.labels.isEmpty && storedConfig.order.isEmpty && !storedConfig.rememberLast,
      "storing a list folds in hidden/labels/order and keeps other settings")

let seedSaved = initialProfileList(config: { var c = Config(); c.profiles = [cp("A", "Alpha")]; return c }(), detect: { base })
check(seedSaved.list == [profile("A", "Alpha")] && !seedSaved.fromChrome, "saved profiles win over detection")
let seedDetected = initialProfileList(config: Config(), detect: { base })
check(seedDetected.list == base && seedDetected.fromChrome, "detected profiles seed the list when nothing is saved")
check(initialProfileList(config: Config(), detect: { nil }).list.isEmpty, "empty when nothing saved or detected")

let savePath = NSTemporaryDirectory() + "pp-save-\(UUID().uuidString)/config.json"
check(try saveConfig(Config(), to: savePath, backup: true) == false, "first save makes no backup")
check(try saveConfig(Config(), to: savePath, backup: false) == false && !FileManager.default.fileExists(atPath: savePath + ".bak"), "backup:false never backs up")
check(try saveConfig(Config(), to: savePath, backup: true) == true && FileManager.default.fileExists(atPath: savePath + ".bak"), "backup:true copies the previous file")
check(String(data: FileManager.default.contents(atPath: savePath)!, encoding: .utf8)!.hasSuffix("\n"), "saved file ends with a newline")

if failures == 0 { print("All tests passed") } else { print("\(failures) test(s) failed"); exit(1) }
