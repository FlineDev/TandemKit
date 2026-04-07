# TandemKit

Claude + Codex plan together, Claude builds, Claude + Codex verify together. They converge until it's right.

TandemKit is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that runs three Claude Code sessions — Planner, Generator, and Evaluator — to produce higher-quality results than a single session alone. In the Planner and Evaluator sessions, Claude automatically launches [Codex](https://openai.com/index/introducing-codex/) as a background task within its own session, so two different models independently investigate and then converge on a result. You never need to open Codex separately — everything happens inside Claude Code.

## Who Is This For?

You have both a **Claude Code** subscription and a **Codex** subscription. You've noticed that Claude is great at executing, adjusting related code, and communicating — but can sometimes declare "looks good!" prematurely. Codex reads more carefully, digs deeper, and catches things Claude misses. TandemKit makes Claude invoke Codex internally as its second opinion — you get the benefits of both models without switching tools.

## Why TandemKit?

Anthropic's [Harness article](https://www.anthropic.com/engineering/harness-design-long-running-apps) (March 2026) showed that long-running AI sessions need structured evaluation to avoid premature completion. A single session tends to anchor on its own work and miss issues.

TandemKit applies that insight with a twist: instead of two Claude sessions checking each other, it pairs **Claude + Codex** within the same session — two different models that think differently. Claude runs Codex in the background, reads its findings, and they converge through structured back-and-forth. This gives you:

- **Two planners** — Claude and Codex investigate independently within the Planner session, then converge on a spec
- **One generator** — Claude implements against the spec
- **Two evaluators** — Claude and Codex verify independently within the Evaluator session, then converge on a verdict

Different models catch different issues. In early missions, Codex found real bugs that Claude marked as passing. The dual-model approach is the entire value proposition — there is no single-model mode.

The Harness article also showed that evaluation quality depends on **concrete verification tools**. Without them, evaluators guess based on surface impressions — apps "looked impressive but still had real bugs when you actually tried to use them." Giving evaluators the ability to interact with the running artifact — run tests, navigate the UI, take screenshots, inspect state — transforms evaluation from subjective impression into evidence-based assessment. TandemKit's `/tandemkit:init` sets up exactly these tools for your project type.

## How It Works

All three sessions are Claude Code sessions. Claude orchestrates everything — including launching Codex as a background task when a second opinion is needed.

```
USER
  │
  ├──> Planner Session (Claude invokes Codex internally, they converge on a spec)
  │       └──> Spec.md
  │
  ├──> Generator Session (Claude implements against Spec.md)
  │       └──> commits at milestones, signals Evaluator
  │
  └──> Evaluator Session (Claude invokes Codex internally, they converge on a verdict)
          └──> PASS / FAIL ──> Generator iterates until PASS
```

**Three Claude Code sessions for the entire mission:**
1. **Planner** — Claude investigates the codebase and launches Codex in the background to do the same. Both produce independent findings. Claude reads Codex's results, merges them, and they iterate until converged. You answer questions and approve the final spec.
2. **Generator** — Claude implements against the spec, committing at milestones. Fully autonomous — no Codex needed here since the Evaluator handles verification.
3. **Evaluator** — Claude evaluates independently while Codex does the same in the background. They converge on a verdict. On FAIL, the Generator fixes and resubmits. On PASS, you review the result.

You are active during planning, then step away while Generator and Evaluator loop autonomously until the work passes.

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

The only command you need to remember is `/tandemkit:planner`:

```bash
# Option A: Provide your goal directly
/tandemkit:planner Add JWT authentication with refresh tokens

# Option B: Just start the planner — it will ask you to describe your goal
/tandemkit:planner
```

After planning, Claude presents the exact commands to copy-paste for the Generator and Evaluator sessions. You don't need to remember those — they're always provided for you.

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
| **Apple platforms** (iOS, macOS, visionOS) | [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) CLI | Build, test, run simulator, UI automation, take screenshots, navigate the app |
| **Web** (frontend, full-stack) | [browser-use](https://github.com/browser-use/browser-use) CLI | Open pages, click around, take screenshots, extract data, verify UI flows |
| **CLI / Libraries** | Test suites (`swift test`, `npm test`, etc.) | Build, run tests, verify command output and exit codes |
| **Domain systems** (tax, health, legal) | Canonical case testing | Predefined test cases, consistency checks, fabrication detection |

The key principle: **the Evaluator should be able to do whatever a human reviewer would do** — build, run, navigate, screenshot, test. The more verification paths available, the harder it is for bugs to slip through.

### Strategy reference files

Evaluation strategies are documented in [`skills/evaluator/strategies/`](skills/evaluator/strategies/):

- **`Evaluation-Strategy-ApplePlatform.md`** — XcodeBuildMCP setup, simulator UI automation, SwiftUI previews
- **`Evaluation-Strategy-Web.md`** — browser-use CLI setup, token-optimized extraction patterns
- **`Evaluation-Strategy-Web-Playwright.md`** — Playwright MCP fallback for web projects
- **`Evaluation-Strategy-CLI.md`** — test suites, command-line verification, library testing
- **`Evaluation-Strategy-Domain.md`** — canonical case testing, consistency checks, fabrication detection

These files are what `/tandemkit:init` uses to configure your Evaluator. **PRs with new strategies or improvements to existing ones are welcome** — different project types benefit from different verification approaches.

### Project role files

During init, TandemKit creates three role files in your project's `TandemKit/` folder:

| File | Purpose |
|---|---|
| **`Planner.md`** | Project context for the Planner — documentation locations, domain references, key decisions |
| **`Generator.md`** | Project context for the Generator — build commands, code standards, available skills |
| **`Evaluator.md`** | Project context for the Evaluator — verification tools, test commands, evaluation checklist |

These are **your customization points**. Edit them any time to refine how each session works for your project. For example, add domain-specific test cases to `Evaluator.md`, point the Planner at additional documentation, or configure the Generator's commit conventions.

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
/tandemkit:planner --> Claude + Codex investigate --> converge --> user approval --> Spec.md
                                                                                      |
Generator session --> Claude implements --> signals Evaluator ----------------------->|
                ^                                                                     |
                └──── fix <-- FAIL <-- Claude + Codex evaluate <-- Evaluator session <─┘
                                          |
                                       PASS --> Review Briefing --> user approval --> done
```

### Sample Mission File Tree

```
TandemKit/
├── Config.json
├── Planner.md                       <-- project-specific planner context
├── Generator.md                     <-- project-specific generator context
├── Evaluator.md                     <-- project-specific evaluator context
├── ClaudeEvaluatorPrompt.md         <-- hardened system prompt
│
└── 003-DebugActivityTool/
    ├── State.json
    ├── Spec.md                      <-- approved spec
    ├── Summary.md                   <-- written at mission completion
    │
    ├── Planner-Discussion/
    │   ├── Claude-01.md             <-- Claude's investigation
    │   ├── Codex-01.md              <-- Codex's investigation (run by Claude)
    │   ├── Claude-02.md             <-- merged plan + user answers
    │   ├── Codex-02.md              <-- Codex review (NOT APPROVED - 1 high)
    │   ├── Claude-03.md             <-- revised plan
    │   ├── Codex-03.md              <-- Codex review (APPROVED)
    │   └── Claude-04.md             <-- final draft (> Spec.md)
    │
    ├── Generator/
    │   ├── Round-01.md
    │   ├── ChangedFiles-01.txt
    │   ├── Round-02.md
    │   └── ChangedFiles-02.txt
    │
    ├── Evaluator/
    │   ├── Round-01.md              <-- FAIL (2 high findings)
    │   ├── Round-01-Discussion/     <-- Claude + Codex convergence
    │   ├── Round-02.md              <-- PASS
    │   └── Round-02-Discussion/
    │
    └── UserFeedback/
        └── Feedback-01.md           <-- (if user gave feedback after PASS)
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

## License

MIT
