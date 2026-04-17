# Evaluation Strategy: Android (Native + Flutter)

This document guides the evaluator setup and verification approach for Android apps — native (Kotlin/Java with Jetpack Compose, Views, or both) and Flutter apps targeting Android.

**Guiding principle:** Use Google's official **Android CLI** (released April 2026) for build, device management, and UI verification on Android. Prefer the CLI over improvised adb scripting. For Flutter-specific build/test needs, use the `flutter` CLI alongside Android CLI for device/screenshot operations.

## Primary Tool — Android CLI

**Source:** Google/Android — [github.com/android/skills](https://github.com/android/skills) (skill repo) · [developer.android.com/tools/agents](https://developer.android.com/tools/agents) (download) · [developer.android.com/tools/agents/android-cli](https://developer.android.com/tools/agents/android-cli) (command reference)

Android CLI is Google's official agent-first command-line tool for Android development. It consolidates SDK management, project scaffolding, emulator control, APK deployment, and UI inspection into a single binary — roughly the Android equivalent of what XcodeBuildMCP does for Apple platforms.

**Platforms:** macOS ✓ · Linux ✓ · Windows (partial — `android emulator` is currently disabled on Windows)

**Installation:** Download from [developer.android.com/tools/agents](https://developer.android.com/tools/agents). Follow the site's platform-specific instructions. After install, run `android init` to set up the environment and install the baseline `android-cli` skill for any detected agents. Keep it current with `android update`.

### Key commands for evaluation

| Command | What it does |
|---|---|
| `android create` / `android create list` | Scaffold a new project from official templates |
| `android describe` | Analyze project structure and build artifacts |
| `android sdk install` / `list` / `remove` / `update` | SDK component management |
| `android emulator create` / `list` / `start` / `stop` | Virtual device lifecycle |
| `android run` | Build and deploy APK to a device or emulator |
| `android screen capture --output ui.png` | Take a screenshot from the connected device |
| `android screen capture --output ui.png --annotate` | Screenshot with UI element labels overlaid |
| `android screen resolve --screenshot ui.png --string "input tap #5"` | Translate a labeled element to tap coordinates |
| `android layout --output hierarchy.json` / `--pretty` / `--diff` | Dump the UI layout tree as JSON |
| `android docs` | Search Android's Knowledge Base for official guidance |
| `android skills list` / `add` / `remove` / `find` | Manage Android skills for the Evaluator/Generator |

**Core verification loop for UI missions:**

```bash
android emulator start --name Pixel_8          # boot if not already running
android run --variant debug                    # build + install + launch
android screen capture --output /tmp/ui.png --annotate
android layout --output /tmp/layout.json --pretty
android screen resolve --screenshot /tmp/ui.png --string "input tap #3"
```

### Android Skills (companion instruction modules)

Google also ships [`android/skills`](https://github.com/android/skills) — an agent-skills repository with specialized guidance for common Android tasks. Install through the CLI:

```bash
android skills add --all --agent=claude-code
```

`--agent` accepts a comma-separated list; omit it to install into every detected agent directory. Pass `--skill=<name>` to install a single skill.

**Skills currently published include:**

- Navigation 3 setup and migration
- Edge-to-edge system UI modernization
- AGP 9 upgrade (Android Gradle Plugin)
- XML-to-Compose migration
- R8 configuration analysis and auditing
- Play Billing Library updates

The Generator should load the relevant skill automatically once installed — they activate on task keywords (e.g., "make my app edge-to-edge").

## Flutter Projects

Flutter apps use their own tooling for the build/test loop — **`flutter` CLI is primary** — but Android CLI still handles the Android device/emulator and screenshot layer.

**Primary Flutter commands:**

```bash
flutter pub get                              # fetch dependencies
flutter analyze                              # static analysis (must pass)
flutter test                                 # unit + widget tests
flutter test integration_test                # integration tests (if present)
flutter build apk --debug                    # produce APK
flutter drive --target=integration_test/app_test.dart   # drive the running app
```

**Use Android CLI for:** emulator lifecycle (`android emulator start/stop`), installing Flutter-built APKs onto a device (`android run` picks up the latest build), and UI screenshots/layout dumps after launch.

**Note:** If the Flutter project also targets iOS, follow `ApplePlatform.md` for the iOS side. Both strategies apply.

## Fallback — adb + gradlew

Always available if Android CLI has issues or an older setup is in place:

```bash
adb devices
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell screencap -p /sdcard/shot.png && adb pull /sdcard/shot.png
./gradlew assembleDebug
./gradlew test connectedAndroidTest
```

Prefer Android CLI when available — it wraps the same primitives with agent-friendly defaults and avoids the stale `sdkmanager` / cask situation on macOS.

## Evaluation Checklist

### Always Do
1. **Build** — `android run` (native) or `flutter build apk --debug` (Flutter). Build failure = automatic FAIL.
2. **Run the test suite** — `./gradlew test` (+ `connectedAndroidTest` if the mission touches instrumented code) or `flutter test` (+ integration_test if present). Test failure = FAIL.
3. **Static analysis** — `./gradlew lint` (native) or `flutter analyze` (Flutter). New warnings should be addressed.
4. **Check for new compiler warnings** via the build output.

### When the Mission Involves UI
5. **Boot an emulator** — `android emulator start` (or confirm a physical device is attached: `adb devices`).
6. **Launch the app** — `android run` or deploy the Flutter-built APK.
7. **Screenshot** — `android screen capture --output /tmp/ui.png --annotate`.
8. **Read the layout tree** — `android layout --pretty` to verify the expected element hierarchy.
9. **Test interaction flows** — `android screen resolve ... --string "input tap #N"` to translate labels into tap coordinates, then drive through the key flows from the spec.
10. **For Flutter:** prefer `flutter drive` with an integration test over ad-hoc screen-resolve clicks when the app has a stable widget-key vocabulary.

### When the Mission Involves Logic/Algorithm
11. **Runtime verification** — unit tests with real inputs; for Flutter, widget tests that exercise the state.
12. **Code coverage** — `./gradlew jacocoTestReport` or `flutter test --coverage` and inspect `coverage/lcov.info`.

### When the Mission Involves Documentation or Content
Not every mission produces code. For documentation/content missions:
13. **Verify claims against primary sources** — `android docs` for Android API claims, Flutter's official docs for framework claims, and the actual source files in this repo for project claims.
14. **Read the files the spec references**, not just the documentation itself.
15. Build/test is not required for PASS unless the spec includes code changes.

### Never Do
- Never mark PASS without building.
- Never mark PASS without running tests.
- Never assume UI correctness from code alone — take a screenshot and read the layout tree.
- Never skip regression testing.
- Don't scrape together ad-hoc adb loops when Android CLI already exposes the operation — the CLI output is structured and agent-friendly, raw adb is not.

## Role File Template

During init, create `TandemKit/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
[Native Android / Flutter / Flutter + iOS]

## Build & Test
- Build: `android run --variant debug` (native) or `flutter build apk --debug`
- Test: `./gradlew test` (+ `connectedAndroidTest`) or `flutter test` (+ `integration_test`)
- Static analysis: `./gradlew lint` or `flutter analyze`
- Fallback: `./gradlew assembleDebug`, `adb install -r …`

## UI Verification (Android CLI)
- Emulator: `android emulator start --name [AVD]`
- Launch: `android run` (native) or `flutter run -d <deviceId>` (Flutter)
- Screenshot: `android screen capture --output /tmp/ui.png --annotate`
- Layout tree: `android layout --pretty --output /tmp/layout.json`
- Tap by label: `android screen resolve --screenshot /tmp/ui.png --string "input tap #N"`
- Flutter integration test: `flutter drive --target=integration_test/app_test.dart`

## Installed Android Skills
[Output of `android skills list` — Navigation 3, Edge-to-edge, AGP 9, XML→Compose, R8, etc.]

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do (Code Missions)
- Build via Android CLI / flutter CLI before evaluating
- Run the full test suite
- Take annotated screenshots of changed UI
- Dump layout JSON for UI diffs between rounds

## Always Do (Documentation/Content Missions)
- Verify every claim against the source files referenced in the Spec
- Use `android docs` to cross-check Android API claims
- Read the actual source code, not just the documentation being reviewed

## Never Do
- Mark PASS without a successful build (code missions)
- Mark PASS without running tests (code missions)
- Mark PASS without source verification (documentation missions)
- Assume UI correctness without screenshots
```
