# Evaluation Strategy: Apple Platform (iOS, macOS, visionOS, tvOS, watchOS)

This document guides the evaluator setup and verification approach for Apple platform apps built with SwiftUI, UIKit, or AppKit.

## Available Verification Tools

### Tier 1 — Apple's Native Xcode MCP (Built-in)

Available in recent Xcode versions with MCP bridge support. Provides build, test, preview, and diagnostics without any additional setup.

**Key tools:**
- `BuildProject` — build a scheme, catch compile errors
- `GetBuildLog` — structured build diagnostics with filtering
- `RunAllTests` / `RunSomeTests` — run test suites
- `GetTestList` — discover available tests
- `RenderPreview` — render SwiftUI previews as screenshots (critical for UI verification)
- `XcodeListNavigatorIssues` — warnings and errors
- `DocumentationSearch` — search Apple docs

**Setup:** Enable in the project's `.claude/settings.json` or `.claude/settings.local.json`:
```json
{
  "permissions": {
    "allow": ["mcp__xcode__*"]
  }
}
```

The Xcode MCP requires Xcode to be open with the project loaded. When starting a session, the evaluator should check if the Xcode MCP is connected and prompt to reconnect if needed.

**Limitation:** Cannot run the app, interact with UI, or control the simulator. Only build, test, and preview.

### Tier 2 — iOS Simulator Interaction (Recommended)

**joshuayoes/ios-simulator-mcp** (1,800 stars, recommended by Anthropic)

Enables full UI interaction with apps running in the iOS Simulator:
- `ui_tap` — tap at coordinates
- `ui_swipe` — swipe gestures
- `ui_type` — text input
- `ui_describe_all` — full screen accessibility tree (read all UI elements)
- `ui_describe_point` — accessibility element at specific coordinates
- `ui_view` — compressed screenshot returned to LLM
- `screenshot` — save screenshot to file

**Installation:**
```bash
npm install -g ios-simulator-mcp
```

**Claude Code MCP config** (add to `.claude/settings.json`):
```json
{
  "mcpServers": {
    "ios-simulator": {
      "command": "npx",
      "args": ["-y", "ios-simulator-mcp"]
    }
  }
}
```

**Dependency:** Requires Facebook IDB (`idb`):
```bash
brew install idb-companion
pipx install fb-idb
```

**Known issue:** Taps inside ScrollViews may fail silently due to `delaysContentTouches`. If this is a problem, consider the IndigoHID fork by adoosh-afk which uses native touch injection.

### Tier 3 — App Lifecycle via AppleScript

Xcode MCP cannot run or stop the app. Use AppleScript for that:

```bash
# Run the app
osascript -e 'tell application "Xcode" to tell workspace document "MyApp.xcodeproj" to run'

# Stop the app
osascript -e 'tell application "Xcode" to tell workspace document "MyApp.xcodeproj" to stop'
```

After running, verify the app started:
```bash
sleep 3 && pgrep -x "MyApp" && echo "Running" || echo "Not running"
```

### Tier 4 — Simulator Management via CLI

`xcrun simctl` provides simulator control from the command line:

```bash
# Boot a simulator
xcrun simctl boot "iPhone 16 Pro"

# Take a screenshot
xcrun simctl io booted screenshot /tmp/screenshot.png

# Set dark mode
xcrun simctl ui booted appearance dark

# Open a deep link
xcrun simctl openurl booted "myapp://settings"

# Send a push notification
xcrun simctl push booted com.example.myapp notification.json

# Install an app
xcrun simctl install booted /path/to/MyApp.app

# Launch an app with console output
xcrun simctl launch --console booted com.example.myapp
```

## Evaluation Checklist for Apple Platform Apps

### Always Do
1. **Build the project** — a build failure is an automatic FAIL
2. **Run the test suite** — test failures are automatic FAILs
3. **Take SwiftUI preview screenshots** (via `RenderPreview`) for any new or changed views
4. **Check for new compiler warnings** — compare against baseline

### When the Mission Involves UI
5. **Run the app in the simulator** (via AppleScript or `xcrun simctl`)
6. **Navigate to the affected screens** (via ios-simulator-mcp or manually describe what to check)
7. **Take screenshots** of the implemented UI
8. **Read the accessibility tree** (`ui_describe_all`) to verify all elements are labeled
9. **Test interaction flows** — tap buttons, fill forms, navigate between screens

### When the Mission Involves Data
10. **Verify data persistence** — create data, restart the app, verify it's still there
11. **Test edge cases** — empty states, maximum values, special characters

### Never Do
- Never mark PASS without building the project
- Never mark PASS without running the test suite
- Never assume UI correctness from code alone — take screenshots
- Never skip regression testing — verify existing screens still work

## Role File Template

During init, create `HarnessKit/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
[Apple platform type: iOS / macOS / visionOS / multi-platform]

## Build & Test
- Build command: [xcodebuild command or Xcode MCP BuildProject]
- Test command: [xcodebuild test command or Xcode MCP RunAllTests]
- Build scheme: [scheme name]
- Test scheme: [test scheme name]

## UI Verification Tools
- Xcode MCP: RenderPreview for SwiftUI preview screenshots
- [ios-simulator-mcp: tap, swipe, accessibility tree, screenshots] (if installed)
- [AppleScript: run/stop app via Xcode] (if applicable)
- [xcrun simctl: simulator management] (always available)

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do
- Build the project before evaluating
- Run the full test suite
- Take screenshots of changed UI via RenderPreview
- [Project-specific rules]

## Never Do
- Mark PASS without a successful build
- Mark PASS without running tests
- Assume UI looks correct without screenshots
- [Project-specific rules]
```
