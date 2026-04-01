# HarnessKit

Planner / Generator / Evaluator orchestration for Claude Code and Codex.

HarnessKit coordinates parallel AI sessions for structured implementation and evaluation. One session implements, another evaluates — with fresh eyes, different models, and honest quality gates. The user stays in control, reviewing and giving feedback until the mission is truly done.

Inspired by Anthropic's [March 2026 harness architecture](https://www.anthropic.com/engineering/harness-design-long-running-apps).

## Why HarnessKit?

When you ask an AI to implement something and then ask it "does this look good?", it will almost always say yes — it made those decisions, so of course it thinks they're right. HarnessKit solves this by separating the roles:

- **Planner** investigates the codebase and writes a spec with clear acceptance criteria
- **Generator** implements the spec, committing at milestones
- **Evaluator** verifies the implementation with fresh eyes — building the project, running tests, taking screenshots, interacting with the UI

Each role runs in its own session with its own context. The Evaluator has never seen the implementation decisions — it only sees the spec and the result. This is what makes the evaluation honest.

## How It Works

### The Two Loops

```
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  INNER LOOP (AI autonomous)                                  │
  │                                                              │
  │  Generator implements → Evaluator evaluates                  │
  │       ^                        |                             │
  │       └──── FAIL/GAPS ────────┘                             │
  │                                                              │
  │  Repeats until Evaluator says PASS                           │
  │                                                              │
  └──────────────────────┬───────────────────────────────────────┘
                         │
                    AI PASS
                         │
                         v
              Review Briefing for the user
              (what was done, what to test, AI limitations)
                         │
                         v
              User tests and reviews
                    │              │
              "Looks good"    Has feedback
                    │              │
                    v              v
            MISSION COMPLETE   Feedback documented
                               → back to inner loop
```

The inner loop is fully autonomous — the Generator and Evaluator coordinate via files and watchman-wait, taking turns until the Evaluator is satisfied. Then the user reviews. Only the user can complete a mission.

### A Typical Mission

1. **Plan** — You describe your goal. The Planner investigates the codebase, asks questions, and writes a Spec.md with acceptance criteria.

2. **Execute** — You open parallel sessions: one Generator, one Evaluator. They coordinate automatically. The Generator implements, the Evaluator catches bugs with real tools (building, testing, screenshots, UI interaction). They iterate until PASS.

3. **Review** — The Generator presents a Review Briefing: what was done, what to test manually, and what AI couldn't verify (visual design, animations, UX feel). You test and either approve or give feedback.

4. **Feedback** — If you have feedback, it's documented and the inner loop restarts. Generator fixes, Evaluator re-verifies, you review again. Repeat until you're satisfied.

5. **Complete** — You say "looks good." Summary generated, coordination files committed, mission archived.

## Installation

### From the Marketplace (Coming Soon)

Once published to the FlineDev Marketplace:
```
/plugin marketplace add FlineDev/Marketplace
/plugin install harness-kit
```

### From Source (Current)

```bash
claude --plugin-dir /path/to/HarnessKit
```

**Note:** When using `--plugin-dir`, every new Claude Code session needs the same flag. If you open parallel sessions for Generator/Evaluator, each session must be started with `claude --plugin-dir /path/to/HarnessKit`. Once installed via marketplace, this is no longer needed — the plugin is available in all sessions automatically.

### Requirements

- Claude Code (or Codex for Evaluator/Planner sessions)
- `watchman` — installed automatically during setup (`brew install watchman` on macOS)

## Quick Start

### 1. Initialize (Once Per Project)

```
/harness-kit:init
```

This investigates your project, asks configuration questions, installs watchman if needed, and sets up the `HarnessKit/` folder with role-specific context.

### 2. Start a Mission

```
Let's use HarnessKit to add JWT authentication
```

The Planner investigates, asks questions, and produces a Spec.md.

### 3. Launch Execution Sessions

After planning, HarnessKit generates prompts to paste into new sessions:

**Generator session:**
```
You are the Generator for HarnessKit mission 001-JWTAuth.
Read the spec and start implementing.
```

**Evaluator session:**
```
You are the Evaluator for HarnessKit mission 001-JWTAuth.
Read the spec and wait for the Generator to signal ready.
```

Each session needs the HarnessKit plugin loaded. If using `--plugin-dir`, start each with `claude --plugin-dir /path/to/HarnessKit`. You can also reuse the Planner session as the Generator — clear/compact it and paste the Generator prompt.

The sessions coordinate automatically. You can walk away.

### 4. Review When Ready

When the inner loop completes, the Generator presents a Review Briefing in its session. Test the implementation, then either approve or give feedback.

## Features

### Dual Planning

Use two Planner sessions (e.g., Claude + Codex) for diverse investigation. Different models explore different approaches, cross-review each other's findings, and reconcile into a single spec.

### Dual Evaluation

Use two Evaluator sessions for more thorough review. They evaluate independently, cross-review, discuss until they agree, and produce one consensus evaluation.

### Codex Compatibility

The Evaluator and Planner skills work in both Claude Code and Codex. During init, a symlink is created so Codex sessions can load the HarnessKit skill. Use different models for Generator and Evaluator — different models catch different bugs.

### User Feedback Loop

AI PASS never means "done." After the inner loop completes, you review, test, and give feedback. Your feedback triggers another round of implementation and evaluation. The mission only completes when you say so.

### Mission Archive

Every mission is a numbered subfolder (`001-JWTAuth/`, `002-SettingsRefactor/`). Completed missions remain as archive — no cleanup needed. Each mission includes the spec, all generator/evaluator rounds, user feedback, and a summary.

### Git Integration

- Feature branches per mission (optional, default: yes)
- Generator commits at milestones (optional, default: yes)
- HarnessKit coordination files committed only at mission completion
- Respects project's existing commit conventions

## File Structure

### Plugin (Installed)

```
HarnessKit/
├── .claude-plugin/plugin.json
├── commands/
│   └── init.md                    # /harness-kit:init
├── skills/
│   └── mission/
│       ├── SKILL.md               # The orchestration skill
│       └── references/
│           ├── Role-Planner.md
│           ├── Role-Generator.md
│           ├── Role-Evaluator.md
│           ├── Dual-Session-Protocol.md
│           ├── Spec-Format.md
│           ├── Evaluation-Strategy-ApplePlatform.md
│           ├── Evaluation-Strategy-Web.md
│           ├── Evaluation-Strategy-CLI.md
│           └── Evaluation-Strategy-Domain.md
├── DESIGN.md
├── README.md
└── LICENSE
```

### In Your Project (After Init)

```
HarnessKit/
├── Config.json
├── Planner.md                    # Project-specific planner context
├── Generator.md                  # Project-specific generator context
├── Evaluator.md                  # Project-specific evaluator context
├── 001-JWTAuth/                  # A completed mission
│   ├── Spec.md
│   ├── State.json
│   ├── Summary.md
│   ├── Generator/
│   │   ├── Round-01.md
│   │   └── Round-02.md
│   ├── Evaluator/
│   │   ├── Round-01.md           # FAIL
│   │   ├── Round-01-Conversation/ # dual evaluator process
│   │   └── Round-02.md           # PASS
│   ├── Planner-Conversation/     # dual planner process
│   │   └── ...
│   └── UserFeedback/
│       └── Feedback-01.md
└── 002-SettingsRefactor/         # Current mission
    ├── Spec.md
    ├── State.json
    └── ...
```

## Terminology

| Term | Meaning |
|------|---------|
| **Mission** | A self-contained unit of work (plan → implement → evaluate → user review → done) |
| **Round** | One iteration within a mission. Round 1 = first implementation + evaluation. Round 2 = fixes + re-evaluation. |
| **Planner** | Investigates the codebase, writes the spec |
| **Generator** | Implements the spec, commits at milestones |
| **Evaluator** | Verifies the implementation with fresh eyes |
| **Review Briefing** | Summary presented to the user after AI PASS — what was done, what to test, AI limitations |
| **Inner Loop** | Generator ↔ Evaluator autonomous iteration |
| **Outer Loop** | AI work → User review → Feedback → AI work (human in the loop) |

## Evaluation Strategies

HarnessKit supports different evaluation strategies based on project type:

| Project Type | Primary Tools | What Gets Verified |
|---|---|---|
| **Apple Platform** | Xcode MCP, ios-simulator-mcp, AppleScript | Build, tests, previews, simulator UI interaction |
| **Web** | Playwright MCP | Build, tests, browser interaction, screenshots |
| **CLI / Library** | Test runners, command execution | Build, tests, output verification, API checks |
| **Domain System** | Canonical cases, consistency tests | Reasoning quality, case handling, fact accuracy |

During init, HarnessKit detects your project type and recommends the right tools.

## Crash Recovery

Both Claude Code and Codex restore the full session transcript when you resume. If your computer crashes or you close a terminal:

1. Reopen the session (both tools support session resumption)
2. Say "Continue" or "Resume"
3. The session has its full history — it knows what role it was playing
4. If it was in a wait loop (the `watchman-wait` background task was killed), it checks State.json and re-enters the wait loop

**Restart order doesn't matter.** Each session independently checks State.json to determine what to do. Resume whichever session you want first.

## Codex Compatibility

HarnessKit is designed to work with both Claude Code and Codex. During init, a symlink is created so Codex sessions can load the HarnessKit skill.

**Known limitations when using Codex:**
- `watchman-wait` requires the watchman daemon — verify it works in your Codex environment
- MCP servers (Xcode MCP, Playwright, ios-simulator-mcp) depend on your Codex sandbox configuration
- AppleScript execution may be restricted depending on Codex's sandbox mode
- If Codex cannot run these tools, it can still evaluate by reading code, checking tests, and analyzing the implementation — just without interactive UI verification

The Generator should always be Claude Code (it needs full file system access for implementation). The Evaluator and Planner roles are where Codex provides the most value — a different model's perspective.

## Design Philosophy

1. **Separation of concerns** — Generator implements, Evaluator verifies. No self-grading.
2. **Human in the loop** — AI PASS is "ready for review," not "done." Only the user completes a mission.
3. **File-based coordination** — sessions communicate through project files, not ephemeral mechanisms. Everything is inspectable and persistent.
4. **Cross-tool diversity** — different models catch different bugs. Use Claude for generation, Codex for evaluation (or vice versa).
5. **No unnecessary scaffolding** — with Opus 4.6 running coherently for 2+ hours, we don't need sprints, sprint contracts, or micro-task decomposition.
6. **Archive everything** — completed missions remain in numbered subfolders. No cleanup needed. The history of how features were built is valuable.

## License

MIT
