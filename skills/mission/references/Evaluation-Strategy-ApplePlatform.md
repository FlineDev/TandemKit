# Evaluation Strategy: Apple Platform (iOS, macOS, visionOS, tvOS, watchOS)

This document guides the evaluator setup and verification approach for Apple platform apps built with SwiftUI, UIKit, or AppKit.

**Guiding principle:** Use Xcode MCP for IDE-native verification, use XcodeBuildMCP for autonomous Apple build/run/test/UI automation, and prefer CLI unless MCP is known-good in the current client.

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
xcodebuildmcp init    # installs the CLI skill
```

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

### macOS — Build/Test Only, No GUI Automation
XcodeBuildMCP supports `build_run_macos`, `test_macos`, `launch_mac_app`, `stop_mac_app`. But there are **no macOS GUI automation tools** (tap, screenshot, accessibility tree for macOS apps). For macOS UI verification, use `screencapture` via Bash or manual testing.

## Evaluation Checklist

### Always Do
1. **Build the project** via XcodeBuildMCP CLI (`xcodebuildmcp simulator build`) — build failure = automatic FAIL
2. **Run the test suite** via XcodeBuildMCP CLI (`xcodebuildmcp simulator test`) — test failure = automatic FAIL. If output is truncated, fall back to `xcodebuild test` via Bash.
3. **Take SwiftUI preview screenshots** via Xcode MCP `RenderPreview` for new/changed views
4. **Check for new compiler warnings**

### When the Mission Involves UI (iOS)
5. **Run the app** via `xcodebuildmcp simulator build-and-run`
6. **Read the accessibility tree** via `xcodebuildmcp ui-automation snapshot-ui`
7. **Take screenshots** via `xcodebuildmcp ui-automation screenshot`
8. **Test interaction flows** via `xcodebuildmcp ui-automation tap` / `swipe` / `type-text`
9. **Capture logs** via `xcodebuildmcp log-capture start-sim-log-cap` / `stop-sim-log-cap`

### When the Mission Involves Logic/Algorithm
10. **Runtime verification** via Xcode MCP `ExecuteSnippet` — test with real inputs
11. **Code coverage** via `xcodebuildmcp simulator get-coverage-report`

### Never Do
- Never mark PASS without building
- Never mark PASS without running tests
- Never assume UI correctness from code alone — take screenshots and read accessibility tree
- Never skip regression testing

## Role File Template

During init, create `HarnessKit/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
[Apple platform type: iOS / macOS / visionOS / multi-platform]

## Build & Test (XcodeBuildMCP CLI)
- Build: `xcodebuildmcp simulator build --scheme [scheme] --project-path [path]`
- Test: `xcodebuildmcp simulator test --scheme [scheme] --project-path [path]`
- Run: `xcodebuildmcp simulator build-and-run --scheme [scheme] --project-path [path]`
- Fallback: `xcodebuild build -scheme [scheme] -project [path] -destination '...'`

## UI Verification (XcodeBuildMCP CLI)
- Screenshot: `xcodebuildmcp ui-automation screenshot`
- Accessibility tree: `xcodebuildmcp ui-automation snapshot-ui`
- Tap: `xcodebuildmcp ui-automation tap --element [id]`
- SwiftUI previews: Xcode MCP `RenderPreview`
- Runtime verification: Xcode MCP `ExecuteSnippet`

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do
- Build via XcodeBuildMCP before evaluating
- Run the full test suite
- Take screenshots of changed UI
- For logic changes: runtime verification via ExecuteSnippet

## Never Do
- Mark PASS without a successful build
- Mark PASS without running tests
- Assume UI looks correct without screenshots
```
