# TandemKit

Claude plans and builds. Codex reviews. They converge until it's right.

TandemKit is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that orchestrates Claude and Codex across three sessions — Planner, Generator, and Evaluator — to produce higher-quality results than either model alone. Claude handles execution and communication, Codex provides independent review. They iterate autonomously until both agree the work meets spec.

## Who Is This For?

You have both a **Claude Code** subscription and a **Codex** subscription. You've noticed that Claude is great at executing, adjusting related code, and communicating — but can sometimes declare "looks good!" prematurely. Codex reads more carefully, digs deeper, and catches things Claude misses. TandemKit puts them in tandem: Claude does the work, Codex keeps it honest.

## Why TandemKit?

Anthropic's [Harness article](https://www.anthropic.com/engineering/harness-design-long-running-apps) (March 2026) showed that long-running AI sessions need structured evaluation to avoid premature completion. A single session tends to anchor on its own work and miss issues.

TandemKit applies that insight with a twist: instead of two Claude sessions, it pairs **Claude + Codex** — two different models that think differently. This gives you:

- **Two planners** (Claude + Codex investigate independently, then converge on a spec)
- **One generator** (Claude implements against the spec)
- **Two evaluators** (Claude + Codex verify independently, then converge on a verdict)

Different models catch different issues. In early missions, Codex found real bugs that Claude marked as passing. The dual-model approach is the entire value proposition — there is no single-model mode.

## How It Works

```
USER
  |
  |---> Planner Session (Claude + Codex converge on a spec)
  |       \---> Spec.md
  |
  |---> Generator Session (Claude implements against Spec.md)
  |       \---> commits at milestones, signals Evaluator
  |
  \---> Evaluator Session (Claude + Codex converge on a verdict)
          \---> PASS / FAIL ---> Generator iterates until PASS
```

**Three persistent sessions for the entire mission:**
1. **Planner** — Claude and Codex investigate the codebase in parallel, ask you questions, and converge on a detailed spec. You approve it.
2. **Generator** — Claude implements against the spec, committing at milestones. Fully autonomous.
3. **Evaluator** — Claude and Codex independently verify the work, then converge on a verdict. On FAIL, the Generator fixes and resubmits. On PASS, you review the result.

The user is active during planning, then steps away while Generator and Evaluator loop autonomously until the work passes.

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

If you're in an active session, run `/reload-plugins` to activate immediately. TandemKit is part of the [FlineDev Marketplace](https://github.com/FlineDev/Marketplace) — see the full list of available plugins there.

> [!TIP]
> **Automatic Updates:** By default, third-party plugins don't auto-update. To receive new features and fixes:
> 1. Type `/plugin` and press Enter
> 2. Switch to the **Marketplaces** tab
> 3. Navigate to **FlineDev** and press Enter
> 4. Press Enter on **Enable auto-update**

### Prerequisites

- **Claude Code** with the `codex-plugin-cc` plugin installed (TandemKit always uses both models)
- **Codex CLI** authenticated (`/codex:setup` to verify)
- **python3** (used by coordination scripts)
- **watchman** (`brew install watchman`) — for file-watching between sessions

The `/tandemkit:init` command checks all prerequisites and guides you through setup.

## Quick Start

```bash
# 1. Start a Planner session
/tandemkit:planner Add JWT authentication with refresh tokens

# 2. After spec is approved, start Generator and Evaluator
#    (Planner shows the exact commands to copy)

# 3. Generator and Evaluator work autonomously until PASS
#    User reviews the final result
```

## Commands

| Command | Purpose |
|---------|---------|
| `/tandemkit:init` | First-time setup — project investigation, tool installation, role configuration |
| `/tandemkit:planner` | Start a mission — investigate, plan with Codex, produce a spec |
| `/tandemkit:generator` | Implement against the spec, commit at milestones, signal evaluator |
| `/tandemkit:evaluator` | Verify the Generator's work with Codex as second opinion |

## The Convergence Protocol

Both the Planner and Evaluator use the same back-and-forth pattern with Codex. This is the core quality mechanism.

```
    ROUND 1 (parallel)
    -------------------
    Claude investigates          Codex investigates (background)
           |                              |
           v                              v
      Claude-01.md                   Codex-01.md
           |                              |
           \------ Claude reads Codex-01 -/
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
              Codex reads Claude-01 + Claude-02
              (first time seeing Claude's work)
              Re-investigates any disagreed points
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
/tandemkit:planner --> investigation --> Codex convergence --> user approval --> Spec.md
                                                                                  |
/tandemkit:generator --> implement milestone --> signal evaluator --------------->|
                ^                                                                 |
                \---- fix <-- FAIL <-- evaluation <-- /tandemkit:evaluator <------/
                                          |
                                       PASS --> Review Briefing --> user approval --> done
```

### Sample Mission File Tree

```
TandemKit/
|-- Config.json
|-- Planner.md                       <-- project-specific planner context
|-- Generator.md                     <-- project-specific generator context
|-- Evaluator.md                     <-- project-specific evaluator context
|-- ClaudeEvaluatorPrompt.md         <-- hardened system prompt
|
\-- 003-DebugActivityTool/
    |-- State.json
    |-- Spec.md                      <-- approved spec
    |-- Summary.md                   <-- written at mission completion
    |
    |-- Planner-Discussion/
    |   |-- Claude-01.md             <-- investigation + questions
    |   |-- Codex-01.md              <-- investigation + questions
    |   |-- Claude-02.md             <-- merged plan + user answers
    |   |-- Codex-02.md              <-- review (NOT APPROVED - 1 high)
    |   |-- Claude-03.md             <-- revised plan
    |   |-- Codex-03.md              <-- review (APPROVED)
    |   \-- Claude-04.md             <-- final draft (-> Spec.md)
    |
    |-- Generator/
    |   |-- Round-01.md              <-- prose report
    |   |-- ChangedFiles-01.txt      <-- machine-readable file manifest
    |   |-- Round-02.md
    |   \-- ChangedFiles-02.txt
    |
    |-- Evaluator/
    |   |-- Round-01.md              <-- FAIL (2 high findings)
    |   |-- Round-01-Discussion/
    |   |   |-- Claude-01.md         <-- Claude's eval
    |   |   |-- Codex-01.md          <-- Codex's eval
    |   |   |-- Claude-02.md         <-- merged eval
    |   |   |-- Codex-02.md          <-- APPROVED
    |   |   \-- Claude-03.md         <-- final (-> Round-01.md)
    |   |
    |   |-- Round-02.md              <-- PASS
    |   \-- Round-02-Discussion/
    |       \-- ...
    |
    \-- UserFeedback/
        \-- Feedback-01.md           <-- (if user gave feedback after PASS)
```

## State Coordination

Generator and Evaluator communicate via `State.json` in the mission folder:

```json
{
  "phase": "planning | ready-for-execution | generation | evaluation | user-review | complete | abandoned",
  "round": 0,
  "generatorStatus": "null | researching | working | ready-for-eval | awaiting-user | done",
  "evaluatorStatus": "null | watching | evaluating | done",
  "verdict": "null | PASS | PASS_WITH_GAPS | FAIL | BLOCKED",
  "userFeedbackRounds": 0,
  "started": "ISO-8601",
  "updated": "ISO-8601"
}
```

## Design Decisions

### Why always dual-model (Claude + Codex)

There is no single-model mode. Different models catch different things — Codex found real bugs that Claude missed in early missions. If Codex is unavailable, the session blocks until it's fixed. Solo Claude without Codex is just regular Claude Code.

### Why NOT fresh Codex threads per evaluation round

Context accumulation is valuable — by Round 6, Codex knows the codebase and past issues. "Fresh eyes" comes from two different models, not context amnesia. The re-investigation rule prevents lazy anchoring.

### Why severity-based convergence, not numeric scores

Scores (1-10) can hide criterion failures behind a good average. A score of 8/10 could mean 2 criteria completely failed. Criterion-by-criterion PASS/FAIL with severity-based agreement is fundamentally safer.

### Why Generator doesn't use Codex

The Generator implements against a spec. Implementation correctness is verified by the Evaluator (with Codex). Adding Codex to the Generator would double the cost of every implementation round for marginal benefit.

## Project Structure

```
TandemKit/
|-- scripts/
|   |-- create-mission.sh            # Scaffold new mission folder
|   \-- wait-for-state.sh            # Generator<->Evaluator coordination
|-- skills/
|   |-- planner/
|   |   |-- SKILL.md                 # Planning + Codex convergence
|   |   \-- templates/Spec-Format.md
|   |-- generator/
|   |   |-- SKILL.md                 # Implementation loop
|   |   \-- templates/
|   |       |-- Generator-Round-Format.md
|   |       \-- Summary-Format.md
|   \-- evaluator/
|       |-- SKILL.md                 # Evaluation + Codex convergence
|       |-- templates/Evaluator-Round-Format.md
|       \-- strategies/
|           |-- Evaluation-Strategy-ApplePlatform.md
|           |-- Evaluation-Strategy-CLI.md
|           |-- Evaluation-Strategy-Domain.md
|           |-- Evaluation-Strategy-Web.md
|           \-- Evaluation-Strategy-Web-Playwright.md
|-- system-prompts/
|   \-- claude-evaluator.md          # Hardened evaluator system prompt
\-- commands/
    \-- init.md                      # Project initialization
```

## Development Setup (Symlinks)

For local development or contributing, you can symlink the skills directly instead of installing the plugin:

```bash
# Claude Code (user-level)
ln -sf /path/to/TandemKit/skills/planner ~/.claude/skills/planner
ln -sf /path/to/TandemKit/skills/generator ~/.claude/skills/generator
ln -sf /path/to/TandemKit/skills/evaluator ~/.claude/skills/evaluator

# Codex (user-level)
mkdir -p ~/.agents/skills
ln -sf /path/to/TandemKit/skills/planner ~/.agents/skills/planner
ln -sf /path/to/TandemKit/skills/generator ~/.agents/skills/generator
ln -sf /path/to/TandemKit/skills/evaluator ~/.agents/skills/evaluator
```

Note: With symlinks, commands use unprefixed names (`/planner`, `/generator`, `/evaluator`) instead of the plugin-qualified form.

## License

MIT
