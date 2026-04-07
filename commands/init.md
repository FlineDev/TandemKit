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
   - `Cargo.toml` → Rust / `go.mod` → Go
   - **Check submodules:** Read `.gitmodules` if it exists. Check inside submodule directories for build files.
   - **If both Package.swift AND .xcodeproj exist:** Note both and present options.

3. **Check available tools:**
   - Read `~/.claude/settings.json` for global permissions and MCP tool allowances
   - Read project `.claude/settings.json` and `.mcp.json` for project-level MCP servers
   - Check what's already available: Xcode MCP? browser-use CLI (`which browser-use`)? Simulator tools?

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

Present a brief summary of findings to the user before asking the first question.

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

### Question 6: .gitignore Preference

> "Do you want TandemKit coordination files gitignored during active missions?"

## Step 4 — Check Permissions for Autonomous Operation

**Detection-based:** Only speak up about what's actually missing.

Read `~/.claude/settings.json` and project `.claude/settings.json`. Check for core tools and MCP tools.

If Codex is enabled, check `~/.codex/config.toml`. Only mention issues if restrictive.

## Step 5 — Recap and Confirm

**Before writing any files**, present a summary of everything you're about to encode:

> "Here's what I'll set up:
> - Project type: [type]
> - Evaluation scope: [list]
> - Tools: [list]
> - Git: auto-commit [yes/no], scope [where], feature branches [yes/no], branch pattern [pattern]
> - Codex: [enabled/disabled], mode [CLI/MCP]
> - .gitignore: [yes/no]
>
> Does this look right?"

Wait for confirmation. This catches misunderstandings before they're baked into config files.

## Step 6 — Create the TandemKit Directory

Create the folder structure with Config.json, Planner.md, Generator.md, Evaluator.md, and ClaudeEvaluatorPrompt.md.

### ClaudeEvaluatorPrompt.md

Copy from the plugin's `system-prompts/claude-evaluator.md` template. **If the file already exists** (re-init): do NOT overwrite. Ask first.

This file is NOT modified by the self-learning system — keep it stable.

### Config.json

Do NOT add a `codex` section — Codex is always required and not configurable.
Do NOT add `learnings` sections to any role file — the self-learning system has been removed.

```json
{
  "currentMission": null,
  "nextMissionNumber": 1,
  "projectType": "[detected/confirmed type]",
  "git": {
    "autoCommit": true,
    "autoCommitUmbrellaRepo": false,
    "autoCommitOnMainBranch": false,
    "featureBranches": true,
    "branchPattern": "[detected from existing branches]",
    "commitConventions": "[from project docs]"
  },
  "evaluation": {
    "scope": ["code", "ui-previews", "domain-content"],
    "tools": ["xcodebuildmcp-cli", "xcode-mcp"]
  }
}
```

### Planner.md, Generator.md, Evaluator.md

Populate each with project-specific context. Key requirements:

**Evaluator.md must cover BOTH code missions AND documentation/content missions:**
- Build/test/preview commands (for code missions)
- Source verification guidance (for documentation/content missions)
- "Always Do" and "Never Do" sections should distinguish between code and content missions
- For macOS apps: SwiftUI views → `#Preview` + `RenderPreview` as primary UI verification. AppKit/integrated flows → manual testing. `screencapture` → evidence capture only (not automated navigation).

**Generator.md should reference existing project skills** that are relevant (e.g., "Load `swift-code-context` before writing Swift code", "Load `swiftui-code-context` for SwiftUI work", "Use `review-swift-changes` for validation").

**Planner.md should reference ALL major documentation areas** — not just code docs. Include research folders, exploration docs, context directories, domain-specific reference material with "When to read" guidance.

### Verify Build Commands

Run the build command once to verify it works. Fix if needed.

## Step 7 — Update .gitignore (If User Agreed)

Only if the user said yes in Question 6.

## Step 8 — Verify Codex Skill Access

Codex needs access to the TandemKit skills so it can read evaluation strategies and role context. Check in this order:

1. **Check user-level Codex symlinks first:** Do `~/.agents/skills/planner`, `~/.agents/skills/generator`, `~/.agents/skills/evaluator` exist and point to valid TandemKit skill folders?
   - If YES → skip to Step 9. Tell user: "Codex skills already installed at user level."
   - If NO → continue to step 2.

2. **Resolve the TandemKit repo path** using the plugin root:
   ```bash
   # For plugin installs, CLAUDE_PLUGIN_ROOT points to the plugin directory
   TANDEM_PATH="${CLAUDE_PLUGIN_ROOT}"
   ```
   If `CLAUDE_PLUGIN_ROOT` is not set (standalone symlink install), resolve from the Claude skill symlink:
   ```bash
   TANDEM_PATH=$(readlink -f ~/.claude/skills/planner | sed 's|/skills/planner$||')
   ```

3. **Create user-level Codex symlinks:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -sf "$TANDEM_PATH/skills/planner" ~/.agents/skills/planner
   ln -sf "$TANDEM_PATH/skills/generator" ~/.agents/skills/generator
   ln -sf "$TANDEM_PATH/skills/evaluator" ~/.agents/skills/evaluator
   ```

4. **Verify the symlinks resolve correctly:**
   ```bash
   ls -la ~/.agents/skills/planner/SKILL.md
   ```
   If the symlink is broken, tell the user and ask them to verify their TandemKit installation.

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
