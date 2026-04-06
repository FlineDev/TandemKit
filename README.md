# HarnessKit

Multi-session Planner/Generator/Evaluator orchestration for Claude Code with Codex as a built-in second opinion.

**Status:** v2, battle-tested across 3 missions (2026-04-06)

## Documentation Contract

| File | Authority |
|---|---|
| **This README** | Overview, motivation, architecture, key concepts, design rationale |
| **skills/\*/SKILL.md** | Exact runtime behavior and protocol steps |
| **templates/** and **strategies/** | Output format and evaluation contracts |

The SKILL.md files are what Claude actually reads and follows at runtime. This README is the human-readable overview for understanding how and why things work.

---

## How It Works

Three Claude Code sessions collaborate on a mission. The Planner and Evaluator internally invoke Codex via the `codex-plugin-cc` plugin for independent verification. The Generator implements alone.

```
USER
  │
  ├─→ Planner Session (Claude + Codex internally)
  │     └─→ produces Spec.md
  │
  ├─→ Generator Session (Claude only)
  │     └─→ implements against Spec.md, commits at milestones
  │
  └─→ Evaluator Session (Claude + Codex internally)
        └─→ verifies against Spec.md, provides feedback to Generator
```

**Three persistent contexts for the entire mission:**
- One Claude Planner session (done after spec approval)
- One Claude Generator session
- One Claude Evaluator session (maintains one persistent Codex thread across all rounds)

No fresh Codex threads per evaluation round — context accumulation is valuable. "Fresh eyes" comes from two different models evaluating, not from context amnesia. The skill instructions enforce rigor via "re-verify ALL criteria from scratch."

---

## Mission Lifecycle

```
/planner → investigation → Codex convergence → user approval → Spec.md
                                                                   ↓
/generator → implement milestone → signal evaluator ──────────────→↓
                ↑                                                  ↓
                └──── fix ←── FAIL ←── evaluation ←── /evaluator ←─┘
                                          ↓
                                       PASS → Review Briefing → user approval → done
```

### UX Flow

1. **Planning (interactive):** User runs `/planner`, describes the goal. Claude and Codex investigate in parallel, converge on a spec, ask questions between rounds. User approves the final Spec.md.

2. **Execution (autonomous):** User starts Generator and Evaluator sessions (Planner shows the exact commands). Generator implements against the spec, Evaluator (with Codex) verifies. They loop until PASS. The user doesn't need to be present.

3. **Completion:** On PASS, the Generator presents a Review Briefing. User reviews, approves, and the mission is complete.

---

## The Convergence Protocol

Both the Planner and Evaluator use the same back-and-forth pattern with Codex. This is the core mechanism.

```
    ROUND 1 (parallel)
    ───────────────────
    Claude investigates          Codex investigates (background)
           │                              │
           ▼                              ▼
      Claude-01.md                   Codex-01.md
           │                              │
           └────── Claude reads Codex-01 ─┘
                        │
                        ▼
    ROUND 2
    ───────
    Claude creates merged/improved version
    (incorporates what it agrees with from Codex,
     explains disagreements with rationale)
                        │
                        ▼
                   Claude-02.md
                        │
              Codex reads Claude-01 + Claude-02
              (first time seeing Claude's work)
              Re-investigates any disagreed points
                        │
                        ▼
                   Codex-02.md  (agreement feedback with severity)
                        │
    ROUND 3+
    ────────
    Claude reads Codex feedback
    Re-investigates disagreed points (re-reads source, re-checks facts)
    Creates improved version
                        │
                        ▼
                   Claude-03.md
                        │
              Codex reads Claude-03 (already has prior context)
              Re-investigates remaining disagreements
                        │
                        ▼
                   Codex-03.md  (only low disagreements → APPROVED)
                        │
              Claude reads low feedback, makes editorial adjustments
                        │
                        ▼
                   Claude-04.md  (FINAL — copied to output location)
```

### Key Rules

1. **Re-investigate, don't argue from memory.** When Claude or Codex disagrees, they MUST re-read the relevant source files before responding. Prevents circular disagreements.

2. **Codex doesn't re-read its own prior files** — session is persistent, it already has that context. Each review just reads the latest Claude-NN.md.

3. **Exception: Round 2** — Codex reads both Claude-01.md and Claude-02.md (first time seeing Claude's work).

4. **Stuck escalation:** If the same disagreement persists across 3 rounds, present both positions to the user and let them decide.

### Severity Levels

The same scale is used for both findings (bugs/issues) and agreement (disagreements):

| Level | In Findings | In Agreement |
|---|---|---|
| **High** | Acceptance criterion fails, regression, security issue | Claude's assessment is factually wrong or misses a critical issue |
| **Medium** | Non-blocking issue, overclaim, missing edge case | Assessment could be improved or is missing context |
| **Low** | Suggestion, minor wording, style | Minor note — acceptable either way |

**Convergence gate:** APPROVED when no high or medium disagreements remain. There is no fixed iteration limit — in practice, convergence takes 2-4 exchanges.

---

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

### State Transitions

| Who | When | Sets |
|---|---|---|
| **Planner** | Spec approved | `phase: "ready-for-execution"` |
| **Generator** | Starting, evaluator not ready | `generatorStatus: "researching"` |
| **Generator** | Evaluator ready, implementing | `generatorStatus: "working"`, `phase: "generation"` |
| **Generator** | Milestone done, signaling | `generatorStatus: "ready-for-eval"`, `phase: "evaluation"`, `round: N` |
| **Generator** | Mission complete | `phase: "complete"` |
| **Evaluator** | Ready to watch | `evaluatorStatus: "watching"` |
| **Evaluator** | Evaluating | `evaluatorStatus: "evaluating"` |
| **Evaluator** | Done with verdict | `evaluatorStatus: "done"`, `verdict: "..."` |

### Round-Aware Waiting

To prevent stale-signal false triggers, `wait-for-state.sh` supports exact round matching via `--round N`. The script only returns READY if the field matches AND `round` equals N exactly.

---

## Codex Integration

Codex is invoked via the `codex-plugin-cc` plugin's `/codex:rescue` command. Key mechanics:

- **Backgrounding:** Launch via Agent tool with `run_in_background: true`. Do NOT also use `--background` in the Codex CLI — that creates double-backgrounding. Claude is notified automatically when the Agent completes.
- **Thread persistence:** First call uses `--fresh`, subsequent calls use `--resume` to continue the same thread.
- **Fallback:** If `--resume` fails, use `--fresh` with all prior discussion files as context in the prompt.
- **Unavailability:** If Codex is unavailable, the session blocks. No single-model fallback — the entire value proposition is multi-model verification.

---

## Sample Mission File Tree

```
HarnessKit/
├── Config.json
├── Planner.md                       ← project-specific planner context
├── Generator.md                     ← project-specific generator context
├── Evaluator.md                     ← project-specific evaluator context
├── ClaudeEvaluatorPrompt.md         ← hardened system prompt
│
└── 003-DebugActivityTool/
    ├── State.json
    ├── Spec.md                      ← approved spec
    ├── Summary.md                   ← written at mission completion
    │
    ├── Planner-Discussion/
    │   ├── Claude-01.md             ← investigation + questions
    │   ├── Codex-01.md              ← investigation + questions
    │   ├── Claude-02.md             ← merged plan + user answers
    │   ├── Codex-02.md              ← review (NOT APPROVED - 1 high)
    │   ├── Claude-03.md             ← revised plan
    │   ├── Codex-03.md              ← review (APPROVED)
    │   └── Claude-04.md             ← final draft (→ Spec.md)
    │
    ├── Generator/
    │   ├── Round-01.md              ← prose report
    │   ├── ChangedFiles-01.txt      ← machine-readable file manifest
    │   ├── Round-02.md
    │   └── ChangedFiles-02.txt
    │
    ├── Evaluator/
    │   ├── Round-01.md              ← FAIL (2 high findings)
    │   ├── Round-01-Discussion/
    │   │   ├── Claude-01.md         ← Claude's eval
    │   │   ├── Codex-01.md          ← Codex's eval
    │   │   ├── Claude-02.md         ← merged eval
    │   │   ├── Codex-02.md          ← APPROVED
    │   │   └── Claude-03.md         ← final (→ Round-01.md)
    │   │
    │   ├── Round-02.md              ← PASS
    │   └── Round-02-Discussion/
    │       └── ...
    │
    └── UserFeedback/
        └── Feedback-01.md           ← (if user gave feedback after PASS)
```

---

## Design Decisions

### Why always dual-model (Claude + Codex)

There is no single-model mode. Different models catch different things — Codex found real bugs that Claude missed in early missions. If Codex is unavailable, the session blocks until it's fixed. Solo Claude without Codex is just regular Claude Code.

### Why NOT fresh Codex threads per evaluation round

Context accumulation is valuable — by Round 6, Codex knows the codebase and past issues. "Fresh eyes" comes from two different models, not context amnesia. The re-investigation rule prevents lazy anchoring. Starting fresh threads for every round would be massive token waste.

### Why severity-based convergence, not numeric scores

Scores (1-10) can hide criterion failures behind a good average. A score of 8/10 could mean 2 criteria completely failed. Criterion-by-criterion PASS/FAIL with severity-based agreement is fundamentally safer. An optional non-gating qualityScore (1-10) is available for trend tracking.

### Why Generator doesn't use Codex

The Generator implements against a spec. Implementation correctness is verified by the Evaluator (with Codex). Adding Codex to the Generator would double the cost of every implementation round for marginal benefit — the same issues will be caught during evaluation.

### Why Codex runs inside Claude sessions

v1 used manual dual sessions (Claude + Codex in separate terminals). This was fragile — Codex sessions stopped watching, dropped protocol, needed manual user intervention. v2 uses the `codex-plugin-cc` plugin so Claude invokes Codex within the same session, keeping control of the flow.

---

## Project Structure

```
HarnessKit/
├── scripts/
│   ├── create-mission.sh            # Scaffold new mission folder
│   └── wait-for-state.sh            # Generator↔Evaluator coordination
├── skills/
│   ├── planner/
│   │   ├── SKILL.md                 # Planning + Codex convergence
│   │   └── templates/Spec-Format.md
│   ├── generator/
│   │   ├── SKILL.md                 # Implementation loop
│   │   └── templates/
│   │       ├── Generator-Round-Format.md
│   │       └── Summary-Format.md
│   └── evaluator/
│       ├── SKILL.md                 # Evaluation + Codex convergence
│       ├── templates/Evaluator-Round-Format.md
│       └── strategies/
│           ├── Evaluation-Strategy-ApplePlatform.md
│           ├── Evaluation-Strategy-CLI.md
│           ├── Evaluation-Strategy-Domain.md
│           └── Evaluation-Strategy-Web.md
├── system-prompts/
│   └── claude-evaluator.md          # Hardened evaluator system prompt
└── commands/
    └── init.md                      # Project initialization (plugin distribution)
```

## Prerequisites

- Claude Code with the `codex-plugin-cc` plugin installed
- Codex CLI authenticated (`/codex:setup` to verify)
- HarnessKit initialized in the project (`/harness-kit-init` or manual symlinks)

## Quick Start

```bash
# 1. Start a Planner session
/planner Add JWT authentication with refresh tokens

# 2. After spec is approved, start Generator and Evaluator
#    (Planner shows the exact commands to copy)

# 3. Generator and Evaluator work autonomously until PASS
#    User reviews the final result
```

## Development Setup (Symlinks)

For local development, symlink the skills directly:

```bash
# Claude Code (user-level — works in all projects)
ln -sf /path/to/HarnessKit/skills/planner ~/.claude/skills/planner
ln -sf /path/to/HarnessKit/skills/generator ~/.claude/skills/generator
ln -sf /path/to/HarnessKit/skills/evaluator ~/.claude/skills/evaluator

# Codex (user-level)
mkdir -p ~/.agents/skills
ln -sf /path/to/HarnessKit/skills/planner ~/.agents/skills/planner
ln -sf /path/to/HarnessKit/skills/generator ~/.agents/skills/generator
ln -sf /path/to/HarnessKit/skills/evaluator ~/.agents/skills/evaluator
```

## History

- **v1** (March 2026): Manual dual sessions — Claude A + Codex B in separate terminals with file-based coordination. Fragile: Codex stopped watching, dropped protocol, needed user intervention.
- **v2** (April 2026): Codex plugin integration. Single sessions with internal Codex invocation via `codex-plugin-cc`. Convergence Protocol replaces dual-session protocol. Battle-tested across 3 missions.

## License

MIT
