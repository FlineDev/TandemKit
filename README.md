# TandemKit

Describe your goal, approve the spec, then step away — Claude and Codex loop together until it's right.

TandemKit is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that runs three sessions — Planner, Generator, and Evaluator — with two of them pairing Claude and Codex as independent reviewers. You are only needed at two points: during **planning** (questions and spec approval) and at **review** (when evaluation passes and you give feedback or call it done). Between those two points, the Generator implements and the Evaluator verifies in a tight loop, with no manual review or copy-pasting from you. In both the Planner and Evaluator sessions, Claude automatically launches [Codex](https://openai.com/index/introducing-codex/) as a background task using the official [Codex plugin](https://github.com/openai/codex-plugin-cc), so two different models independently investigate and converge on a result — everything inside Claude Code.

## Who Is This For?

You have a **Claude Max** subscription (which includes Claude Code) and a **ChatGPT** subscription (which includes Codex). You work on tasks complex enough to warrant the extra cost — TandemKit is not recommended for simple, small, or mechanical tasks, since the multi-session loop uses significantly more tokens than a regular Claude session.

You've noticed that Claude is great at executing, adjusting related code, and communicating — but can sometimes declare "looks good!" prematurely. Codex reads more carefully, digs deeper, and catches things Claude misses. TandemKit pairs Claude and Codex in the Planner and Evaluator sessions — the two phases where independent investigation and verification matter most — while Claude handles implementation alone in between. You get the benefits of both models without switching tools.

## Why TandemKit?

Anthropic's [Harness article](https://www.anthropic.com/engineering/harness-design-long-running-apps) (March 2026) identified the core problem with agentic sessions: **Claude stops too early.** A single session anchors on its own work, declares "looks good!" prematurely, and misses real bugs — especially in longer, multi-step tasks. The fix is a separate evaluator session that verifies independently rather than rubber-stamping its own output.

TandemKit applies that insight with a twist: instead of two Claude sessions checking each other, it pairs **Claude + Codex** — two different models that approach problems differently — in both the planning and evaluation phases. See *How It Works* below for the exact session breakdown.

Different models catch different issues — not because one is better, but because they approach problems differently. Codex tends to explore more files and dig into details Claude passes over — a pattern observed consistently across months of working with both tools, and independently reported by others. TandemKit runs Codex at `--effort xhigh` (the maximum reasoning level) to get the most thorough investigation it can produce. In practice, Codex at this setting finds real bugs that Claude has already marked as passing. This is the second insight TandemKit builds on: the evaluator should not be the same model. The dual-model approach is the entire value proposition — there is no single-model mode.

The Harness article also showed that evaluation quality depends on **concrete verification tools**. Without them, evaluators guess based on surface impressions — apps "looked impressive but still had real bugs when you actually tried to use them." Giving evaluators the ability to interact with the running artifact — run tests, navigate the UI, take screenshots, inspect state — transforms evaluation from subjective impression into evidence-based assessment. TandemKit's `/tandemkit:init` sets up exactly these tools for your project type.

## How It Works

All three sessions are Claude Code sessions. Claude orchestrates everything — including launching Codex as a background task when a second opinion is needed.

```
USER  ── step 1: planning
  │
  └──> [1] Planner Session
             Claude ───────────────► Codex (launched by Claude, runs in background)
              │    ◄──── findings ── │
              └─────── converge ─────┘
                            │
                         Spec.md ◄── you review and approve before continuing

USER  ── step 2: open both sessions in parallel — they coordinate autonomously from here
  │
  ├──> [2] Generator Session (reads Spec.md)
  │          Claude implements, commits at milestones
  │
  └──> [3] Evaluator Session
             Claude ───────────────► Codex (launched by Claude, runs in background)
              │    ◄──── findings ── │
              └─────── converge ─────┘
                            │
                            ├──> FAIL ──> Generator fixes & resubmits ──> back to [3]
                            └──> PASS ──> Review Briefing ──> User
```

**Three Claude Code sessions for the entire mission:**
1. **Planner** — Claude investigates the codebase and launches Codex in the background to do the same. Both produce independent findings. Claude reads Codex's results, merges them, and they iterate until converged. You answer questions and approve the final spec.
2. **Generator** — Claude implements against the spec, committing at milestones. Fully autonomous — no Codex needed here since the Evaluator handles verification.
3. **Evaluator** — Claude evaluates independently while Codex does the same in the background. They converge on a verdict. On FAIL, the Generator fixes and resubmits. On PASS, you review the result.

You are active during planning, then step away while Generator and Evaluator loop autonomously. When evaluation passes, you receive a Review Briefing — approve it or give feedback, and the loop continues with updated requirements until you're satisfied.

The whole system is structurally similar to **pair programming** — a proven practice that demonstrably improves output quality even for experienced humans, simply by having a second set of eyes on the work. TandemKit maps directly onto that model: the Generator is the **driver** (writing code, fully focused on implementation), and the Evaluator — Claude and Codex working together — is the **navigator** (reviewing, catching mistakes, thinking ahead). That AI-to-AI driver/navigator loop is the core of what TandemKit adds over a single session. You play the navigator role at two points: during planning (guiding the investigation and approving the spec) and at the final review (deciding whether the result meets your standard or needs another pass).

**Model and effort settings:** Codex runs at `--effort xhigh` (maximum) throughout. Claude runs at whatever model and effort level you have configured locally — Sonnet 4.6 is the minimum recommended model; Opus produces better results at higher cost. Both are yours to tune based on task complexity and how much you want to spend.

## Installation

Start Claude Code, then run:

```
/plugin marketplace add FlineDev/Marketplace
```

```
/plugin install tandemkit
```

```
/tandemkit:init
```

`/tandemkit:init` investigates your project, asks configuration questions, and sets up role files. Run it once per project.

If you're in an active session, run `/reload-plugins` to activate immediately. TandemKit is part of the [FlineDev Marketplace](https://github.com/FlineDev/Marketplace) — see the full list of available plugins there.

> [!TIP]
> **Automatic Updates:** By default, third-party plugins don't auto-update. To receive new features and fixes:
> 1. Type `/plugin` and press Enter
> 2. Switch to the **Marketplaces** tab
> 3. Navigate to **FlineDev** and press Enter
> 4. Press Enter on **Enable auto-update**

### Prerequisites

- **Claude Code** with the `codex-plugin-cc` plugin installed (Claude uses this to invoke Codex internally)
- **Codex CLI** authenticated (`/codex:setup` to verify)
- **python3** (used by coordination scripts)
- **watchman** (`brew install watchman`) — for file-watching between sessions

The `/tandemkit:init` command checks all prerequisites and guides you through setup.

## Quick Start

The only command you need to remember is `/planner` — Claude resolves it to `/tandemkit:planner` automatically:

```
# Option A: Provide your goal directly
/planner Add JWT authentication with refresh tokens

# Option B: Just start — the planner will ask you to describe your goal
/planner
```

After planning, Claude presents the exact commands to copy-paste for the Generator and Evaluator sessions. Those use the full `/tandemkit:` prefix because the short alias doesn't apply reliably to pasted text — but you never need to remember them yourself, they're always provided for you.

## Commands

| Command | When to use |
|---------|-------------|
| `/tandemkit:init` | **Once per project** — first-time setup, project investigation, role configuration |
| `/tandemkit:planner` | **Every mission** — the only command you need to remember. Describe your goal (or omit it and the planner will ask). |
| `/tandemkit:generator` | Copy-paste from planner output — never need to remember this |
| `/tandemkit:evaluator` | Copy-paste from planner output — never need to remember this |

## Evaluation Strategies & Customization

### Why verification tooling matters

An evaluator that can only read code will miss real bugs. The Harness article demonstrated this directly: "the evaluator used the Playwright MCP to click through the running application the way a user would, testing UI features, API endpoints, and database states." Without concrete tools, evaluation degrades to guessing.

`/tandemkit:init` detects your project type and recommends the right verification tools:

| Project Type | Primary Tool | What it enables |
|---|---|---|
| **Apple platforms** (iOS, macOS, visionOS) | [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) CLI + Apple's Xcode MCP | Build, test, run simulator, UI automation, screenshots, navigate the app; SwiftUI preview screenshots and Swift snippet execution via Xcode MCP |
| **Web** (frontend, full-stack) | [browser-use](https://github.com/browser-use/browser-use) CLI | Open pages, click around, take screenshots, extract data, verify UI flows |
| **CLI / Libraries** | Test suites (`swift test`, `npm test`, etc.) | Build, run tests, verify command output and exit codes |
| **Domain systems** (tax, health, legal) | Canonical case testing | Predefined test cases, consistency checks, fabrication detection |

The key principle: **the Evaluator should be able to do whatever a human reviewer would do** — build, run, navigate, screenshot, test. The more verification paths available, the harder it is for bugs to slip through.

> **Apple platforms note:** XcodeBuildMCP CLI and Apple's built-in Xcode MCP are complementary, not alternatives. XcodeBuildMCP handles everything runtime: building, running the simulator, UI automation, tapping, swiping, accessibility tree, log capture. Apple's Xcode MCP covers two things it uniquely does well: `RenderPreview` (render SwiftUI previews as screenshots without running the app) and `ExecuteSnippet` (compile and run a Swift snippet in the project context). TandemKit uses both — you don't need to choose.

Both XcodeBuildMCP and browser-use ship an official Claude Code skill that primes the Evaluator with the right commands and patterns. `/tandemkit:init` guides you through installing both — but the commands are:

```bash
# XcodeBuildMCP: install CLI, then run the interactive skill installer
# (choose user-level + CLI variant; ignore the MCP setup — not needed here)
brew tap getsentry/xcodebuildmcp && brew install xcodebuildmcp
xcodebuildmcp init

# browser-use: install CLI, then run the interactive skill installer
# (select Claude Code + Codex, user-level, symlink)
curl -fsSL https://browser-use.com/cli/install.sh | bash
npx skills add https://github.com/browser-use/browser-use --skill browser-use
```


### Strategy reference files

Evaluation strategies are documented in [`skills/evaluator/strategies/`](skills/evaluator/strategies/):

- **`ApplePlatform.md`** — XcodeBuildMCP setup, simulator UI automation, SwiftUI previews
- **`Web.md`** — browser-use CLI setup, token-optimized extraction patterns
- **`Web-Playwright.md`** — Playwright MCP fallback for web projects
- **`CLI.md`** — test suites, command-line verification, library testing
- **`Domain.md`** — canonical case testing, consistency checks, fabrication detection

These files are what `/tandemkit:init` uses to configure your Evaluator. **PRs with new strategies or improvements to existing ones are welcome** — different project types benefit from different verification approaches.

### Project role files

During init, TandemKit creates three role files in your project's `TandemKit/` folder:

| File | Purpose |
|---|---|
| **`Planner.md`** | Project context for the Planner — documentation locations, domain references, key decisions |
| **`Generator.md`** | Project context for the Generator — build commands, code standards, available skills |
| **`Evaluator.md`** | Project context for the Evaluator — verification tools, test commands, evaluation checklist |

These are **your customization points**. Edit them any time to refine how each session works for your project. For example, add domain-specific test cases to `Evaluator.md`, point the Planner at additional documentation, or configure the Generator's commit conventions.

### Hardened Evaluator system prompt

By default, Claude optimizes its tool use for efficiency — reading diffs instead of full files, sampling relevant lines, skipping re-verification of criteria it already checked. This is fine for most work, but exactly wrong for evaluation, where thoroughness matters more than speed.

TandemKit addresses this with `TandemKit/ClaudeEvaluatorPrompt.md` — a hardened system prompt created during init that overrides Claude's default efficiency behavior for the Evaluator session. It enforces explicit rules that Claude would otherwise bend in the name of token savings:

- **Read full implementation files**, not diffs or snippets
- **Gather explicit evidence** (file path, line number, actual behavior) before deciding on each criterion
- **No inherited trust between rounds** — re-verify all criteria each round, regardless of prior verdicts
- **Second pass if zero findings** — non-trivial work with no issues is suspicious; do a second pass looking for omissions, regressions, and edge cases
- **BLOCKED, not PASS**, when required verification can't be performed

The Planner provides the exact launch command at the end of the planning phase:

```bash
claude --append-system-prompt-file TandemKit/ClaudeEvaluatorPrompt.md
```

Open your Evaluator session with this command so the hardened prompt is active from the start.

## The Convergence Protocol

Both the Planner and Evaluator use the same back-and-forth pattern. Claude launches Codex as a background task within its own session, reads the results, and they iterate until they agree. This is the core quality mechanism.

```
    ROUND 1 (parallel, within the same Claude session)
    ---------------------------------------------------
    Claude investigates          Codex runs in background
           |                              |
           v                              v
      Claude-01.md                   Codex-01.md
           |                              |
           └────── Claude reads Codex-01 ─┘
                        |
                        v
    ROUND 2
    -------
    Claude creates merged/improved version
    (incorporates Codex findings, explains disagreements)
                        |
                        v
                   Claude-02.md
                        |
              Claude sends Claude-02 to Codex for review
              Codex re-investigates any disagreed points
                        |
                        v
                   Codex-02.md  (agreement feedback with severity)
                        |
    ROUND 3+
    --------
    Continue until no high or medium disagreements remain.
    Convergence typically takes 2-4 exchanges.
```

**Key rules:**
1. **Re-investigate, don't argue from memory.** When disagreeing, both models re-read the actual source files.
2. **Severity-based convergence.** APPROVED when no high or medium disagreements remain. No fixed iteration limit.
3. **Stuck escalation.** If the same disagreement persists across 3 rounds, both positions are presented to you for a decision.

### Severity Levels

| Level | In Findings (bugs/issues) | In Agreement (disagreements) |
|---|---|---|
| **High** | Acceptance criterion fails, regression, security issue | Assessment is factually wrong or misses critical issue |
| **Medium** | Non-blocking issue, overclaim, missing edge case | Assessment could be improved or is missing context |
| **Low** | Suggestion, minor wording, style | Minor note — acceptable either way |

## Mission Lifecycle

```
    /planner
       │  Claude + Codex investigate, converge
       │  you review and approve
       ▼
    Spec.md
       │
       ▼
    Generator ◄────────────────────────┐
       │  Claude implements            │
       │  commits at milestones        │ FAIL: fix & resubmit
       ▼                               │
    Evaluator                          │
       │  Claude + Codex evaluate      │
       │  converge on verdict          │
       ├── FAIL ───────────────────────┘
       │
       └── PASS ──► Review Briefing
                       ├── you approve ──► done
                       └── you give feedback ──► Generator iterates
```

When the Evaluator issues a PASS, it presents a Review Briefing summarizing what was built and verified. You can approve (done) or give feedback — if you give feedback, it becomes updated requirements and the Generator + Evaluator loop continues. You never need to intervene mid-loop; you only engage when you choose to review.

### The TandemKit Folder

`/tandemkit:init` creates a `TandemKit/` folder at your project root. It holds a few project-wide files set up once, plus one subfolder per mission:

```
TandemKit/
├── Config.json                 ← naming convention, project type, mission counter
├── Planner.md                  ← project-specific planner context
├── Generator.md                ← project-specific generator context
├── Evaluator.md                ← project-specific evaluator context
├── ClaudeEvaluatorPrompt.md    ← hardened system prompt for Evaluator session
│
├── 001-AddUserSettings/        ← completed mission
├── 002-FixLoginFlow/           ← completed mission
└── 003-AddDarkMode/            ← active mission
```

Missions use globally unique 3-digit numbers — never reused, even after deletion, so log references stay stable.

The naming convention is auto-detected during `/tandemkit:init` — Swift/Apple projects use UpperCamelCase (as shown above), while JS/web projects use kebab-case (`add-dark-mode/`, `claude-01.md`, etc.). The convention is stored in `Config.json`.

**Full visibility — everything is plain text.** Every investigation, round, and convergence exchange is stored as readable files. You can open any `Claude-02.md` or `Codex-01.md` to see exactly what was found, what was disputed, and how it was resolved. Nothing is hidden in a database or API log.

**To commit or not** — `/tandemkit:init` asks whether to gitignore these files. Many people commit them: they're plain text, never edited after the fact, and become a full audit trail of the development history. You might prefer to gitignore if you don't want this detail in your team's shared history. Either way, the files stay on disk for the duration of the mission.

### Inside a mission

```
003-AddDarkMode/
├── State.json                ← current phase, session statuses, round counter
├── Spec.md                   ← approved spec (written by Planner, approved by you)
├── Summary.md                ← written at mission completion
│
├── Planner-Discussion/
│   ├── Claude-01.md          ← Claude's independent investigation
│   ├── Codex-01.md           ← Codex's independent investigation (background)
│   ├── Claude-02.md          ← Claude's merged plan
│   ├── Codex-02.md           ← Codex review: NOT APPROVED (1 high disagreement)
│   ├── Claude-03.md          ← revised plan addressing disagreement
│   ├── Codex-03.md           ← Codex review: APPROVED
│   └── Claude-04.md          ← final plan draft (→ Spec.md)
│
├── Generator/
│   ├── Round-01.md           ← Generator implementation report, round 1
│   ├── ChangedFiles-01.txt   ← files changed in round 1
│   ├── Round-02.md           ← Generator implementation report, round 2
│   └── ChangedFiles-02.txt
│
├── Evaluator/
│   ├── Round-01.md           ← verdict: FAIL (2 high findings)
│   ├── Round-01-Discussion/  ← Claude + Codex convergence files for round 1
│   │   ├── Claude-01.md      ← Claude's independent evaluation
│   │   ├── Codex-01.md       ← Codex's independent evaluation
│   │   ├── Claude-02.md      ← Claude's merged evaluation
│   │   └── Codex-02.md       ← Codex review: APPROVED
│   ├── Round-02.md           ← verdict: PASS
│   └── Round-02-Discussion/
│       ├── Claude-01.md
│       ├── Codex-01.md
│       └── Claude-02.md      ← final merged evaluation (→ Round-02.md)
│
└── UserFeedback/
    └── Feedback-01.md        ← user feedback after PASS (triggers another loop)
```

## Design Decisions

### Why always dual-model (Claude + Codex)

There is no single-model mode. Different models catch different things — Codex found real bugs that Claude missed in early missions. If Codex is unavailable, the session blocks until it's fixed. Solo Claude without Codex is just regular Claude Code.

### Why NOT fresh Codex threads per evaluation round

Context accumulation is valuable — by Round 6, Codex knows the codebase and past issues. "Fresh eyes" comes from two different models, not context amnesia. The re-investigation rule prevents lazy anchoring.

### Why severity-based convergence, not numeric scores

Scores (1-10) can hide criterion failures behind a good average. A score of 8/10 could mean 2 criteria completely failed. Criterion-by-criterion PASS/FAIL with severity-based agreement is fundamentally safer.

### Why the Generator doesn't invoke Codex

The Generator implements against a spec. Implementation correctness is verified by the Evaluator (where Claude invokes Codex). Adding Codex to the Generator would double the cost of every implementation round for marginal benefit — the same issues will be caught during evaluation.

## Tips & Known Limitations

### Keep missions focused — TandemKit is not a replacement for task planning

TandemKit evaluates the full spec in one pass. There is no milestone-by-milestone or phase-by-phase evaluation — the Generator implements the complete spec, then the Evaluator verifies it as a whole. This is intentional: partial evaluation of partially implemented work tends to produce noisy, inconclusive verdicts.

The practical implication is that **mission scope matters**. A mission that spans a large feature with many acceptance criteria will produce large evaluation rounds that strain context limits and make findings harder to act on. If a task feels too large to describe cleanly in a single spec, it probably is.

The right approach is to split upfront — before starting TandemKit — rather than trying to phase evaluation mid-mission. [PlanKit](https://github.com/FlineDev/PlanKit) is designed exactly for this: it breaks a large feature into focused, session-sized implementation steps. Each step becomes its own TandemKit mission with a tight spec and a tractable evaluation scope. No PlanKit required though — any upfront breakdown works. The point is that a well-scoped mission produces a spec that two AI models can evaluate completely and confidently in one pass.
