# Evaluation Strategy: Apple Platform (iOS, macOS, visionOS, tvOS, watchOS)

This document guides the evaluator setup and verification approach for Apple platform apps built with SwiftUI, UIKit, or AppKit.

**Guiding principle:** Use Xcode MCP for IDE-native verification, XcodeBuildMCP for autonomous Apple build/run/test and iOS/simulator UI automation, and **Peekaboo CLI for runtime UI automation of running macOS apps** (where XcodeBuildMCP has no GUI tools). Prefer CLI over MCP unless the MCP mode is known-good in the current client.

## Primary Tools

### XcodeBuildMCP (Build, Run, Test, UI Automation, Debugging)

**GitHub:** [getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) — ~5,000 stars, MIT, actively maintained by Sentry

The primary tool for Apple platform evaluation. Provides 76 CLI tools across 14 workflow groups (82 in MCP mode): build, test, run (simulator + device + macOS), UI automation (tap, swipe, type, screenshot, accessibility tree), simulator management, LLDB debugging, log capture, code coverage, and more.

**Key capabilities for evaluation:**
- `build_sim` / `build_run_sim` — build and optionally launch in simulator
- `test_sim` — run tests with structured results
- `screenshot` — capture simulator screen
- `snapshot_ui` — full accessibility tree with coordinates
- `tap` / `swipe` / `type_text` / `gesture` — interact like a user
- `start_sim_log_cap` / `stop_sim_log_cap` — capture runtime logs
- `get_coverage_report` — check test coverage
- `debug_attach_sim` / `debug_variables` / `debug_stack` — LLDB debugging

**Preferred transport: CLI mode.** The project was refactored CLI-first (PR #197) and `xcodebuildmcp init` installs the CLI skill by default. CLI avoids MCP connectivity issues (#220, #210) and orphaned process risks.

**Installation:**
```bash
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp
xcodebuildmcp init
```

`xcodebuildmcp init` is an interactive skill installer — choose **user-level** and the **CLI** variant (not MCP). It installs the official Claude Code skill to `~/.claude/skills/`, priming the Evaluator with the right commands and workflows. Re-run it after major version upgrades.

Or without global install (MCP mode for Codex):
```json
"XcodeBuildMCP": {
  "command": "npx",
  "args": ["-y", "xcodebuildmcp@latest", "mcp"],
  "env": { "XCODEBUILDMCP_SENTRY_DISABLED": "true" }
}
```

**Configuration:** Enable needed workflows upfront in `.xcodebuildmcp/config.yaml` — dynamic workflow discovery is not well supported by current clients.

**Telemetry:** Disable by default with `XCODEBUILDMCP_SENTRY_DISABLED=true` in env.

**Known issues:**
- `snapshot_ui` may return empty on iOS 26+ fresh simulators (#290) — enable both accessibility defaults: `xcrun simctl spawn booted defaults write com.apple.Accessibility AccessibilityEnabled 1 && xcrun simctl spawn booted defaults write com.apple.Accessibility ApplicationAccessibilityEnabled 1`
- Test output may be truncated (#177) — fall back to `xcodebuild test` via Bash for full output
- Security: prompt injection via build output (#291) and shell injection PRs open (#289, #292) — be cautious with untrusted dependencies
- MCP mode: tool visibility issues reported (#220) — use CLI mode if 0 tools appear

### Apple's Native Xcode MCP (IDE-Native Verification)

Provides capabilities XcodeBuildMCP doesn't natively have:

- `RenderPreview` — render SwiftUI previews as screenshots (unique, critical for UI verification)
- `ExecuteSnippet` — compile and run Swift code in project context (unique, powerful for algorithm verification)
- `DocumentationSearch` — search Apple docs and WWDC transcripts
- `XcodeListNavigatorIssues` — live warnings and errors
- `GetBuildLog` — structured build diagnostics

**Setup:** Enable in `.claude/settings.json`:
```json
{ "permissions": { "allow": ["mcp__xcode__*"] } }
```

Requires Xcode to be open with the project loaded. XcodeBuildMCP has an optional Xcode IDE bridge, but it's still buggy (#252) — use Apple's MCP directly for these tools.

## Fallback Tools

### xcrun simctl + raw xcodebuild

Always available, no dependencies. Use when XcodeBuildMCP has issues:

```bash
xcrun simctl boot "iPhone 16 Pro"
xcrun simctl io booted screenshot /tmp/screenshot.png
xcodebuild build -scheme App -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Removed from Recommendations

- **mobile-mcp** — broken on Xcode 26 (WDA incompatibility), subsumed by XcodeBuildMCP for iOS
- **ios-simulator-mcp** — stale, requires IDB, strict subset of XcodeBuildMCP
- **AppleScript for app lifecycle** — subsumed by XcodeBuildMCP's `build_run_sim` / `stop_app_sim`

## Platform-Specific Notes

### iOS / visionOS — Full Support
XcodeBuildMCP provides complete build/run/test/UI automation for simulator and device.

### macOS — Build/Test + Peekaboo for Runtime UI Verification
XcodeBuildMCP supports `build_run_macos`, `test_macos`, `launch_mac_app`, `stop_mac_app` but has **no macOS GUI automation tools** (tap, accessibility tree for running macOS apps). For runtime UI verification use **Peekaboo CLI** — it exposes the macOS Accessibility tree as structured JSON and provides clicks, typing, menu navigation, screenshots, and dialog helpers. This replaces the old preview-only strategy.

**DO NOT use `mcp__computer-use__*` on macOS** — it times out (30s hardcoded) on complex SwiftUI apps on macOS Tahoe due to a ScreenCaptureKit regression + native compositor filtering.

#### Peekaboo setup (one-time per machine)

Peekaboo is in active beta. Install the latest published version:

```bash
brew install peekaboo
peekaboo --version
peekaboo permissions   # must show Screen Recording + Accessibility granted
```

If permissions aren't granted: System Settings → Privacy & Security → Screen & System Audio Recording AND Accessibility → add the terminal running Peekaboo.

Start the daemon once per boot to stabilize capture and permission checks:

```bash
peekaboo daemon start
peekaboo daemon status
```

#### Core usage pattern: `see → act → verify`

```bash
peekaboo app switch --to "MyApp" --verify
peekaboo list windows --app "MyApp"
SNAP=$(peekaboo see --app "MyApp" --window-id <id> --json --timeout-seconds 30 | jq -r .data.snapshot_id)
peekaboo click --on elem_12 --snapshot "$SNAP"
peekaboo type "new value" --clear
peekaboo see --app "MyApp" --window-id <id> --json  # re-capture to verify
```

**Key commands:** `image` (window screenshot), `see` (AX tree + IDs), `click --on <id>` / `click --coords` / `click "fuzzy"`, `type`, `hotkey`, `press`, `menu list` / `menu click --path`, `dialog --action click --button "…"`, `app switch --to`, `app launch`.

#### Accessibility identifiers are a hard prerequisite for `see`

On SwiftUI apps without `.accessibilityIdentifier(…)` coverage, `peekaboo see` hangs at a 25-second hard cap walking unnamed descendants. **With identifiers the AX walk completes in ~1 second.** Adding identifiers is part of the Generator's responsibility when it touches interactive views. If your Claude setup has a convenience skill for accessibility-identifier conventions (e.g. one named `macos-accessibility-ids`, but actual names vary — scan `~/.claude/skills/`), load it; otherwise follow the standard AppKit/UIKit equivalents (`.accessibilityIdentifier(_:)` on SwiftUI, `setAccessibilityIdentifier(_:)` on AppKit, `view.accessibilityIdentifier = …` on UIKit).

**Fallback for apps without identifiers (or non-native apps like Electron):**
1. `peekaboo image` for the screenshot.
2. `peekaboo menu list` + `menu click --path "File > Save"` — exact, no AX walk needed.
3. `peekaboo hotkey --keys "cmd,s"` — fastest and most reliable.
4. `peekaboo click --coords X,Y` from an `image` inspection — last resort.

#### Known quirks

- `see`'s element detection hangs on SwiftUI apps with few/no identifiers. Adding identifiers fixes this.
- Fuzzy `click "label"` can match across apps — always scope with `--window-title` or `--window-id`, or prefer menu-path clicks.
- Focus stealing: every shell call reactivates the terminal as frontmost. Chain multi-step flows in a single `peekaboo run <script.peekaboo.json>` script, or re-focus the target before every click (`peekaboo app switch --to X --verify`).

Full pattern catalog and troubleshooting lives in the Peekaboo CLI's own docs (`peekaboo --help`) and optionally in a user-level convenience skill if your Claude setup has one (a common name is `macos-peekaboo` at `~/.claude/skills/macos-peekaboo/`, but actual names vary — scan `~/.claude/skills/` to see what's installed).

#### When Peekaboo is NOT enough

- **SwiftUI `#Preview` screenshots** via Xcode MCP `RenderPreview` are still the fastest verification for pure view rendering — use them first when the change is isolated to a single view's appearance. Peekaboo is for end-to-end flows against the running app.
- **AppKit with no identifiers** — add them (`setAccessibilityIdentifier(_:)`); `see` works on AppKit the moment identifiers are present. If your setup has a helper skill for accessibility-identifier conventions (example name: `macos-accessibility-ids`), it offers faster naming guidance — but the API calls are standard AppKit regardless.
- **Electron/Chromium-based apps** — AX tree is opaque; fall back to menu paths, hotkeys, and coordinate clicks. Check if the app has an official CLI/extension API first.

## Evaluation Checklist

### Always Do
1. **Build the project** via XcodeBuildMCP CLI (`xcodebuildmcp simulator build`) — build failure = automatic FAIL
2. **Run the test suite** via XcodeBuildMCP CLI (`xcodebuildmcp simulator test`) — test failure = automatic FAIL. If output is truncated, fall back to `xcodebuild test` via Bash.
3. **Take SwiftUI preview screenshots** via Xcode MCP `RenderPreview` for new/changed views
4. **Check for new compiler warnings**

### When the Mission Involves UI (iOS / visionOS / Simulator)
5. **Run the app** via `xcodebuildmcp simulator build-and-run`
6. **Read the accessibility tree** via `xcodebuildmcp ui-automation snapshot-ui`
7. **Take screenshots** via `xcodebuildmcp ui-automation screenshot`
8. **Test interaction flows** via `xcodebuildmcp ui-automation tap` / `swipe` / `type-text`
9. **Capture logs** via `xcodebuildmcp log-capture start-sim-log-cap` / `stop-sim-log-cap`

### When the Mission Involves UI (macOS)
5m. **Build and launch** via `xcodebuildmcp macos build` then `xcodebuildmcp macos launch --app-path …` (or `peekaboo app launch`)
6m. **Read the accessibility tree** via `peekaboo see --app X --window-id <id> --json --timeout-seconds 30` (requires `.accessibilityIdentifier` coverage on interactive views — if missing, add them to the relevant views; your Claude setup may have a helper skill for naming conventions, e.g. something named `macos-accessibility-ids`, if not the standard SwiftUI/AppKit APIs work directly)
7m. **Take screenshots** via `peekaboo image --app X --window-id <id> --path …`
8m. **Test interaction flows** via `peekaboo click --on <id> --snapshot <snap>`, `peekaboo type`, `peekaboo hotkey`, `peekaboo menu click --path "…"`
9m. **Verify backend side-effects via the app's own CLI/API** when the UI writes to a remote service (e.g., `asc` CLI for App Store Connect writes, database reads for DB writes) — do not trust the UI alone

### When the Mission Involves Logic/Algorithm
10. **Runtime verification** via Xcode MCP `ExecuteSnippet` — test with real inputs
11. **Code coverage** via `xcodebuildmcp simulator get-coverage-report`

### When the Mission Involves Documentation, Skills, or Content
Not every mission is a code mission. For documentation/content missions (e.g., writing skill files, updating docs, creating reference material):
12. **Verify claims against primary sources** — the deliverable's claims about tool behavior, APIs, or project conventions must match the actual source code and verified test results
13. **Read the source files referenced in the spec** — don't verify documentation by reading only the documentation itself (that's circular)
14. **Build/test/preview are NOT required for PASS** unless the spec explicitly includes code changes
15. **The "Always Do" checklist above adapts**: for pure content missions, "build the project" is not mandatory — content accuracy IS mandatory

### Never Do
- Never mark PASS without building
- Never mark PASS without running tests
- Never assume UI correctness from code alone — take screenshots and read the accessibility tree
- Never skip regression testing
- **Never use XcodeBuildMCP as an MCP server** — always use the CLI (`xcodebuildmcp <command>`). MCP mode is not configured for this project.
- **Never use `mcp__computer-use__*` on macOS** — it times out on complex SwiftUI apps on Tahoe. Use Peekaboo CLI instead.

## Role File Template

During init, create `TandemKit/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
[Apple platform type: iOS / macOS / visionOS / multi-platform]

## Build & Test (XcodeBuildMCP CLI)
- Build: `xcodebuildmcp simulator build --scheme [scheme] --project-path [path]`
- Test: `xcodebuildmcp simulator test --scheme [scheme] --project-path [path]`
- Run: `xcodebuildmcp simulator build-and-run --scheme [scheme] --project-path [path]`
- Fallback: `xcodebuild build -scheme [scheme] -project [path] -destination '...'`

## UI Verification

### iOS / visionOS / Simulator (XcodeBuildMCP CLI)
- Screenshot: `xcodebuildmcp ui-automation screenshot`
- Accessibility tree: `xcodebuildmcp ui-automation snapshot-ui`
- Tap: `xcodebuildmcp ui-automation tap --element [id]`

### macOS (Peekaboo CLI + Xcode MCP)
- Launch + focus: `peekaboo app launch "[AppName]" --wait-until-ready` then `peekaboo app switch --to "[AppName]" --verify`
- Screenshot: `peekaboo image --app "[AppName]" --window-id <id> --path /tmp/shot.png`
- Accessibility tree (needs identifiers for complex SwiftUI): `peekaboo see --app "[AppName]" --window-id <id> --json --timeout-seconds 30`
- Click / type: `peekaboo click --on <id> --snapshot <snap>`, `peekaboo type "…" --clear`
- Menu navigation: `peekaboo menu click --app "[AppName]" --path "File > Save"`
- Hotkeys: `peekaboo hotkey --keys "cmd,s"`
- **Adding identifiers**: adding `.accessibilityIdentifier(_:)` (SwiftUI) or `setAccessibilityIdentifier(_:)` (AppKit) unlocks fast `see` and stable targeting. If your Claude setup has a convenience skill for naming conventions (e.g. one named like `macos-accessibility-ids`), it's worth a scan; otherwise the API calls are standard.
- **DO NOT use `mcp__computer-use__*` on macOS** — unreliable on Tahoe.

### Shared
- SwiftUI previews: Xcode MCP `RenderPreview`
- Runtime verification: Xcode MCP `ExecuteSnippet`

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do (Code Missions)
- Build via XcodeBuildMCP before evaluating
- Run the full test suite
- Take screenshots of changed UI
- For logic changes: runtime verification via ExecuteSnippet

## Always Do (Documentation/Content Missions)
- Verify every claim against the source files referenced in the Spec
- Read the actual source code, not just the documentation being reviewed
- Check for contradictions between the deliverable and verified test results

## Never Do
- Mark PASS without a successful build (code missions)
- Mark PASS without running tests (code missions)
- Mark PASS without source verification (documentation missions)
- Assume UI looks correct without screenshots
- Use XcodeBuildMCP as an MCP server — always use the CLI (`xcodebuildmcp <command>`)
```
