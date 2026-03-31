# HarnessKit — Design Document

## Vision

A Claude Code plugin that orchestrates **Planner / Generator / Evaluator** workflows across parallel sessions with file-based coordination. Cross-compatible with Codex. Inspired by Anthropic's March 2026 harness architecture.

## Terminology (Anthropic Official)

| Role | Purpose | From |
|------|---------|------|
| **Planner** | Expands goals into specs with acceptance criteria | Anthropic blog, March 2026 |
| **Generator** | Implements code against the spec | Anthropic blog, March 2026 |
| **Evaluator** | Verifies implementation against acceptance criteria | Anthropic blog, March 2026 |

Source: [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps)

## Key Terminology

| Term | Meaning |
|------|---------|
| **Mission** | A self-contained unit of work driven through the harness (plan → implement → evaluate → done). Each mission gets its own numbered subfolder (e.g., `001-AuthModule/`). |
| **Round** | One iteration within a mission's execution phase. Round 1 = first implementation + first evaluation. Round 2 = fixes + re-evaluation. Etc. |

## Architecture Overview

### Two Phases

**Phase 1 — Planning (interactive)**

User works with one or two Planner sessions to create a specification with acceptance criteria. Two options:
- **Single Planner:** User + Claude (or Codex) plan together interactively
- **Dual Planners:** Claude + Codex both investigate and propose, then reconcile — recommended for diversity of approaches and findings

Output: `Spec.md` with clear acceptance criteria.

When planning is done, the user signals "go." Both sessions are reset (or the user starts fresh sessions).

**Phase 2 — Execution (autonomous coordination)**

Two or three sessions coordinate via files:
- **Session 1: Generator** (always Claude Code) — implements against the spec
- **Session 2: Evaluator A** (Claude Code OR Codex) — verifies against acceptance criteria
- **Optional Session 3: Evaluator B** (the other tool) — independent second evaluation

Generator and Evaluator(s) take turns. Generator implements → signals done → Evaluator(s) evaluate → signal done → Generator reads findings and iterates → repeat until PASS.

### Communication

Sessions coordinate through files in the project's `HarnessKit/` directory plus `watchman-wait` for near-instant file change detection (~120ms latency).

**State.json** is the source of truth for who is doing what. It is:
- Always in the repository (persistent, auditable)
- Inspectable by the user at any time
- The basis for crash recovery ("continue where you left off")

**watchman-wait** blocks until State.json changes, then the session reads the new state. Installed during HarnessKit setup via Homebrew (macOS) or system package manager.

### Crash Recovery

When a session restarts after a crash/update, the user says "continue" and the skill reads State.json to determine what to do:

| Last State in State.json | Session Role | Resume Action |
|---|---|---|
| `generator: "working"` | Generator | Continue implementing where it left off |
| `generator: "ready-for-eval"` | Generator | Start watching for evaluation results |
| `evaluator: "waiting"` | Evaluator | Start watching for generator completion |
| `evaluator: "evaluating"` | Evaluator | Continue evaluating |
| `evaluator: "done"` | Evaluator | Wait (generator should read results) |

Each round's Gen and Eval files serve as checkpoints — even if context is lost, the session can re-read the spec, the latest round file, and State.json to fully reconstruct what was happening.

---

## Decided

### 1. File-based coordination with watchman-wait

**Decision:** Use `watchman-wait` for near-instant file change detection (~120ms). State.json is always the source of truth. No named pipes, no polling loops.

**Why:** Works with Codex (just file reads/writes). Persistent and inspectable. Survives crashes. The ~120ms latency is irrelevant when actual work takes minutes.

**Alternatives considered:**
- Named pipes (FIFOs): ~20ms latency but ephemeral, won't work in Codex sandbox, lost on reboot
- Polling with `stat`: Works everywhere but has 1-second resolution on macOS, wasteful
- `kqwait`: Fastest (~1-5ms) but requires install, no cross-platform story
- Hybrid (pipes + files): Too complex for no real benefit
- Claude Code Agent Teams: Cloud/API-only, extra cost, not available in Claude Code Max, no Codex support

### 2. No Claude Code Agent Teams

**Decision:** Manual parallel sessions started by the user, not Agent Teams.

**Why:** Agent Teams requires API billing (not included in Claude Code Max), cannot integrate with Codex, gives user less visibility and control.

### 3. Codex compatibility as hard requirement

**Decision:** The Evaluator skill must work in both Claude Code and Codex. During setup, a symlink is created from the Codex skills location to the evaluator skill.

**Why:** Using different models (Claude + GPT/Codex) for Generator and Evaluator provides diversity — different models find different bugs, have different strengths. The user should be able to choose Claude+Claude or Claude+Codex freely.

**Technical approach:** Codex uses `.agents/skills/<name>/SKILL.md` with similar YAML frontmatter (requires `name` + `description`). The skill body uses tool-agnostic instructions (what to do, not which specific tools to use). Both Claude Code and Codex can read project files, run shell commands, and search code.

### 4. Dual Evaluator support

**Decision:** Support 1 or 2 Evaluators. When 2 are active, they evaluate independently, then Evaluator A reconciles into a consensus. The Generator always sees only one final evaluation per round.

**Why:** Two evaluators with different models catch more issues. The reconciliation step prevents contradictory feedback.

### 5. Anthropic naming convention

**Decision:** Use Planner, Generator, Evaluator (not Implementer, Reviewer, etc.).

**Why:** These are the official terms from Anthropic's March 2026 blog post. Using standard terminology avoids confusion.

### 6. watchman installed during setup

**Decision:** `harness-kit:init` installs `watchman` via Homebrew (macOS) or appropriate package manager during project setup.

**Why:** watchman-wait provides near-instant file change detection without polling. It's a one-time install, lightweight, and well-maintained by Meta.

### 7. "Mission" as the unit of work

**Decision:** Each unit of work driven through the harness is called a **mission**. Each mission gets a numbered subfolder: `001-AuthModule/`, `002-UserProfile/`, etc.

**Why:** "Mission" conveys purpose and completion, works for features AND bug fixes AND refactors, fits the harness metaphor (you harness the team for a mission), and avoids conflicts with existing terms (Claude Code "tasks", CI "runs", Anthropic's removed "sprints").

**Alternatives considered:**
- Run: Too generic, conflicts with CI/test terminology
- Goal: "Goal 002" sounds odd as a folder name
- Task: Conflicts with Claude Code's built-in TaskCreate
- Drive: Tech ambiguity (disk drive, Google Drive)
- Feature: Not everything is a feature (bug fixes, refactors)
- Cycle/Sprint: Conflicts with inner iteration rounds / Anthropic explicitly removed sprints

### 8. Numbered subfolders with dates in metadata (Option C)

**Decision:** Missions use numbered PascalCase subfolders (`001-AuthModule/`, `002-UserProfile/`). Config.json tracks `"currentMission": "002-UserProfile"` as a string matching the full folder name. Dates are stored in State.json and Summary.md metadata, not folder names. No cleanup needed — completed missions remain as archive.

**Why:**
- Consistent with PlanKit's proven `NNN-FeatureName` numbering
- Clean, short folder names that sort naturally
- Each mission is fully self-contained (move it, reference it independently)
- No cleanup step to forget — new mission = new folder, old missions stay
- Summary.md provides quick overview per mission without opening round files
- `nextMissionNumber` counter in Config.json ensures unique numbering

**Folder structure:**
```
HarnessKit/
├── Config.json                    # Global config + currentMission + nextMissionNumber
├── 001-AuthModule/
│   ├── Spec.md                    # Acceptance criteria from planning
│   ├── State.json                 # Coordination state (phase: "done")
│   ├── Gen/
│   │   ├── Round-001.md           # Generator's implementation report
│   │   └── Round-002.md           # Generator's fix report
│   ├── Eval/
│   │   ├── Round-001.md           # Evaluator findings (FAIL)
│   │   └── Round-002.md           # Evaluator findings (PASS)
│   ├── Discussion/                # Only when dual evaluators
│   │   ├── Round-001-A.md
│   │   ├── Round-001-B.md
│   │   └── Round-001-Consensus.md
│   └── Summary.md                 # Auto-generated after PASS
├── 002-UserProfile/               # Current mission
│   ├── Spec.md
│   ├── State.json                 # phase: "evaluation", round: 1
│   ├── Gen/
│   │   └── Round-001.md
│   └── Eval/                      # (evaluator currently working)
```

**Summary.md** is auto-generated when a mission reaches PASS. It captures: goal, dates, round count, roles used, key decisions, issues found & fixed, files changed. The skill reads Summary.md files when the user asks "what have we worked on?"

**Alternatives considered:**
- Date-prefixed folders (`2026-03-31_AuthModule`): Longer names, disambiguation needed for same-day missions, not consistent with PlanKit
- Flat structure (no subfolders): Requires cleanup between missions, no archive
- `currentMission` as integer: Doesn't match folder name directly, error-prone

---

## Open — To Be Discussed

### Planning Phase Details

- Single vs. dual Planner: how does the two-Planner setup work exactly?
- How do two Planners reconcile? Same file-based protocol as Generator+Evaluator?
- What does Spec.md look like? Format, required sections, acceptance criteria structure

### Evaluator Profiles

- Should Config.json include a strategy field (e.g., `"evaluator": "swiftui"`) that influences evaluation?
- Or should the evaluator just adapt based on available tools and project type?

### Skill Structure

- How many skills, what are they called, which are user-invocable?
- The Generator skill vs. the Evaluator skill vs. the Planner skill
- How does "continue" work across all roles?

### Dual Evaluator Discussion Protocol

- How do Evaluator A and B communicate during reconciliation?
- What if they disagree? Who has final say?

### When Is a Mission "Done"?

- Evaluator says PASS → what happens? Auto-commit? Summary generation? State update?
- How is the mission closed/archived?

### Dual Planner Phase

- Should the planning phase also support two parallel sessions (Claude + Codex)?
- How do two Planners reconcile their findings into one Spec.md?
- Is the protocol the same as Generator+Evaluator or different?

---

## Research Summary

### Anthropic Blog Posts

**March 2026 — "Harness design for long-running application development"**
- Three-agent system: Planner, Generator, Evaluator
- Key finding: With Opus 4.6, **sprints were removed** — the model runs coherently for 2+ hours without decomposition
- Planner and Evaluator remained load-bearing; sprint contracts did not
- Evaluator used Playwright MCP to click through running apps
- Generator and Evaluator negotiated "sprint contracts" (later removed)
- Communication via files: agents read/respond to each other's outputs

**November 2025 — "Effective harnesses for long-running agents"**
- Two-agent system: Initializer + Coding Agent
- Feature list as structured JSON with `passes: bool` field
- `claude-progress.txt` + git history for session bridging
- Incremental single-feature work prevents "one-shotting"
- Clean state at session end (git commit + progress update)

### Community Projects (Most Relevant)

| Project | Key Pattern | Stars |
|---------|-------------|-------|
| agents-scaffolding | Append-only files (HANDOFF.md, ISSUES.md), 40 agent-days zero conflicts | 0 |
| AI Bridge MCP | Checkpoint+guidance JSON, hook-based auto-injection | 0 |
| Company Skill | criteria.json + Stop Hook, verify loop until all criteria pass | 0 |
| Citadel | Discovery relay between agents, campaign persistence | 427 |
| claude-tmux-orchestration | Heartbeat + idle detection, adaptive polling, .ready handshake | 22 |
| Crosswire | Typed messages (task/question/reply/info), threading, inbox pattern | 7 |
| claude_code_agent_farm | Lock files, 20+ agent coordination | 764 |
| multi-agent-shogun | Cross-CLI support (Claude, Codex, Copilot, Kimi) | 1166 |

### Notification Mechanisms (Evaluated)

| Mechanism | Latency | Chosen? |
|-----------|---------|---------|
| Named pipes (FIFO) | ~20ms | No — ephemeral, Codex-incompatible |
| watchman-wait | ~120ms | **Yes** — persistent, installed during setup |
| fswatch | ~50-200ms | No — watchman already covers this |
| kqwait | ~1-5ms | No — macOS only, no real benefit over watchman |
| stat polling | 1000ms+ | No — wasteful, low resolution |
| SQLite WAL | depends on polling | No — overkill |
