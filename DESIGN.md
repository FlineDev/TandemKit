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
| `generatorStatus: "working"` | Generator | Continue implementing where it left off |
| `generatorStatus: "ready-for-eval"` | Generator | Start watching for evaluation results |
| `evaluatorStatus: "pending"` | Evaluator | Start watching for generator completion |
| `evaluatorStatus: "evaluating"` | Evaluator | Continue evaluating |
| `evaluatorStatus: "done"` | Evaluator | Wait (generator should read results) |

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

### 4. Dual-session protocol (Planners & Evaluators)

**Decision:** When two sessions share the same role (two Planners or two Evaluators), they follow a structured 6-step protocol. Session A is always the primary (asks user, writes final documents, goes first in sequential phase). Session B is always the secondary (reviews, never talks to user directly).

**The protocol:**

1. **Upfront Questions** (Planners only, parallel) — Both independently think about whether the user needs to clarify direction. Both signal done. A collects questions and asks the user. If none, A explicitly tells user "no upfront questions, I'll investigate" so user can leave.

2. **Parallel Investigation** — Both investigate/research independently. Each writes findings with full source references (file paths with line numbers, links, command outputs). Each signals "investigation done."

3. **Parallel Cross-Review** — Both wait until other's investigation is done. Both read the other's findings and write a review. Both signal "review done."

4. **Sequential Discussion** — A goes first. They alternate responses until 100% agreement on every aspect. No skipping disagreements — everything must be resolved.

5. **Documentation** — A writes the final document (Spec.md for planners, Eval/Round-NNN.md for evaluators). B reviews. A fixes. B re-reviews. Repeat until both agree the document is correct.

6. **End Questions** (Planners only) — A collects remaining questions from both sessions and asks the user. If answers require re-investigation, back to Step 2.

**Key rules:**
- Steps 1-3 are parallel (both work simultaneously, then wait for each other)
- Steps 4-6 are sequential (alternating, A always starts)
- All findings must include source references so the other session can verify without re-investigating
- The user is only engaged in Session A's chat, only at the start (upfront questions) and end (remaining questions)
- From the Generator's perspective, there's always one Spec.md and one Eval/Round-NNN.md — it doesn't know or care if one or two sessions produced it

**File structure for dual-session communication:**
```
Planning/                              # (or EvalDiscussion/ for evaluators)
├── State.json                         # Phase tracking for the protocol
├── UpfrontQuestions-A.md              # (planners only)
├── UpfrontQuestions-B.md              # (planners only)
├── UserAnswers.md                     # (planners only)
├── Investigation-A.md                 # A's findings with source refs
├── Investigation-B.md                 # B's findings with source refs
├── Review-A.md                        # A's review of B's investigation
├── Review-B.md                        # B's review of A's investigation
├── Discussion/
│   ├── 001-A.md                       # Sequential discussion rounds
│   ├── 002-B.md
│   ├── 003-A.md
│   └── 004-B.md                       # Agreement reached
├── EndQuestions.md                     # (planners only)
└── Draft/
    ├── 001-A.md                       # A's draft of final document
    ├── 002-B.md                       # B's feedback
    └── 003-A.md                       # A's revision (B approves → done)
```

**State.json for the protocol:**
```json
{
  "step": "parallel-investigation",
  "sessionA": { "status": "investigating", "tool": "claude-code" },
  "sessionB": { "status": "investigating", "tool": "codex" },
  "discussionRound": 0,
  "draftRound": 0,
  "updated": "2026-03-31T14:30:00Z"
}
```

Step field progresses: `upfront-questions` → `parallel-investigation` → `parallel-review` → `sequential-discussion` → `documentation` → `end-questions` → `done`

**Why this protocol:**
- Parallel investigation leverages different models finding different things
- Cross-review catches blind spots without redundant investigation
- Sequential discussion resolves disagreements explicitly
- Documentation with review ensures nothing is lost
- The user can leave after upfront questions and return when planning is done

**Alternatives considered:**
- Simple "both write, A merges": Loses the back-and-forth that resolves disagreements
- Fully parallel throughout: Risk of contradictory conclusions without resolution
- Subagent-based evaluation: Black box for user, context lost between iterations, can't use Codex

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
│   ├── Spec.md                    # Acceptance criteria (output of planning)
│   ├── State.json                 # Coordination state (phase: "done")
│   ├── Planning/                  # Only when dual planners were used
│   │   ├── State.json             # Planning protocol state
│   │   ├── Investigation-A.md
│   │   ├── Investigation-B.md
│   │   ├── Review-A.md
│   │   ├── Review-B.md
│   │   ├── Discussion/
│   │   └── Draft/
│   ├── Gen/
│   │   ├── Round-001.md           # Generator's implementation report
│   │   └── Round-002.md           # Generator's fix report
│   ├── Eval/
│   │   ├── Round-001.md           # Final evaluator findings (FAIL)
│   │   └── Round-002.md           # Final evaluator findings (PASS)
│   ├── EvalDiscussion/            # Only when dual evaluators, per round
│   │   ├── Round-001/             # Dual-session protocol files for round 1
│   │   │   ├── State.json
│   │   │   ├── Investigation-A.md
│   │   │   ├── Investigation-B.md
│   │   │   ├── Review-A.md
│   │   │   ├── Review-B.md
│   │   │   ├── Discussion/
│   │   │   └── Draft/
│   │   └── Round-002/
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

### 9. Spec.md format

**Decision:** Spec.md is the central artifact connecting planning to execution to evaluation. It is requirements-focused, never prescriptive about implementation.

**Required sections:**

1. **User Intent** — The user's exact words (typo/grammar-corrected), including follow-up clarifications. Preserved as blockquotes for reference. When the user changed their mind, both the original position and the change are documented.

2. **Goal** — One-paragraph summary of what we're building/fixing and why. Written in plain language the Evaluator can understand without deep codebase knowledge.

3. **Context & Investigation Findings** — The Planner's actual findings from investigating the codebase:
   - Existing architecture relevant to this mission (with file paths + line numbers)
   - Relevant external resources with links
   - Considerations explored during planning (tradeoffs discussed, not just final decisions)
   - Related PlanKit features/steps (if PlanKit is present)

4. **Acceptance Criteria** — Numbered, unambiguous pass/fail statements. Two independent evaluators must reach the same verdict on each criterion. No implementation details — focus on observable behavior and outcomes. The Evaluator is smart enough to figure out how to verify each criterion.

5. **Edge Cases & Boundaries** — Non-obvious cases with expected behavior. Things the Generator should handle and the Evaluator should check. Includes negative cases ("must NOT do X when Y").

6. **Key Decisions** — Decisions made during planning with rationale. When the user changed their mind, documents both the original position and the change with the user's words.

7. **Out of Scope** — Explicit boundaries so the Generator doesn't over-build and the Evaluator doesn't flag missing features that are intentionally excluded.

8. **Possible Directions & Ideas** (optional) — Soft suggestions from the Planner's investigation. Non-binding. Relevant code patterns to consider, libraries already available, architectural ideas. The Generator can take these or ignore them.

**Key principles:**
- Constrain deliverables, not implementation — specify WHAT and WHY in detail, never HOW (unless there's a specific architectural constraint)
- Acceptance criteria stay lean — no rigid verification scripts. Modern models figure out how to verify
- Include negative cases — what must NOT happen is as important as what must happen
- Investigation findings are rich — links, file paths, tradeoffs explored. The Planner did work; preserve it
- Spec is immutable during implementation — Generator and Evaluator work against a locked spec
- Prune ruthlessly — if removing a line would not cause the Generator to make mistakes, remove it

**Alternatives considered:**
- Super-granular 200+ item feature lists (Anthropic Nov 2025): Outdated — Opus 4.6 runs coherently for 2+ hours without micro-decomposition
- Sprint contracts between generator/evaluator: Removed by Anthropic in March 2026 with Opus 4.6
- Detailed verification scripts per criterion: Unnecessary — modern evaluators figure out how to verify
- Implementation-prescriptive specs: Causes cascading errors when the prescribed approach is wrong

### 10. Role files and initialization

**Decision:** Each project gets a `HarnessKit/Roles/` folder with three project-specific role files: `Planner.md`, `Generator.md`, `Evaluator.md`. These are populated during `harness-kit:init` based on project investigation + user Q&A. The plugin's skills contain the general protocol knowledge; the role files contain the project-specific context.

**Why:** Skills in the plugin are the same for all projects (how to coordinate, how to evaluate, the dual-session protocol). But WHAT to evaluate and HOW to verify is project-specific. The role files bridge this gap. Every session reads its role file as the first thing — it's the project-specific briefing.

**Role files in the target project:**
```
HarnessKit/Roles/
├── Planner.md      # Key files to investigate, planning priorities, domain context
├── Generator.md    # Architecture, conventions, build commands, test suites
└── Evaluator.md    # Available verification tools, evaluation priorities, always/never rules
```

**Evaluator.md is the most important** because effective evaluation is the hardest and most project-specific part. It documents:
- Available verification tools (build, test, UI interaction, screenshots)
- How to use each tool (commands, MCP tools, scripts)
- Evaluation priorities (from user input during init)
- "Always do" rules (e.g., always build before evaluating, always take screenshots)
- "Never do" rules (e.g., never mark PASS without building successfully)

**The init skill (`harness-kit:init`) does:**

1. Investigates the project automatically: reads AGENTS.md, CLAUDE.md, README, Package.swift / package.json, checks for Xcode project, web framework, test runners, existing MCP server configs

2. Asks focused questions: project type confirmation, evaluation scope (UI? logic? performance? accessibility?), existing tools and patterns

3. Guides tool setup with strong recommendations. Emphasizes that an evaluator that can only read code will miss visual bugs, broken navigation, spacing issues, and interaction problems. Recommends:
   - **Apple platform:** Xcode MCP (built-in, for builds/previews/tests) + joshuayoes/ios-simulator-mcp (1,800 stars, Anthropic-endorsed, for UI interaction/screenshots) + AppleScript for app lifecycle
   - **Web:** Playwright MCP for full browser interaction
   - **CLI:** Test runners and output verification
   - **Domain systems:** Scenario-based testing, case files

4. Populates all three role files with project-specific context

**Reference documents** live under the main skill (used by both init and runtime):
```
skills/harness-kit/references/
├── RolePlanner.md                   # General planner knowledge
├── RoleGenerator.md                 # General generator knowledge
├── RoleEvaluator.md                 # General evaluator knowledge
├── DualSessionProtocol.md           # How two sessions coordinate
├── SpecFormat.md                    # Spec.md structure and principles
├── EvalStrategy-ApplePlatform.md    # Xcode MCP + ios-simulator-mcp + AppleScript setup
├── EvalStrategy-Web.md              # Playwright MCP setup and patterns
├── EvalStrategy-CLI.md              # Test runners, output verification
└── EvalStrategy-Domain.md           # Case-based reasoning, scenario testing
```

**Apple platform evaluation tools (researched):**

| Tool | Purpose | Stars |
|------|---------|-------|
| Apple Xcode MCP (`xcrun mcpbridge`) | Build, test, SwiftUI preview screenshots (`RenderPreview`), build diagnostics | Built-in |
| joshuayoes/ios-simulator-mcp | Tap, swipe, read accessibility tree, screenshot running app in simulator | 1,800 |
| adoosh-afk/ios-simulator-mcp | Fork using IndigoHID — fixes tap reliability inside ScrollViews | 0 (new) |
| `osascript` (AppleScript) | Run/stop app via Xcode (Xcode MCP can't do this) | Built-in |
| `xcrun simctl` | Boot/shutdown simulators, take screenshots, set dark mode, deep links | Built-in |

**Alternatives considered:**
- No role files (evaluator adapts on its own): Misses project-specific tools and priorities, inconsistent across sessions
- YAML evaluator profiles: Rigid, hard to maintain, doesn't capture nuance
- Single Config.json strategy field: Too minimal — doesn't capture tool setup, commands, or priorities
- Full evaluator profile system (ChatGPT proposal): Over-engineered, creates maintenance burden

### 11. Plugin structure: one command + one skill

**Decision:** HarnessKit has exactly two components:

1. **`init` command** (`commands/init.md`) — user runs `/harness-kit:init` once per project. Never auto-loads. Handles project investigation, user Q&A, tool installation, and populating `HarnessKit/Roles/`.

2. **`harness-kit` skill** (`skills/harness-kit/SKILL.md`) — auto-triggers when user mentions HarnessKit, missions, etc. Contains ALL orchestration logic: planning, generation, evaluation, coordination, resumption. Role-specific references are read conditionally based on which role this session has.

**Plugin directory structure:**
```
HarnessKit/                              # The plugin repo
├── .claude-plugin/plugin.json
├── commands/
│   └── init.md                          # /harness-kit:init (manual only)
├── skills/
│   └── harness-kit/
│       ├── SKILL.md                     # THE skill — orchestrates everything
│       └── references/
│           ├── RolePlanner.md           # How to be an effective planner
│           ├── RoleGenerator.md         # How to be an effective generator
│           ├── RoleEvaluator.md         # How to be an effective evaluator
│           ├── DualSessionProtocol.md   # How two sessions coordinate
│           ├── SpecFormat.md            # Spec.md structure and principles
│           ├── EvalStrategy-ApplePlatform.md
│           ├── EvalStrategy-Web.md
│           ├── EvalStrategy-CLI.md
│           └── EvalStrategy-Domain.md
├── README.md
└── LICENSE
```

**Why one skill, not three:**
- The skill determines the role from the user's prompt (not from which skill was invoked)
- Role-specific knowledge lives in reference files, read only when needed
- Simpler for the user — one skill name to remember
- The skill body contains the overall protocol; references contain the depth

**How the skill determines the role:**
- "Let's use HarnessKit to work on X" → Planner (new mission)
- "I'm the Generator for mission X" (pasted prompt) → Generator
- "I'm Evaluator A for mission X" (pasted prompt) → Evaluator
- "Continue" / resumption → Check State.json, resume last role

**How the skill reads role-specific context:**
1. Reads the appropriate plugin reference (e.g., `references/RoleGenerator.md`)
2. Reads the project-specific role file (e.g., `HarnessKit/Roles/Generator.md`)
3. Both inform the session's behavior

**User workflow:**

1. **Setup (once):** `/harness-kit:init` → answers questions, creates HarnessKit/

2. **New mission:** User says "Let's use HarnessKit to add JWT auth"
   - Skill auto-loads, acts as Planner
   - Asks: "Do you want dual planning with a parallel session?"
   - If yes: generates a prompt for the user to paste into a second session
   - Planning proceeds (single or dual)
   - Spec.md written and finalized

3. **Transition to execution:** Planning done →
   - Asks: "Do you want dual evaluation?"
   - Generates prompts for Generator + Evaluator(s) sessions
   - User creates new sessions, pastes prompts
   - Sessions auto-coordinate via State.json + watchman-wait

4. **Resumption after crash:** User continues session, says "continue"
   - Skill checks State.json, sees role and state
   - Resumes (working or watching for the other session)

**The generated prompts** are the key UX mechanism. The skill generates ready-to-paste text like:
```
HarnessKit: I'm the Generator for mission 001-JWTAuth.
Read the spec and start implementing.
```
These prompts trigger the skill in the new session, which then reads the role from the prompt text and proceeds accordingly.

**Codex compatibility:** During init, a symlink is created from `.agents/skills/harness-kit/` to the plugin's skill directory. When the user pastes an evaluator or planner prompt into Codex, the symlinked skill loads and follows the same instructions.

**Alternatives considered:**
- Separate skills per role (harness-plan, harness-generate, harness-eval): More commands to remember, harder to maintain, role-specific logic better handled by conditional reference loading
- Separate /harness-kit:continue skill: Not needed — each role's logic handles resumption by checking State.json
- Separate /harness-kit:status skill: Status is built into the main skill — user just asks "what's the status?"

### 12. Git commit policy

**Decision:** Commit behavior is configured during `harness-kit:init` and documented in Config.json. The init command reads existing commit rules from AGENTS.md/CLAUDE.md, considers the project's conventions, and asks the user focused questions.

**Default behavior (suggested for quick setup):**

- **Generator commits at milestones** — the Planner can suggest natural milestone points in the spec, but the Generator decides when to commit. Each commit should represent a coherent, buildable state.
- **HarnessKit/ files are NOT committed until the mission is fully complete** — the coordination files (State.json, Gen/, Eval/, etc.) stay uncommitted during the mission. Only when the user confirms the mission is done are HarnessKit/ files committed (as part of the archive).
- **Feature branches per mission** — each mission gets its own branch (e.g., `001-jwt-auth`), following git conventions (lowercase, dashes). The branch name mirrors the mission folder name.

**Init questions for the user:**
1. "Should the Generator make commits automatically at milestones?" (default: yes)
2. "Should each mission use a feature branch?" (default: yes) — if yes, follows the project's branch naming convention
3. "Any specific commit message conventions?" (reads from existing AGENTS.md/CLAUDE.md)

**Config.json stores these preferences:**
```json
{
  "git": {
    "autoCommit": true,
    "featureBranches": true,
    "branchPrefix": "",
    "commitConventions": "read from AGENTS.md"
  }
}
```

**Alternatives considered:**
- Always auto-commit: Some users don't want AI making commits — must be configurable
- Never auto-commit: Loses the milestone-based progress tracking that makes long missions recoverable
- Commit HarnessKit/ files during the mission: Pollutes git history with coordination artifacts that change every few minutes

### 13. Mission completion: two-loop architecture with user feedback

**Decision:** A mission is NEVER complete just because the AI says PASS. The AI's PASS means "we're ready for your review." Only the user can complete a mission. This is the most important architectural decision in HarnessKit.

**The two loops:**

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│  OUTER LOOP (Human in the loop)                                     │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                                                            │     │
│  │  INNER LOOP (AI autonomous)                                │     │
│  │                                                            │     │
│  │  Generator implements → Evaluator evaluates                │     │
│  │       ↑                        │                           │     │
│  │       └──── FAIL/GAPS ────────┘                           │     │
│  │                                                            │     │
│  │  Repeats until Evaluator says PASS                         │     │
│  │                                                            │     │
│  └──────────────────────┬─────────────────────────────────────┘     │
│                         │                                           │
│                    AI PASS                                           │
│                         │                                           │
│                         ▼                                           │
│              Review Briefing presented to user                      │
│              (what was done, what to test, AI limitations)          │
│                         │                                           │
│                         ▼                                           │
│              User tests and reviews                                 │
│                    │              │                                  │
│              "Looks good"    Has feedback                           │
│                    │              │                                  │
│                    ▼              ▼                                  │
│            MISSION COMPLETE   User feedback documented              │
│                               → back to inner loop                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Detailed flow:**

**Step 1: AI Inner Loop**
Generator and Evaluator(s) iterate autonomously until the Evaluator says PASS. This is the existing Gen/Eval coordination described in Decision 4.

**Step 2: AI PASS → Review Briefing**
When the Evaluator says PASS, the Generator session presents a **Review Briefing** to the user. This is NOT Summary.md (that's the final archive). The Review Briefing includes:

1. **What was done** — high-level summary of the implementation
2. **Stats** — files created/changed, lines of code, number of Gen/Eval rounds, number of user feedback rounds (if any)
3. **Issues found and fixed** — significant bugs or problems the Evaluator caught and the Generator fixed
4. **Key decisions made** — architectural or implementation choices the Generator made
5. **What the user should test** — specific things to check manually, with clear instructions:
   - "Open the app and navigate to Settings → Auth"
   - "Try logging in with invalid credentials"
   - "Check if the refresh token flow works after 15 minutes"
6. **Aspects AI cannot fully verify** — explicitly called out:
   - "We created a new login screen but could not fully verify the visual design — please check spacing, font sizes, and color consistency"
   - "The error messages are functional but we recommend checking if the wording feels right to your users"
   - "Animations and transitions were not testable via our tools"

The Generator also notifies the user (via claude-notify if available) that the review is ready.

**Step 3: User Reviews and Gives Feedback**
The user tests the implementation. Two outcomes:

**A) User says "looks good" / "approved" / "done":**
→ Mission is COMPLETE (see Step 5)

**B) User has feedback:**
The user describes issues, changes, or refinements. This is documented in `UserFeedback/Feedback-NNN.md`:

```
HarnessKit/001-JWTAuth/
├── UserFeedback/
│   ├── Round-001.md       # User's first feedback after initial AI PASS
│   ├── Round-002.md       # User's second feedback (after AI addressed round 1)
│   └── ...
```

Each feedback round file captures the user's exact words (like User Intent in Spec.md), plus any clarifications. User feedback is treated as **an extension of the spec** — it can:
- Point out bugs the AI missed
- Request changes to the implementation approach
- Change direction ("now that I see it, I want it differently")
- Add new requirements that weren't in the original spec

**Step 4: AI Inner Loop Resumes**
The Generator reads the user feedback, the Evaluator reads it too. They re-enter the inner loop:
- Generator makes changes to address the feedback
- Evaluator verifies the changes address ALL points in the feedback AND don't regress existing functionality
- They iterate until the Evaluator says PASS again
- Another Review Briefing is presented, this time focusing on "what changed since last review"

**Step 5: Mission Complete**
When the user says "looks good":
1. State.json updated: `"phase": "complete"`, `"completedBy": "user"`
2. Summary.md generated (the final archive document)
3. HarnessKit/ files committed (the coordination artifacts become part of the archive)
4. Config.json: `"currentMission": null`
5. If feature branch: prompt user about merging
6. Generator session: "Mission 001-JWTAuth complete. Summary saved."

**File structure with user feedback:**
```
HarnessKit/001-JWTAuth/
├── Spec.md                    # Original spec from planning
├── State.json                 # Final state: phase: "complete"
├── Gen/
│   ├── Round-001.md           # Initial implementation
│   ├── Round-002.md           # After evaluator feedback
│   └── Round-003.md           # After user feedback round 1
├── Eval/
│   ├── Round-001.md           # FAIL
│   ├── Round-002.md           # PASS (first AI pass)
│   └── Round-003.md           # PASS (after user feedback)
├── UserFeedback/
│   └── Feedback-001.md           # User's feedback after first AI pass
├── Planning/                  # (if dual planners were used)
├── EvalDiscussion/            # (if dual evaluators were used)
└── Summary.md                 # Final archive
```

**Round numbering is continuous across the whole mission.** If the first AI inner loop was 2 rounds (Gen-001, Eval-001 FAIL, Gen-002, Eval-002 PASS), and then the user gives feedback, the next Gen/Eval round is 003. This makes the timeline clear.

**Why this matters:**
- AI tools are good but not perfect — they WILL miss things, especially visual/UX issues
- The user feedback loop catches what AI can't
- Documenting feedback rounds creates a record of the iterative refinement process
- The Review Briefing with "what to test" and "AI limitations" sets honest expectations
- The user is always in control of when a mission is truly done

**Alternatives considered:**
- AI PASS = mission complete: Dangerous — AI marks things done that aren't actually done from the user's perspective
- No structured user feedback: Feedback gets lost in chat history, not documented
- Separate mission for user feedback: Creates overhead, loses context of the original mission

---

## Open — To Be Discussed

All major architectural decisions have been made. Remaining topics are implementation details that can be decided during development:

- Exact content and wording of the Review Briefing
- State.json schema details (full field list)
- Config.json schema details (full field list)
- SKILL.md auto-trigger keywords
- Codex symlink mechanics during init
- Exact prompt templates for parallel sessions

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
