---
description: Initialize TandemKit in this project. Sets up the coordination folder, configures roles, installs tools, and verifies Codex access.
---

# TandemKit — Project Initialization

> **Note:** This command is for plugin-based distribution only. For local development, use direct symlinks to the TandemKit repo instead — see README.md for setup instructions.

This command sets up TandemKit in the current project. Run it once per project.

## Important UX Rules

Follow these rules throughout the entire init flow:

1. **Do NOT explain what TandemKit is.** The user already knows — they just ran the init command.
2. **Ask questions ONE AT A TIME.** Before each question, write 2-3 sentences of context in chat explaining WHY this matters and what you recommend. Then ask using AskUserQuestion. Never batch multiple questions.
3. **Do NOT install or configure anything without explicit user approval.** Ask first, show what you want to do, get a "yes", then do it.
4. **Before modifying any existing file** (.gitignore, settings.json, config.toml), explain what you want to change and get user approval.
5. **When recommending external tools**, always provide: verified GitHub URL, star count, brief description of what it does, and at least one alternative. Never present a single option as the only choice.
6. **For npm packages, use `npx -y`** (run without global install), never `npm install -g`. Check the user's permission deny list in settings.json — never recommend commands that appear there.
7. **MCP server configurations go in `.mcp.json`** at the project root, NOT in `.claude/settings.json`. MCP tool permissions (allow rules) go in settings.json.
8. **Start brief.** Jump straight to investigation. No preamble, no tutorial.
9. **Before writing any files, show a recap** of all the settings you're about to encode and get user confirmation. This catches misunderstandings before they're baked into config files.

## Pre-Flight Check

1. Verify `TandemKit/` does not already exist in the project root. If it does, tell the user: "TandemKit is already initialized in this project. Config is at TandemKit/Config.json."
2. Check that this is a git repository. If not, warn: "This project is not a git repository. TandemKit works best with git for feature branches and milestone commits. Continue anyway?"

## Step 1 — Install watchman

Check if watchman is installed: `which watchman-wait`

If not installed, tell the user and wait for approval before installing.

## Step 2 — Investigate the Project

Before asking questions, investigate thoroughly. Tell the user: "Let me investigate your project..." then do all of the following:

1. **Read project documentation:**
   - `AGENTS.md` or `CLAUDE.md` — conventions, architecture, commit rules
   - `README.md` — project overview

2. **Detect project type — check for ALL build systems:**
   - `.xcodeproj` or `.xcworkspace` → Apple platform app
   - `Package.swift` → Swift package (can coexist with .xcodeproj!)
   - `package.json` → Node.js / web
   - `pubspec.yaml` → Flutter (may also contain an `android/` + `ios/` folder — treat as multi-platform)
   - `build.gradle` / `build.gradle.kts` / `settings.gradle(.kts)` or an `AndroidManifest.xml` → native Android (Kotlin / Java / Compose)
   - `Cargo.toml` → Rust / `go.mod` → Go
   - **Check submodules:** Read `.gitmodules` if it exists. Check inside submodule directories for build files.
   - **If both Package.swift AND .xcodeproj exist:** Note both and present options.
   - **If Flutter + `ios/` both exist:** note both — the Android CLI covers the Android side, XcodeBuildMCP covers the iOS side.

3. **Check available tools:**
   - Read `~/.claude/settings.json` for global permissions and MCP tool allowances
   - Read project `.claude/settings.json` and `.mcp.json` for project-level MCP servers
   - Check what's already available: Xcode MCP? browser-use CLI (`which browser-use`)? Simulator tools? Android CLI (`which android`)? Flutter CLI (`which flutter`)?

4. **Read commit conventions and branch patterns:**
   - Check AGENTS.md/CLAUDE.md for commit message rules, push policies, branch conventions
   - Run `git branch -a` to see existing branch naming patterns — use these for TandemKit feature branches. Do NOT invent a new convention or add prefixes.
   - Check for git hooks

5. **Read the user's permission deny list** in settings.json.

6. **Discover existing skills:**
   - List `.claude/skills/` contents. Read the name + description of each existing skill.
   - Note which skills are relevant for the Generator (e.g., code context, review skills) and Evaluator (e.g., preview patterns, testing approaches).
   - Reference these in the role files so roles know to load them.

7. **Explore documentation structure beyond AGENTS.md:**
   - Check for research folders, exploration docs, context directories, domain-specific reference material.
   - If found, note them for the Planner.md — the Planner needs to know ALL knowledge sources, not just code docs.

8. **Check Codex permissions** (if `~/.codex/config.toml` exists):
   - Check if bash/shell commands are allowed (sandbox_mode, approval_policy)
   - This determines whether Codex should use CLI or MCP mode for tools

9. **Detect the project name** — used to label session renames so the user can distinguish TandemKit sessions across multiple projects in the session picker:
   - Get the git root: `git rev-parse --show-toplevel 2>/dev/null || pwd`
   - Take the `basename` of that path as the candidate project name.
   - **Generic-folder fallback:** if the basename is one of `App`, `Server`, `Client`, `Frontend`, `Backend`, `Web`, `Mobile`, `iOS`, `macOS`, `Android`, `Desktop`, walk up one level and use the parent's basename instead — these are common umbrella-component folders that are not the project's identity.
   - If the resulting name is still ambiguous (parent also generic, or the user has a custom umbrella layout where the meaningful project name lives a level or two up), surface it in the Step 2 summary and let the user override it during the Step 5 recap.
   - This name will be stored in `Config.json` as `projectName` and read by the Planner / Generator / Evaluator on every session rename.

Present a brief summary of findings to the user before asking the first question. Include the detected project name verbatim so the user can object early if it's wrong.

## Step 3 — Ask Configuration Questions

Ask each question ONE AT A TIME. Before each question, explain briefly in chat why it matters and what you recommend.

### Question 1: Project Type Confirmation

Present your detection results, then ask.

### Question 2: Evaluation Scope

Explain that TandemKit's evaluator can verify different aspects, then ask:

> "What should the Evaluator verify?"

Options:
- Code correctness (build + tests) — always included for code missions
- UI verification (previews, screenshots, interaction) — recommended for apps
- Domain/content verification (verify claims against source material) — for documentation, skill files, knowledge bases
- Accessibility — recommended for apps
- Performance — if relevant

**Domain/content verification must be a first-class option.** Not every mission produces code. Documentation missions, skill file creation, and knowledge base work need source verification as the primary evaluation path.

### Question 3: Tool Setup (Based on Project Type)

**For Apple platform projects:**

Read `${CLAUDE_PLUGIN_ROOT}/skills/evaluator/strategies/ApplePlatform.md` for full details. Recommend XcodeBuildMCP CLI as the primary tool for BOTH Claude and Codex sessions (if both allow bash/shell commands). Only suggest MCP mode if the user's Codex config restricts bash.

Explain to the user that XcodeBuildMCP provides build, test, simulator, UI automation, and screenshot tools — and that you recommend installing it so the Evaluator can do real verification rather than code-reading alone. Ask for confirmation, then install:

```bash
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp
```

Then tell the user to install the official Claude Code skill by pasting the following into a **separate terminal window** and clicking through the prompts (recommended choices: **user-level**, **CLI** variant — not MCP):

```bash
xcodebuildmcp init
```

Ask the user to come back and say "done" when finished so you can verify the skill was installed.

**Detect macOS target and offer Peekaboo (if applicable).**

Run this detection — does the project build for macOS?

```bash
# True if any scheme / xcodebuild destination supports macOS
grep -r "platform = macOS\|SUPPORTED_PLATFORMS.*macosx\|.macOS\|platform=macOS" --include="*.pbxproj" --include="Package.swift" -l . 2>/dev/null | head -1
```

If the project has a macOS target (or is macOS-only), XcodeBuildMCP can build/test/launch but cannot tap/read-AX-tree on the running macOS app. **Recommend installing Peekaboo CLI** so the Evaluator can do real runtime UI verification (screenshots + AX tree + clicks + typing + menu navigation) instead of falling back to preview-only testing. Explain the tradeoff:

> "Your project has a macOS target. XcodeBuildMCP alone can't drive a running macOS app — Apple doesn't expose UI automation there. **Peekaboo CLI** fills that gap: it uses the macOS Accessibility API to capture screenshots, query elements, click, type, and navigate menus. It's an order of magnitude more reliable and token-efficient than Claude's built-in `computer-use` MCP, which has known 30s timeouts on complex SwiftUI apps on macOS Tahoe. It's in active beta — Homebrew has the latest published build."

Ask for confirmation, then run the setup:

```bash
brew install peekaboo
peekaboo --version
peekaboo permissions    # must show Screen Recording + Accessibility granted
```

**If `peekaboo permissions` shows anything as "not granted"**, tell the user to open System Settings → Privacy & Security → (a) Screen & System Audio Recording AND (b) Accessibility → and enable the terminal they use to run `peekaboo`. Wait for them to confirm.

**Start the daemon once** (stabilizes capture on Tahoe):

```bash
peekaboo daemon start
peekaboo daemon status
```

**Check for companion skills the user may have** at `~/.claude/skills/`. Names and availability vary — examples of skills that pair well with Peekaboo workflows:

- A Peekaboo-usage skill (one common name is `macos-peekaboo`) — full Peekaboo usage catalog (see → act → verify loop, gotchas, troubleshooting).
- An accessibility-identifiers skill (one common name is `macos-accessibility-ids`) — how to add `.accessibilityIdentifier(…)` / `setAccessibilityIdentifier(_:)` so `peekaboo see` returns fast AX trees instead of hanging at its 25-second cap.

These names are illustrative — scan `~/.claude/skills/` and surface whatever exists. If nothing similar is installed, the CLI still works directly; inline guidance is just nice-to-have. The Evaluator strategy in `ApplePlatform.md` covers the technique fundamentals regardless of which skills are present.

Ask the user to come back and say "done" when Peekaboo is verified so you can proceed.

**For Android / Flutter projects:**

Read `${CLAUDE_PLUGIN_ROOT}/skills/evaluator/strategies/Android.md` for full details. The primary tool is Google's official **Android CLI** (released 2026-04-16), which consolidates SDK management, emulator control, APK deployment, and UI inspection into a single binary — roughly the Android counterpart of XcodeBuildMCP.

Explain the tradeoff to the user:

> "For Android verification, I recommend Google's official **Android CLI**. It's a single binary with commands for SDK management, emulator lifecycle, builds, screenshots (with annotated UI labels), and layout tree dumps — everything the Evaluator needs to verify UI work without falling back to raw `adb`. It also installs companion **Android skills** (Navigation 3, edge-to-edge, XML→Compose, AGP 9, R8, Play Billing, etc.) that activate automatically when the Generator touches those areas.
>
> Install page: [developer.android.com/tools/agents](https://developer.android.com/tools/agents) · Skills repo: [github.com/android/skills](https://github.com/android/skills) (official, ~3k stars)
>
> macOS and Linux are fully supported. Windows works except for `android emulator`."

**Do NOT install anything automatically.** Ask the user to install the CLI themselves from the download page (it's platform-specific and may require sudo), then come back and say "done." After they confirm, run:

```bash
# Verify install and set up the environment for the current agent (Claude Code).
android --version
android init
```

`android init` installs the baseline `android-cli` skill into the detected agent directories. Then, with user confirmation, offer to add the rest of the official skills:

```bash
android skills add --all --agent=claude-code
```

(Drop `--agent=claude-code` to install for every detected agent. Use `--skill=<name>` for a single skill.)

**For Flutter specifically:** also verify that the `flutter` CLI is on `PATH` (`which flutter`, `flutter doctor`). Flutter's own CLI drives the build/test loop (`flutter build apk`, `flutter test`, `flutter drive`), while Android CLI handles device/emulator and screenshot operations. If the Flutter project also targets iOS, walk through the Apple platform setup too (XcodeBuildMCP + optional Peekaboo for macOS).

**For web projects:**

Read `${CLAUDE_PLUGIN_ROOT}/skills/evaluator/strategies/Web.md` for full details. **Recommend browser-use CLI as the primary browser automation tool.** Explain the tradeoffs:

> "For browser-based verification, I recommend **browser-use CLI** — it uses 10–50× fewer tokens than Playwright MCP for the same operations, which means faster and cheaper evaluations. It runs as a simple CLI command (no MCP server needed) and has built-in session management for parallel testing.
>
> If you already have Playwright MCP configured and prefer to keep it, that works too — I'll set up the evaluation strategy for Playwright instead."

**browser-use setup (if user agrees — recommended):**

1. Check if browser-use is installed: `which browser-use` (also check aliases: `bu`, `browser`, `browseruse`)
2. If not installed, ask for confirmation then install:
   ```bash
   curl -fsSL https://browser-use.com/cli/install.sh | bash
   ```
3. Verify and run initial setup:
   ```bash
   browser-use doctor
   browser-use setup
   ```
4. Tell the user to install the official Claude Code skill by pasting the following into a **separate terminal window** and clicking through the prompts (recommended choices: **Claude Code + Codex**, **user-level**, **symlink**):
   ```bash
   npx skills add https://github.com/browser-use/browser-use --skill browser-use
   ```
   Ask the user to come back and say "done" when finished so you can verify the skill was installed.
5. **Check permissions** — read `~/.claude/settings.json` and project `.claude/settings.json`. Look for a permission `allow` entry that covers `Bash(browser-use *)` — either explicitly or via a broader rule like `Bash(*)` or `Bash`. If no matching permission exists, recommend adding `"Bash(browser-use *)"` to the allow list so browser-use commands run without prompting during evaluation.

**Playwright setup (if user explicitly prefers):**

Read `${CLAUDE_PLUGIN_ROOT}/skills/evaluator/strategies/Web-Playwright.md`. Set up the MCP server in `.mcp.json`:
```json
{
   "mcpServers": {
      "playwright": {
         "command": "npx",
         "args": ["-y", "@anthropic-ai/mcp-playwright"]
      }
   }
}
```

**For CLI/domain projects:** Read the appropriate Evaluation-Strategy reference.

### Question 4: Git Commit Policy

Present what you found in the project's commit conventions and branch patterns, then ask:

> "For TandemKit missions:"

1. Should the Generator make commits automatically at milestones? (default: yes)
2. Should each mission use a feature branch? (default: yes)

**Branch naming:** Show the pattern you detected from existing branches (e.g., "Your branches follow `username/feature-description`"). TandemKit will use the same pattern. Do NOT invent a new convention or add prefixes like "hk-".

**If submodules exist:** Ask specifically about commit scope:
- "Should auto-commits happen in the umbrella repo, in submodules, or submodules only?"
- "Should auto-commits ever happen on the main branch, or only on feature branches?"

**Note on commit message content** (non-configurable — just informing the user): when auto-commit is on, the Generator writes commit titles and bodies that describe the code change only. TandemKit, the Generator/Evaluator roles, missions, and rounds are **never** mentioned in implementation, milestone, final, or PR commits — the history describes the software, not the process that produced it. The sole exception is the optional post-mission commit of the `TandemKit/NNN-MissionName/` text files, where "mission files" may appear. The project can override this in `TandemKit/Generator.md` if a different convention is desired. See the Generator skill §"Commit Messages & PR Text" for the full rule.

### Question 5: Codex Plugin Verification

TandemKit ALWAYS uses Codex alongside Claude — this is not optional. Do NOT ask whether the user wants Codex. Instead, verify the `codex-plugin-cc` plugin is installed:

1. Check if the plugin is available: look for `/codex:setup` command or check `~/.claude/settings.json` for `codex` in enabled plugins
2. If NOT installed, tell the user and provide the install instructions:

   "TandemKit requires the `codex-plugin-cc` plugin (Claude + Codex always work in tandem). Install it first:"

   ```
   /plugin marketplace add openai/codex-plugin-cc
   /plugin install codex@openai-codex
   /reload-plugins
   /codex:setup
   ```

   "After installing and verifying with `/codex:setup`, re-run `/tandemkit:init`."

   Then STOP. Do not continue init without the plugin.

3. If installed: run `/codex:setup` to verify authentication works. If auth fails, tell the user to fix it before continuing.

### Question 6: Codex Reasoning Effort

Explain that TandemKit invokes Codex multiple times per mission (once per Planner round, once per Evaluator round) and the reasoning effort controls how thorough each invocation is — at the cost of token usage and rate-limit pressure on personal Codex accounts. Then ask via AskUserQuestion:

> "What Codex reasoning effort should TandemKit use for this project?"

Present these options (and recommend `high` as the default):

- **high** (recommended) — Very thorough reasoning, friendlier to personal-account rate limits than xhigh. Good default for almost all projects. Codex still finds bugs Claude misses at this level.
- **xhigh** — Maximum effort, slightly more thorough than `high` but burns through Codex tokens noticeably faster. Pick this only for projects where you genuinely need every last bit of reasoning quality and don't mind hitting rate limits sooner.
- **medium** — Faster and cheaper than `high`. Pick this for routine missions in established codebases where deep investigation is rarely needed, or if you're hitting rate limits even on `high`.

The selection is stored in `Config.json` under `codex.effort` and used by every Planner and Evaluator Codex invocation. It can be changed later by editing Config.json directly.

### Question 7: TandemKit Commit Policy

The `TandemKit/` folder contains two kinds of content:

- **Coordination text files** (`State.json`, `Spec.md`, `Claude-NN.md`/`Codex-NN.md` discussion files, `Generator/Round-NN.md`, `Evaluator/Round-NN.md`, etc.) — small, plain-text, high value as an audit trail of the development history.
- **Binary assets** (screenshots and other verification artifacts under `NNN-Mission/Assets/`) — typically WebP screenshots written by the Generator and consumed by the Evaluator. They can add up in repo size if every mission keeps many captures.

Explain both kinds, then ask via AskUserQuestion:

> "What do you want committed to git for TandemKit missions?"

Present three options (default: **Text-only**):

- **Commit everything (text + assets)** — full audit trail including before/after screenshots. Enables linking screenshots from PR descriptions via GitHub's raw URL. Best for projects where UI/visual missions are common and the history is worth keeping. Stores `TandemKit/` untouched in git.
- **Commit text only, gitignore assets (Recommended)** — keeps the full textual audit trail (decisions, discussions, specs, reports) but ignores `TandemKit/*/Assets/` so binary captures don't bloat the repo. Screenshots still live on disk for the active mission; Generator can upload them to a PR separately if needed.
- **Don't commit TandemKit at all** — everything under `TandemKit/` is gitignored. Use if you prefer to keep coordination artifacts out of the repo entirely. The files still exist on disk during the mission.

Store the choice in `Config.json` under `git.tandemKitCommit` with values `"all"` / `"text-only"` / `"none"`. Step 7 writes the matching `.gitignore` entries.

## Step 4 — Check Permissions for Autonomous Operation

**Detection-based:** Only speak up about what's actually missing.

Read `~/.claude/settings.json` and project `.claude/settings.json`. Check for core tools and MCP tools.

If Codex is enabled, check `~/.codex/config.toml`. Only mention issues if restrictive.

## Step 5 — Recap and Confirm

**Before writing any files**, present a summary of everything you're about to encode:

> "Here's what I'll set up:
> - Project name: [detected name] — used to label session renames so this project is recognizable in the session picker. Override now if wrong.
> - Project type: [type]
> - Evaluation scope: [list]
> - Tools: [list]
> - Git: auto-commit [yes/no], scope [where], feature branches [yes/no], branch pattern [pattern]
> - Codex: effort [high/xhigh/medium]
> - TandemKit commit policy: [all / text-only / none]
>
> Does this look right?"

Wait for confirmation. This catches misunderstandings before they're baked into config files.

## Step 6 — Create the TandemKit Directory

Create the folder structure with Config.json, Planner.md, Generator.md, Evaluator.md, and ClaudeEvaluatorPrompt.md.

### ClaudeEvaluatorPrompt.md

Copy from the plugin's `system-prompts/claude-evaluator.md` template. **If the file already exists** (re-init): do NOT overwrite. Ask first.

This file is NOT modified by the self-learning system — keep it stable.

### Config.json

The `codex.effort` field stores the Codex reasoning effort answered in Question 6 — this is the only Codex setting (whether Codex is used at all is non-negotiable).

The `namingConvention` field captures how identifiers are cased in this project — used by `create-mission.sh` for folder names AND by the Generator/Evaluator when naming `Assets/` files. Auto-detect from existing branch and file patterns; present the detected value in the recap. Valid values: `"PascalCase"`, `"camelCase"`, `"kebab-case"`, `"snake_case"`. When in doubt, ask the user with an example of what a mission folder would look like (`003-AddDarkMode` vs `003-add-dark-mode` vs `003-add_dark_mode`).

The `projectName` field captures the human-readable project identity (auto-detected from git root in Step 2.9, with the generic-folder walk-up applied) — used by the Planner / Generator / Evaluator to label session renames so the user can recognize which TandemKit project a given session belongs to in the session picker. The recap (Step 5) is the explicit confirmation gate — if the user wants to override the detected name there, write the override.

Do NOT add `learnings` sections to any role file — the self-learning system has been removed.

```json
{
  "currentMission": null,
  "nextMissionNumber": 1,
  "projectName": "[detected/confirmed project name]",
  "projectType": "[detected/confirmed type]",
  "namingConvention": "PascalCase",
  "git": {
    "autoCommit": true,
    "autoCommitUmbrellaRepo": false,
    "autoCommitOnMainBranch": false,
    "featureBranches": true,
    "branchPattern": "[detected from existing branches]",
    "commitConventions": "[from project docs]",
    "tandemKitCommit": "text-only"
  },
  "evaluation": {
    "scope": ["code", "ui-previews", "domain-content"],
    "tools": ["xcodebuildmcp-cli", "xcode-mcp"]
    // For Apple projects with a macOS target, ALSO add "peekaboo-cli" to tools
    // and "ui-runtime" to scope — enables Evaluator to drive the running Mac app.
    // For Android: ["android-cli"] — add "flutter-cli" too for Flutter projects.
    // For web: ["browser-use-cli"] or ["playwright-mcp"] depending on choice.
  },
  "codex": {
    "effort": "high"
  }
}
```

### Planner.md, Generator.md, Evaluator.md

Populate each with project-specific context. Key requirements:

**Evaluator.md must cover BOTH code missions AND documentation/content missions:**
- Build/test/preview commands (for code missions)
- Source verification guidance (for documentation/content missions)
- "Always Do" and "Never Do" sections should distinguish between code and content missions
- **For macOS apps:** primary UI verification is **Peekaboo CLI** on the running app (screenshot, AX tree, click, type, menu navigation). `#Preview` + Xcode MCP `RenderPreview` is still the fastest path for isolated view rendering. Forbid `mcp__computer-use__*` on macOS (unreliable on Tahoe). Include Peekaboo command examples in the role file.
- **For macOS apps with backends (ASC, DB, API):** verify backend side-effects via the app's CLI (e.g., `asc`, `psql`) — do not trust the UI alone.

**Generator.md should reference existing project skills** that are relevant. The specific skills depend entirely on what exists in the project's `.claude/skills/` directory — scan that directory and name the ones that apply. Typical categories to look for (names and availability vary by project):

- A style-guide skill for the project's primary language (e.g., something like `<language>-code-context` or `<language>-style-guide`)
- Framework-specific skills (e.g., a UI-framework style guide if the project has one)
- A testing-conventions skill if the project documents one
- A final-review / linter skill if the project has one (e.g., something named like `review-<language>-changes`)

For macOS apps specifically, the project may have skills for runtime UI automation (e.g., something like a Peekaboo CLI wrapper) and accessibility-identifier authoring (so new SwiftUI/AppKit views are automatable). Name whatever the project actually has — do not invent or assume skill names.

Example phrasing in Generator.md (adjust names to match reality): "Load `<project-style-skill>` before writing <language> code" / "Use `<project-review-skill>` for validation at end of every round".

**Generator.md AND Evaluator.md must both include a top-of-file reminder** pointing at the Signal Protocol in SKILL.md. Suggested exact wording (add verbatim at the top of each file, under the first heading):

```markdown
> ⛔ **Signal Protocol — Atomic (NON-NEGOTIABLE):** every round handoff is the two-step SIGNAL from the Generator/Evaluator SKILL.md §"Signal Protocol" — flip State.json **and** launch `wait-for-state.sh` via `Bash run_in_background: true` **before the response ends**. A State.json write without the watcher deadlocks the loop; a foreground `ls`/`until` poll is NOT a substitute — those die when the turn ends. If the user ever asks "why did you stop?", run `scripts/unstick.sh <mission>` and follow the "If the user asks…" section of SKILL.md.
```

This reminder is the project-level safety net that makes the skill-level rule impossible to miss, even if the agent somehow skims past it in SKILL.md.

**Planner.md should reference ALL major documentation areas** — not just code docs. Include research folders, exploration docs, context directories, domain-specific reference material with "When to read" guidance.

### Verify Build Commands

Run the build command once to verify it works. Fix if needed.

## Step 7 — Update .gitignore (Based on Commit Policy)

Read `git.tandemKitCommit` from Config.json and write the matching entries to the project's `.gitignore`. If the file doesn't exist, create it. If the entries already exist (re-init), leave them alone.

- **`"all"`** — no entries. The whole `TandemKit/` folder including assets is committed.
- **`"text-only"`** — add:
  ```gitignore
  # TandemKit: commit coordination text, ignore binary verification assets.
  TandemKit/*/Assets/
  ```
- **`"none"`** — add:
  ```gitignore
  # TandemKit: don't commit any mission artifacts.
  TandemKit/
  ```

Also tell the user which paths you added so they can adjust if they prefer a different layout. Do NOT overwrite existing `TandemKit`-scoped entries — if `text-only` is chosen but the project already has `TandemKit/` ignored, surface the conflict and ask.

## Step 8 — Codex Skill Access

Run the setup script — it handles everything: creates the `~/.agents/skills/` symlinks, sets up the version-agnostic `latest` indirection, and verifies they resolve. Idempotent: makes no changes if everything is already correct.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-codex-skills.sh"
```

- **Silent** if everything is already correct
- **Prints** what it created or updated
- **Errors** if the TandemKit plugin is not installed — tell the user and stop

**How it works:** The script routes skill symlinks through a `latest` pointer at `~/.claude/plugins/cache/FlineDev/tandemkit/latest`. After a plugin upgrade, only that single pointer needs updating — the `~/.agents/skills/` symlinks are stable forever.

The Planner and Evaluator SKILL.md files contain the same preflight call (Codex-only), so Codex auto-repairs stale symlinks at session start whenever a plugin upgrade happened between sessions.

## Step 9 — Update AGENTS.md (Safety Net)

Add a brief TandemKit section to the project's `AGENTS.md` (or `CLAUDE.md` if that's what the project uses). This serves as a safety net — even if the plugin isn't loaded, Claude will know TandemKit exists and what to do:

```markdown
## TandemKit

This project uses TandemKit — Claude and Codex always work in tandem for planning and evaluation.

**To start a new mission:** Run `/tandemkit:planner` and describe your goal. The Planner guides you through everything — including how to start the Generator and Evaluator sessions once the plan is ready.

Project-specific role context: `TandemKit/Planner.md`, `TandemKit/Generator.md`, `TandemKit/Evaluator.md`.
```

**For Apple platform projects**, also append this line to the TandemKit section:

```markdown
**XcodeBuildMCP:** Always use the CLI (`xcodebuildmcp <command>`). Never configure or use it as an MCP server — MCP mode is not set up for this project.
```

Keep it brief. Ask the user before editing AGENTS.md.

## Step 10 — Summary + Commit

Present a brief summary table of what was set up.

Then ask: "Should I commit the TandemKit initialization?" This is the first milestone — the project setup. If the user agrees, commit all TandemKit files:
```bash
git add TandemKit/ .gitignore
# Also add AGENTS.md if it was modified
git commit -m "Initialize TandemKit coordination framework"
```

Then end with:

> **Before starting your first mission:** If any new skills were installed during init (XcodeBuildMCP, browser-use), run `/exit` to restart the session so Claude picks them up. Then open a fresh session and run:
>
> `/tandemkit:planner`
