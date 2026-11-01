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

let tmp = NSTemporaryDirectory() + "profile-picker-test-\(UUID().uuidString).json"
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

// MARK: - launch arguments

let url = URL(string: "https://example.com/a?b=c")!
check(chromeLaunchArguments(url: url, profile: profile("Profile 3")) ==
      ["-na", "Google Chrome", "--args", "--profile-directory=Profile 3", "https://example.com/a?b=c"],
      "launch arguments target the right profile and URL")

if failures == 0 { print("All tests passed") } else { print("\(failures) test(s) failed"); exit(1) }
