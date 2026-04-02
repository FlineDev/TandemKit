---
description: Initialize HarnessKit in this project. Sets up the coordination folder, configures roles, installs tools, and creates Codex symlinks.
---

# HarnessKit — Project Initialization

This command sets up HarnessKit in the current project. Run it once per project.

## Important UX Rules

Follow these rules throughout the entire init flow:

1. **Do NOT explain what HarnessKit is.** The user already knows — they just ran the init command.
2. **Ask questions ONE AT A TIME.** Before each question, write 2-3 sentences of context in chat explaining WHY this matters and what you recommend. Then ask using AskUserQuestion. Never batch multiple questions into one call.
3. **Do NOT install or configure anything without explicit user approval.** Ask first, show what you want to do, get a "yes", then do it.
4. **Before modifying any existing file** (.gitignore, settings.json, config.toml), explain what you want to change and get user approval.
5. **When recommending external tools**, always provide: verified GitHub URL, star count, brief description of what it does, and at least one alternative. Never present a single option as the only choice.
6. **For npm packages, use `npx -y`** (run without global install), never `npm install -g`. Check the user's permission deny list in settings.json — never recommend commands that appear there.
7. **MCP server configurations go in `.mcp.json`** at the project root, NOT in `.claude/settings.json`. MCP tool permissions (allow rules) go in settings.json.
8. **Start brief.** Jump straight to investigation. No preamble, no tutorial.

## Pre-Flight Check

1. Verify `HarnessKit/` does not already exist in the project root. If it does, tell the user: "HarnessKit is already initialized in this project. Config is at HarnessKit/Config.json."
2. Check that this is a git repository. If not, warn: "This project is not a git repository. HarnessKit works best with git for feature branches and milestone commits. Continue anyway?"

## Step 1 — Install watchman

HarnessKit uses `watchman-wait` for near-instant file change detection between sessions.

Check if watchman is installed:
```bash
which watchman-wait
```

If not installed, tell the user:
> "HarnessKit needs `watchman` for file change detection between sessions. Install with: `brew install watchman` (macOS). Want me to install it?"

Wait for approval before installing.

## Step 2 — Investigate the Project

Before asking questions, investigate the project thoroughly to make informed recommendations. Tell the user: "Let me investigate your project..." then do all of the following silently:

1. **Read project documentation:**
   - `AGENTS.md` or `CLAUDE.md` — conventions, architecture, commit rules
   - `README.md` — project overview

2. **Detect project type — check for ALL build systems:**
   - `.xcodeproj` or `.xcworkspace` → Apple platform app
   - `Package.swift` → Swift package (can coexist with .xcodeproj!)
   - `package.json` → Node.js / web
   - `Cargo.toml` → Rust
   - `go.mod` → Go
   - **Check submodules:** Read `.gitmodules` if it exists. Check inside submodule directories for build files too — the main project files may be in a submodule (e.g., `App/Package.swift`, `App/MyApp.xcodeproj`).
   - **If both Package.swift AND .xcodeproj exist:** Note both. `swift build`/`swift test` may be simpler for evaluation, but `xcodebuild` may be needed for full app features. Present both options to the user.

3. **Check available tools:**
   - Read `~/.claude/settings.json` for global permissions and MCP tool allowances
   - Read project `.claude/settings.json` and `.mcp.json` for project-level MCP servers
   - Check what's already available: Xcode MCP? Playwright? Simulator tools?

4. **Read commit conventions:**
   - Check AGENTS.md/CLAUDE.md for commit message rules, push policies, branch conventions
   - Check for git hooks

5. **Read the user's permission deny list** in settings.json — note any denied commands so you don't recommend them later.

Present a brief summary of findings to the user before asking the first question.

## Step 3 — Ask Configuration Questions

Ask each question ONE AT A TIME. Before each question, explain briefly in chat why it matters and what you recommend.

### Question 1: Project Type Confirmation

Present your detection results, then ask:

> "I found [what you found]. Does this look right?"

If the project has both Package.swift and .xcodeproj, mention both and ask which build path the user prefers for evaluation.

### Question 2: Evaluation Scope

Explain that HarnessKit's evaluator can verify different aspects depending on the tools available, then ask:

> "What should the Evaluator verify?"

Options:
- Code correctness (build + tests) — always included
- UI verification (screenshots, interaction) — recommended for apps
- Accessibility — recommended for apps
- Performance — if relevant
- Domain-specific verification — for expert systems

### Question 3: Tool Setup (Based on Project Type)

**For Apple platform projects:**

Read `references/Evaluation-Strategy-ApplePlatform.md` for full details. The recommended stack is:

1. **XcodeBuildMCP** ([getsentry/XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP), ~5,000 stars) — the primary tool. Build, test, run, UI automation (tap/swipe/type/screenshot/accessibility tree), simulator management, debugging, log capture, code coverage. CLI mode preferred for reliability.
2. **Apple Xcode MCP** (built into Xcode) — complement for SwiftUI preview screenshots (`RenderPreview`), Swift REPL (`ExecuteSnippet`), Apple docs, live diagnostics.

**Do NOT start installing until the user agrees.** If they agree:

Install XcodeBuildMCP:
```bash
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp
xcodebuildmcp init
```

This installs the CLI tool and the Claude Code CLI skill. Configure telemetry opt-out and workflow enablement in `.xcodebuildmcp/config.yaml`.

For Codex users, also add MCP config to `~/.codex/config.toml`:
```toml
[mcp_servers.XcodeBuildMCP]
command = "npx"
args = ["-y", "xcodebuildmcp@latest", "mcp"]
```

Verify Xcode MCP is connected (check for `mcp__xcode__*` in available tools).

**Cautions to mention:**
- Set `XCODEBUILDMCP_SENTRY_DISABLED=true` in environment unless user opts in to telemetry
- On iOS 26+ simulators, `snapshot_ui` may return empty — enable accessibility defaults first
- If XcodeBuildMCP CLI or MCP has issues, fall back to `xcrun simctl` + `xcodebuild` via Bash
- macOS apps: build/test supported but no GUI automation — UI verification needs manual testing

**For web projects:**

Read `references/Evaluation-Strategy-Web.md`. Present Playwright MCP option with setup status.

**For CLI/library projects:**

Read `references/Evaluation-Strategy-CLI.md`. Confirm the test command that will be used.

**For domain systems:**

Read `references/Evaluation-Strategy-Domain.md`. Ask about canonical test cases.

### Question 4: Git Commit Policy

Present what you found in the project's commit conventions, then ask:

> "For HarnessKit missions:"

1. Should the Generator make commits automatically at milestones? (default: yes)
2. Should each mission use a feature branch? (default: yes)
3. Branch name prefix? (e.g., `feature/` → `feature/001-jwt-auth`, or empty for `001-jwt-auth`)

### Question 5: Codex Compatibility

> "Do you want to use Codex for evaluation or planning? If yes, I'll create a symlink so the HarnessKit skill is available in Codex sessions too."

### Question 6: .gitignore Preference

> "During active missions, HarnessKit creates coordination files (State.json, Generator/, Evaluator/ round reports). Do you want these gitignored during active missions? If yes, they'll be force-added at mission completion for archival. If no, you'll see them in your Git UI but need to be careful not to stage them during milestone commits."

## Step 4 — Check Permissions for Autonomous Operation

**Detection-based:** Only speak up about what's actually missing. If permissions are already broad, say nothing.

Read `~/.claude/settings.json` and project `.claude/settings.json`. Check for:
- Core tools: `Bash`, `Read`, `Edit`, `Write`, `Glob`, `Grep`
- MCP tools for the configured evaluation tools (e.g., `mcp__xcode__*`, `mcp__mobile-mcp__*`)

If missing critical permissions, explain what's needed and why.

If Codex is enabled, check `~/.codex/config.toml` for sandbox mode and approval policy. Only mention issues if the config is too restrictive for autonomous operation.

## Step 5 — Create the HarnessKit Directory

Create the folder structure:

```
HarnessKit/
├── Config.json
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
    "tools": ["xcode-mcp", "mobile-mcp", "applescript"]
  }
}
```

### Planner.md, Generator.md, Evaluator.md

Populate each with project-specific context based on your investigation findings and the user's answers. Use the appropriate Evaluation-Strategy reference as a template for the Evaluator.md.

### Verify Build Commands

After creating Evaluator.md with build/test commands, **run the build command once** to verify it works. If it fails (wrong scheme, wrong destination, missing dependencies), fix the command in Evaluator.md and Generator.md before proceeding. The user should not discover broken build commands during the first mission.

## Step 6 — Update .gitignore (If User Agreed)

Only if the user said yes in Question 6. Add the entries they approved.

If the user said no, skip this step entirely.

## Step 7 — Create Codex Symlink (If Requested)

If the user wants Codex compatibility:

First, detect if the plugin was loaded via marketplace (cache) or `--plugin-dir` (development):

```bash
# Check if marketplace cache exists
CACHE_PATH=$(find ~/.claude/plugins/cache -path '*/harness-kit/skills/mission' -type d 2>/dev/null | sort -V | tail -1)
```

- If `CACHE_PATH` is found: use it for the symlink
- If not found (--plugin-dir mode): ask the user for the plugin path, or detect it from the current session

```bash
mkdir -p .agents/skills
ln -sf "<resolved-path>" .agents/skills/mission
```

Add `.agents/skills/mission` to `.gitignore` (this symlink is machine-specific and should not be committed). Document the symlink setup command in `AGENTS.md` so collaborators can recreate it.

If Codex MCP servers need configuring, update `~/.codex/config.toml` with the appropriate MCP server entries and auto-approval rules.

## Step 8 — Summary

Present a brief summary table of what was set up, then end with a clear call to action:

> **Next step:** To start your first mission, just say:
> `Let's use HarnessKit to [your goal]`
