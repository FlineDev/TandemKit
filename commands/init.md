---
description: Initialize HarnessKit in this project. Sets up the coordination folder, configures roles, installs tools, and creates Codex symlinks.
---

# HarnessKit — Project Initialization

This command sets up HarnessKit in the current project. Run it once per project.

## Pre-Flight Check

1. Verify `HarnessKit/` does not already exist in the project root. If it does, tell the user: "HarnessKit is already initialized in this project. Config is at HarnessKit/Config.json."
2. Check that this is a git repository. If not, warn: "This project is not a git repository. HarnessKit works best with git for feature branches and milestone commits. Continue anyway?"

## Step 1 — Install watchman

HarnessKit uses `watchman-wait` for near-instant file change detection between sessions.

Check if watchman is installed:
```bash
which watchman-wait
```

If not installed, install it:
- **macOS:** `brew install watchman`
- **Linux (Debian/Ubuntu):** Guide the user to install from the official Watchman releases
- **Other:** Direct the user to https://facebook.github.io/watchman/docs/install

Verify after installation:
```bash
watchman-wait --version
```

## Step 2 — Investigate the Project

Before asking questions, investigate the project to make informed recommendations:

1. **Read project documentation:**
   - `AGENTS.md` or `CLAUDE.md` — conventions, architecture, commit rules
   - `README.md` — project overview
   - `Package.swift` / `package.json` / `Cargo.toml` / `go.mod` — detect language/framework
   - `.claude/settings.json` or `.claude/settings.local.json` — check existing MCP servers

2. **Detect project type:**
   - `.xcodeproj` or `.xcworkspace` → Apple platform (check for SwiftUI, UIKit, AppKit)
   - `package.json` with React/Vue/Svelte/Next → Web app
   - `Package.swift` with no Xcode project → Swift CLI or library
   - `Cargo.toml` → Rust
   - `go.mod` → Go
   - Multiple indicators → ask the user

3. **Check available tools:**
   - Is Xcode MCP connected? (check for `mcp__xcode__*` in available tools)
   - Is Playwright configured? (check MCP servers config)
   - Is ios-simulator-mcp installed? (check MCP servers config)
   - What test runners exist? (`swift test`, `npm test`, `cargo test`, etc.)

4. **Read commit conventions:**
   - Check AGENTS.md/CLAUDE.md for commit message rules
   - Check for conventional commits, git hooks, etc.
   - Check for branch naming conventions

Summarize your findings to the user before asking questions.

## Step 3 — Ask Configuration Questions

Use the AskUserQuestion tool for each question. Present your findings first, then ask.

### Question 1: Project Type Confirmation

> "Based on my investigation, this appears to be a **[detected type]** project. Is that correct, or should I categorize it differently?"

Options based on detection. If unclear, offer:
- Apple platform app (iOS / macOS / visionOS / multi-platform)
- Web application
- CLI tool
- Library / Package
- Domain system / Expert system
- Other

### Question 2: Evaluation Scope

> "What aspects should the Evaluator be able to verify? The more the evaluator can check, the better the quality. I strongly recommend enabling UI verification if your project has a user interface — an evaluator that can only read code will miss visual bugs, broken navigation, and spacing issues."

Options:
- Code correctness (build + tests) — always included
- UI verification (screenshots, interaction) — recommended for apps
- Accessibility — recommended for apps
- Performance — if relevant
- Domain-specific verification — for expert systems

### Question 3: Tool Setup (Based on Project Type)

**For Apple platform projects:**

Read `references/EvalStrategy-ApplePlatform.md` for full details.

> "For the best evaluation quality, I recommend setting up these tools:
> 1. **Xcode MCP** (built-in) — builds, tests, SwiftUI preview screenshots. [Already connected / Not yet connected]
> 2. **ios-simulator-mcp** — lets the evaluator tap buttons, read screens, and take screenshots of your running app. This is the single most impactful tool for UI evaluation. [Install with: `npm install -g ios-simulator-mcp`]
> 3. **AppleScript** — for running/stopping the app from Xcode. No install needed.
>
> Want me to help set these up?"

If the user agrees, guide them through:
- Verifying Xcode MCP connection
- Installing ios-simulator-mcp and adding it to `.claude/settings.json`
- Installing IDB if needed (`brew install idb-companion && pipx install fb-idb`)

**For web projects:**

Read `references/EvalStrategy-Web.md` for full details.

> "For web evaluation, Playwright MCP is essential — it lets the evaluator interact with your app like a real user. [Already configured / Not configured]
>
> Want me to help set it up?"

If the user agrees, add Playwright MCP to `.claude/settings.json`.

**For CLI/library projects:**

Read `references/EvalStrategy-CLI.md`.

> "For CLI/library evaluation, the test suite is the primary verification tool. I'll configure the evaluator to run `[detected test command]` before every evaluation. Anything else specific?"

**For domain systems:**

Read `references/EvalStrategy-Domain.md`.

> "For domain systems, evaluation focuses on reasoning quality, case handling, and consistency. Do you have canonical test cases defined? If not, I'll set up a structure for defining them."

### Question 4: Git Commit Policy

> "I found these commit conventions in your project: [findings from AGENTS.md/CLAUDE.md].
>
> For HarnessKit missions:
> 1. Should the Generator make commits automatically at milestones? (default: yes)
> 2. Should each mission use a feature branch? (default: yes)
> 3. HarnessKit coordination files (State.json, Gen/, Eval/) will only be committed when the mission is completed by you. Is that okay?"

### Question 5: Codex Compatibility

> "Do you want to use Codex for evaluation or planning? If yes, I'll create a symlink so the HarnessKit skill is available in Codex sessions too."

If yes: note this for the symlink creation step.

## Step 4 — Create the HarnessKit Directory

Create the folder structure:

```
HarnessKit/
├── Config.json
└── Roles/
    ├── Planner.md
    ├── Generator.md
    └── Evaluator.md
```

### Config.json

```json
{
  "currentMission": null,
  "nextMissionNumber": 1,
  "projectType": "[detected/confirmed type]",
  "git": {
    "autoCommit": true,
    "featureBranches": true,
    "branchPrefix": "",
    "commitConventions": "[from project docs]"
  },
  "evaluation": {
    "scope": ["code", "ui", "accessibility"],
    "tools": ["xcode-mcp", "ios-simulator-mcp", "applescript"]
  }
}
```

### Roles/Planner.md

Populate with project-specific planner context:
- Key files to investigate
- Planning priorities (from user input)
- Existing documentation locations (AGENTS.md, README, PlanKit if present)
- Domain context if applicable

### Roles/Generator.md

Populate with project-specific generator context:
- Architecture overview (from investigation)
- Coding conventions (from AGENTS.md/CLAUDE.md)
- Build and test commands
- Important patterns to follow
- Commit message conventions

### Roles/Evaluator.md

This is the most important role file. Populate with:
- Project type
- Available verification tools (build, test, UI interaction, screenshots)
- How to use each tool (exact commands, MCP tool names)
- Evaluation priorities (from user input)
- "Always do" rules (build, run tests, take screenshots, etc.)
- "Never do" rules (never PASS without building, never PASS without tests, etc.)

Use the appropriate EvalStrategy reference as a template.

## Step 5 — Create Codex Symlink (If Requested)

If the user wants Codex compatibility:

```bash
mkdir -p .agents/skills
ln -sf "$(find ~/.claude/plugins/cache -path '*/harness-kit/skills/harness-kit' -type d 2>/dev/null | sort -V | tail -1)" .agents/skills/harness-kit
```

If the plugin is loaded via `--plugin-dir` (development mode), use the direct path instead.

Also add `.agents/` to `.gitignore` if it's not already there (the symlink is local, not committed).

Tell the user: "Codex symlink created. In Codex sessions, the HarnessKit skill will be available when you paste a prompt containing 'HarnessKit'."

## Step 6 — Summary

Present a summary of what was set up:

> **HarnessKit initialized!**
>
> - Project type: [type]
> - Evaluation tools: [list]
> - Git: auto-commit [yes/no], feature branches [yes/no]
> - Codex: [enabled/not enabled]
>
> **To start your first mission:**
> Just say "Let's use HarnessKit to [your goal]" in any Claude Code session.
>
> **Files created:**
> - `HarnessKit/Config.json` — project configuration
> - `HarnessKit/Roles/Planner.md` — planner context
> - `HarnessKit/Roles/Generator.md` — generator context
> - `HarnessKit/Roles/Evaluator.md` — evaluator context

Do NOT commit the HarnessKit/ folder now — it will be committed with the first completed mission.
