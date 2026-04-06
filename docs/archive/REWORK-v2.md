# HarnessKit v2 — Rework Design

> **Archive note:** This documents the pre-release HarnessKit design. The project was renamed to TandemKit for the v1.0 public release.

## Overview

HarnessKit v2 replaces manual dual sessions (Claude + Codex in separate terminals) with a single-session model where Claude orchestrates Codex internally via the `codex-plugin-cc` plugin. Every mission always uses both models — there is no single-model mode.

**User manages 3 sessions:** Planner, Generator, Evaluator.
**Codex runs inside** the Planner and Evaluator sessions via `/codex:rescue`.
**Generator is Claude-only** — it implements, it doesn't need a second opinion.

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
- One Claude Evaluator session (internally maintains one persistent Codex thread)

We do NOT start fresh Codex threads per evaluation round. Context accumulation is valuable — the Codex evaluator builds understanding across rounds just like Claude does. "Fresh eyes" comes from two different models evaluating, not from context amnesia. The skill instructions say "re-verify ALL criteria from scratch" which enforces rigor without discarding useful context.

**Exception:** If a Codex thread becomes clearly confused (repeating nonsensical feedback, losing track of what was fixed) or a major spec/architecture shift happens mid-mission, start a fresh Codex thread for the next cycle. This should be rare.

---

## The Convergence Protocol

Both the Planner and Evaluator use the same back-and-forth pattern with Codex. This is the core of v2.

### How It Works

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

1. **Re-investigate, don't argue from memory.** When Claude or Codex disagrees on a point, they MUST re-read the relevant source files and re-check the facts before responding. This prevents circular disagreements and helps discover who's actually right.

2. **Codex doesn't re-read its own prior files** (session is persistent — it already has that context). Each Codex review just reads the latest Claude-NN.md.

3. **Exception: Codex's first review (Round 2)** — Codex reads both Claude-01.md and Claude-02.md since it hasn't seen Claude's work before.

### Convergence Rule

Codex provides an **Agreement Status** in every review:

- **NOT APPROVED** — has high or medium disagreements. Claude must address these.
- **APPROVED** — only low disagreements remain. Claude reads them, may make editorial adjustments, then finalizes.

There is no fixed iteration limit. In practice, convergence takes 2-4 exchanges.

**Stuck convergence escalation:** If the same high or medium disagreement persists across 3 consecutive Codex reviews (Codex keeps raising it, Claude keeps dismissing it), Claude must stop and present both positions to the user: "Codex and I disagree on [X]. Codex's position: [A]. My position: [B]. Which do you prefer?"

**Post-approval rule:** After Codex marks APPROVED, Claude may only make editorial changes (wording, formatting). Any substantive content change requires one more Codex review pass.

### Severity Levels (used in two contexts)

The same scale is used everywhere, in clearly separated sections:

| Level | In Findings (bugs/issues) | In Agreement (disagreements) |
|-------|--------------------------|------------------------------|
| **High** | Acceptance criterion fails, regression, security issue | Codex strongly disagrees — Claude's assessment is factually wrong or misses a critical issue |
| **Medium** | Non-blocking issue, overclaim, missing edge case | Codex partially disagrees — assessment could be improved or is missing context |
| **Low** | Suggestion, minor wording, style preference | Minor note — acceptable either way |

### Optional Quality Score

Alongside the criterion-by-criterion PASS/FAIL verdicts, evaluators may include a non-gating `qualityScore: 1-10` for trend tracking across rounds. This is informational only — it never determines the verdict. The verdict is always criterion-driven.

---

## Codex Runtime Contract

### Thread Policy

Each role maintains **one persistent Codex thread** for the entire mission:
- **Planner** gets one Codex thread for the entire planning phase
- **Evaluator** gets one Codex thread for ALL evaluation rounds (context accumulates)

First Codex call in a session: `--fresh` (new thread).
All subsequent calls in the same session: `--resume` (continue the thread).

This saves tokens (Codex already has context) and gives Codex continuity across the convergence back-and-forth and across evaluation rounds.

### Parallel Execution Mechanics

For the initial parallel investigation/evaluation (Round 1):

1. Claude launches Codex via the Agent tool with `run_in_background: true` and `/codex:rescue --fresh [prompt]`. Do NOT also use `--background` in the Codex CLI — that creates double-backgrounding where the Agent "completes" but Codex is still running.
2. Claude does its own investigation/evaluation (reads files, verifies, etc.)
3. Claude writes `Claude-01.md`
4. When the background Agent completes, Claude is notified automatically. No polling needed — do NOT use sleep loops or `/codex:status`.
5. Claude saves Codex result to `Codex-01.md`
6. Convergence begins (Round 2+)

For subsequent review rounds (Codex reviews Claude's merged work):

1. Claude writes `Claude-NN.md`
2. Claude invokes Codex in **foreground**: `/codex:rescue --resume [review prompt]`
3. Result saved to `Codex-NN.md`
4. Claude reads and decides next step

### Job + Thread Tracking

Each conversation folder contains a `codex-meta.json`:
```json
{
  "threadId": "<from first /codex:rescue --fresh>",
  "lastJobId": "<from most recent /codex:rescue>",
  "model": "gpt-5.4",
  "effort": "xhigh"
}
```

Updated after each Codex invocation. `lastJobId` is used for `/codex:status` and `/codex:result` polling. `threadId` is audit/debug metadata — `--resume` resumes the last thread in the current Codex session automatically; the stored ID is a fallback for the fresh-with-context approach if `--resume` doesn't work as expected.

### Unavailability

If Codex is unavailable (CLI not installed, auth expired, app-server crash):
- **Block.** Do NOT proceed with Claude-only.
- Tell the user: "Codex is unavailable. Please run `/codex:setup` to fix, then say 'continue'."
- HarnessKit requires both models. There is no single-model fallback.

### Fallback: If --resume Doesn't Work

If we discover that `--resume` doesn't work as expected (session can't be continued), the fallback is:
- Always use `--fresh` for every Codex call
- Include in the prompt: "Read these files for context: [spec], [previous Codex rounds], [previous Claude rounds], [latest Claude draft]"
- This works but costs more tokens and takes longer

Document this as a known risk. Test on first real mission. If `--resume` works, great. If not, switch to the fresh-with-context approach.

### Changed-File Discovery (Evaluator)

The Generator writes a `ChangedFiles-NN.txt` manifest alongside each `Generator/Round-NN.md` report. This lists **all files the Generator created or modified in this round** — derived from `git diff --name-only` against the state at the start of the round. If there are multiple commits within one round, the manifest covers all of them.

```
# Changed files for Round 01 (all files touched by Generator in this round)
.claude/skills/timing-mcp-settings-tool/SKILL.md (created)
.claude/skills/timing-mcp-stats-tools/SKILL.md (created)
```

The evaluator reads this manifest BEFORE starting evaluation. Both Claude and Codex receive it in their prompts. The Generator's `Round-NN.md` prose report is read LAST (to preserve evaluation independence).

---

## Phase 1: Planning

### Session: Planner (Claude, invokes Codex via plugin)

**User is available throughout the planning phase.** Questions can be asked in any round, not just at the start or end. During execution (Generator + Evaluator), work is fully autonomous — the user is not expected to be present.

### Step 0 — Mission Setup

1. User invokes `/planner` (optionally with a goal description)
2. If no goal provided: Claude asks "What do you want to build or do? You can describe it briefly or in detail."
3. User provides the goal
4. Claude reads `HarnessKit/Config.json` — check for active mission, read `nextMissionNumber`
5. Claude reads `HarnessKit/Planner.md` for project-specific context (mandatory — informs name suggestion and Codex prompt)
6. **In a single response:** Claude suggests a PascalCase mission name (AskUserQuestion) AND launches Codex in background with investigation prompt. Codex prompt includes: role context ("You are the Codex companion for the Planner"), instruction to read `HarnessKit/Planner.md`, Spec.md format guidance, and the user's goal.
7. On name confirmation: run `create-mission.sh`, create branch if configured
8. Proceed immediately to Step 1 (suggest session rename alongside investigation start)

**Critical flow:** Goal → Read Planner.md → Name + Launch Codex (parallel) → Create mission → Investigate → Questions after Round 1 only.

### Step 1 — Claude's Independent Investigation (Round 1)

Codex is already running from Step 0.6. Claude investigates independently — no clarifying questions during this step.

9. Claude reads reference documents listed in `HarnessKit/Planner.md` that are relevant to this mission
10. Claude does its own deep investigation (reads codebase, docs, source files)
11. Both focus on: understanding the user's intention, what's affected, what might need to change, and collecting any points of unclarity
12. Claude writes `Planner-Discussion/Claude-01.md` — includes:
    - Investigation findings with file paths
    - Initial plan suggestion (following Spec.md format)
    - **Open Questions** section (anything ambiguous or unclear that needs user input)
13. Claude fetches Codex result → saves to `Planner-Discussion/Codex-01.md`

### Step 2 — User Questions (After Round 1)

14. Claude reads Codex-01.md, collects questions from both
15. If either Claude or Codex has questions: merge them, ask user ONE AT A TIME
16. User answers
17. If no questions: skip straight to convergence

### Step 3 — Convergence (Round 2+)

18. Claude creates merged plan: `Claude-02.md`
    - Incorporates Codex findings it agrees with
    - For disagreements: explains rationale, has re-investigated the source
    - Includes user's answers to questions
    - **Open Questions** section (new questions that arose, if any)

19. Claude invokes Codex (`--resume`) to review Claude-02.md
    - Codex reads Claude-01.md (first time seeing Claude's work) + Claude-02.md
    - Codex re-investigates any points it disagrees on
    - Codex provides agreement feedback with severity levels
    - Codex may also have its own **Open Questions**
    - Result saved to `Codex-02.md`

20. If Codex has new questions OR Claude has new questions: Claude asks user before next round
21. If NOT APPROVED: Claude re-investigates disagreed points, creates `Claude-03.md`, Codex reviews → `Codex-03.md`, etc.
    - From Round 3 onward, Codex only needs to read the latest Claude-NN.md (it has all prior context in its thread)
22. If APPROVED: Claude makes editorial adjustments → final `Claude-NN.md`

**`--resume` fallback:** If `--resume` fails, use `--fresh` and include the full original Codex prompt preamble (role context, HarnessKit/Planner.md, Spec format) plus all prior discussion files as context in the prompt.

### Step 4 — User Approval

23. Claude presents to the user:
    - Summary of what Claude and Codex converged on
    - The FULL Spec.md text in chat (not just a link or summary)
    - Any remaining low-level differences noted
24. User reviews, provides feedback
25. Claude incorporates feedback:
    - **Editorial changes**: apply directly, write `Spec.md`
    - **Substantive changes**: apply, then one more Codex review (`--resume`) before finalizing
26. Write `Spec.md`
27. Optionally ask about committing the spec + mission structure

### Step 5 — Transition to Execution

28. Claude presents execution session prompts:

╔═══ START GENERATOR SESSION ═════════════════════════════════════════╗
```
/rename 🛠️ Generator: NNN-MissionName
```
```
/generator NNN-MissionName
```
╚══════════════════════════════════════════════════════════════════════╝

╔═══ START EVALUATOR SESSION (from project root) ═════════════════════╗
```
claude --append-system-prompt-file HarnessKit/ClaudeEvaluatorPrompt.md
```
╚══════════════════════════════════════════════════════════════════════╝

╔═══ THEN IN THE EVALUATOR SESSION ═══════════════════════════════════╗
```
/rename 🔍 Evaluator: NNN-MissionName
```
```
/evaluator NNN-MissionName
```
╚══════════════════════════════════════════════════════════════════════╝

════════════════════════════════════════
  ✓ Planning Complete — Start Generator and Evaluator sessions
════════════════════════════════════════

### Planner Artifacts

```
HarnessKit/NNN-MissionName/
├── State.json
├── Spec.md                          ← final output
└── Planner-Discussion/
    ├── codex-meta.json              ← Codex thread/job tracking
    ├── Claude-01.md                 ← Claude's investigation + questions
    ├── Codex-01.md                  ← Codex's investigation + questions
    ├── Claude-02.md                 ← merged plan + user answers
    ├── Codex-02.md                  ← review (NOT APPROVED)
    ├── Claude-03.md                 ← revised plan
    ├── Codex-03.md                  ← review (APPROVED)
    └── Claude-04.md                 ← final (→ becomes Spec.md)
```

---

## Phase 2: Generation

### Session: Generator (Claude only)

Mostly unchanged from current HarnessKit. Key flow:

1. Read Config.json, Generator.md, Spec.md
2. Suggest session rename (if not already done)
3. Wait for Evaluator readiness (`evaluatorStatus: "watching"`)
4. Implement milestone by milestone against the spec
5. After each milestone:
   - Write `Generator/Round-NN.md` (report)
   - Write `Generator/ChangedFiles-NN.txt` (machine-readable manifest of created/modified files)
   - Signal evaluator via State.json
6. Wait for evaluation verdict
7. If FAIL: read feedback, fix, next round
8. If PASS: present Review Briefing to user
9. On user approval: ask about committing, write Summary.md

### Generator does NOT use Codex.

### Generator Artifacts

```
HarnessKit/NNN-MissionName/
├── Generator/
│   ├── Round-01.md                  ← prose report
│   ├── ChangedFiles-01.txt          ← machine-readable file list
│   ├── Round-02.md
│   ├── ChangedFiles-02.txt
│   └── ...
└── UserFeedback/
    └── Feedback-01.md (if user gives feedback)
```

---

## Phase 3: Evaluation

### Session: Evaluator (Claude, invokes Codex via plugin)

**Fully autonomous.** The user is NOT expected to be present during evaluation. The evaluator and generator work in a loop until PASS or the user intervenes.

### Step 1 — Setup

1. Read Config.json, Evaluator.md, Spec.md
2. Suggest session rename
3. Signal readiness: `evaluatorStatus: "watching"`
4. Wait for Generator to signal `ready-for-eval`

### Step 2 — Parallel Independent Evaluation (Round 1 of each eval cycle)

5. Read `Generator/ChangedFiles-NN.txt` to get the file list (independent of Generator's prose report)
6. Claude starts its own evaluation (reads generated files, verifies against source code, runs builds/tests per Evaluator.md)
7. **Simultaneously**, Claude launches Codex via Agent tool with `run_in_background: true`:
   - First eval cycle: `/codex:rescue --fresh [eval prompt]`
   - Subsequent cycles: `/codex:rescue --resume [eval prompt]`
   Do NOT use `--background` in Codex CLI (Agent tool handles backgrounding).

The evaluation prompt includes:
- Role context ("You are the Codex companion for the Evaluator")
- Instruction to read `HarnessKit/Evaluator.md` for project-specific context and mandatory checks
- Instruction to read the relevant evaluation strategy (matching mission type from Spec.md AND projectType from Config.json)
- The spec (acceptance criteria)
- The changed files list (from manifest)
- Instruction to verify each criterion with evidence
- Instruction to read Generator's report LAST

8. Claude writes `Evaluator/Round-NN-Discussion/Claude-01.md` — includes:
    - Per-criterion verdicts with evidence
    - Findings classified as high/medium/low
    - Optional qualityScore (1-10, non-gating)
9. When background Codex agent completes (automatic notification), Claude saves result to `Round-NN-Discussion/Codex-01.md`

### Step 3 — Convergence

10. Claude reads Codex findings, creates merged evaluation: `Claude-02.md`
    - Incorporates Codex findings it agrees with
    - For disagreements: re-investigates the source code, explains rationale
11. Codex reviews (`--resume`): reads Claude-01 + Claude-02 (first time seeing Claude's work)
    - Re-investigates disagreed points
    - Provides agreement feedback with severity
    - Result: `Codex-02.md`
12. Continue until APPROVED
    - From Round 3+: Codex only reads latest Claude-NN.md (has prior context)
13. Claude finalizes → copies to `Evaluator/Round-NN.md`

### Step 4 — Signal Generator

14. Update State.json with verdict and round number
15. Print handoff banner

════════════════════════════════════════
  → Verdict: [PASS/FAIL/PASS_WITH_GAPS/BLOCKED] — Waiting for next round
════════════════════════════════════════

16. **Immediately re-enter watching** for next round or mission completion
17. When next round arrives: back to Step 2

### Evaluator Artifacts

```
HarnessKit/NNN-MissionName/
├── Evaluator/
│   ├── codex-meta.json              ← Codex thread/job tracking (shared across rounds)
│   ├── Round-01.md                  ← final evaluation (for Generator)
│   ├── Round-01-Discussion/
│   │   ├── Claude-01.md             ← Claude's initial eval
│   │   ├── Codex-01.md              ← Codex's initial eval
│   │   ├── Claude-02.md             ← merged eval
│   │   ├── Codex-02.md              ← review (APPROVED)
│   │   └── Claude-03.md             ← final (→ copied to Round-01.md)
│   ├── Round-02.md
│   ├── Round-02-Discussion/
│   │   └── ...
│   └── ...
```

---

## State.json (Round-Aware)

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

No `evaluationMode` flag — it's ALWAYS dual (Claude + Codex).

### Round-Aware Waiting

To prevent stale-signal false triggers (the Mission 002 bug), waits use exact round matching:

- Generator signals ready: sets `round: N`, `generatorStatus: "ready-for-eval"`
- Evaluator waits: `wait-for-state.sh ... generatorStatus ready-for-eval --round N`
- The script only returns READY if the field matches AND `round` equals N exactly

Implementation: add `--round N` parameter to `wait-for-state.sh`. Exact match, not `>=`.

### State Transition Table

| Who | When | Sets |
|---|---|---|
| **Planner** | After spec approved, before showing execution prompts | `phase: "ready-for-execution"` |
| **Generator** | On start, evaluator not ready yet | `generatorStatus: "researching"` |
| **Generator** | Evaluator is ready, starting implementation | `generatorStatus: "working"`, `phase: "generation"` |
| **Generator** | Milestone done, signaling evaluator | `generatorStatus: "ready-for-eval"`, `evaluatorStatus: "pending"`, `phase: "evaluation"`, `round: N` |
| **Generator** | Processing user feedback | `generatorStatus: "working"`, `phase: "generation"` (do NOT set evaluatorStatus) |
| **Generator** | Presenting Review Briefing | `phase: "user-review"`, `generatorStatus: "awaiting-user"` |
| **Generator** | Mission complete | `phase: "complete"`, `completedBy: "user"` |
| **Evaluator** | Setup done, ready to watch | `evaluatorStatus: "watching"` |
| **Evaluator** | Starting evaluation | `evaluatorStatus: "evaluating"` |
| **Evaluator** | Evaluation complete | `evaluatorStatus: "done"`, `verdict: "..."` |

---

## User Guidance / UX Flow

### Starting a Mission

The user starts by running `/planner` in a Claude Code session:

```
> /planner I want to add a debug activity creation tool for testing
```

Or without a goal:
```
> /planner
```
→ Claude asks: "What do you want to build or do? You can describe it briefly or in detail."

### During Planning

The user stays in the Planner session. They'll be asked questions between rounds if anything is unclear. They review the final spec draft and approve or give feedback. The planning phase is **interactive**.

### Starting Execution

After spec approval, the Planner shows copy-paste commands for:
1. Generator session (rename + skill invocation)
2. Evaluator session (with hardened system prompt + rename + skill invocation)

The user starts both sessions and then can step away. Execution is **autonomous**.

### During Execution

The user doesn't need to be present. Generator and Evaluator loop autonomously:
- Generator implements → signals Evaluator
- Evaluator (Claude + Codex) evaluates → sends feedback
- Generator fixes → next round
- Until PASS

### Mission Completion

When the Evaluator issues PASS, the Generator presents a Review Briefing to the user and asks about committing. The user reviews, approves, and the mission is complete.

---

## Complete Sample File Tree (Theoretical Mission)

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
    │   ├── codex-meta.json
    │   ├── Claude-01.md             ← investigation + questions
    │   ├── Codex-01.md              ← investigation + questions
    │   ├── Claude-02.md             ← merged plan + user answers
    │   ├── Codex-02.md              ← review (NOT APPROVED - 1 high)
    │   ├── Claude-03.md             ← revised plan
    │   ├── Codex-03.md              ← review (APPROVED)
    │   └── Claude-04.md             ← final draft (→ Spec.md)
    │
    ├── Generator/
    │   ├── Round-01.md              ← "implemented data model + tool"
    │   ├── ChangedFiles-01.txt      ← file manifest
    │   ├── Round-02.md              ← "fixed validation + tests"
    │   └── ChangedFiles-02.txt
    │
    ├── Evaluator/
    │   ├── codex-meta.json          ← shared Codex thread across rounds
    │   │
    │   ├── Round-01.md              ← FAIL (2 high findings)
    │   ├── Round-01-Discussion/
    │   │   ├── Claude-01.md         ← Claude's eval
    │   │   ├── Codex-01.md          ← Codex's eval
    │   │   ├── Claude-02.md         ← merged (Codex found extra issue)
    │   │   ├── Codex-02.md          ← APPROVED
    │   │   └── Claude-03.md         ← final (→ Round-01.md)
    │   │
    │   ├── Round-02.md              ← PASS
    │   └── Round-02-Discussion/
    │       ├── Claude-01.md
    │       ├── Codex-01.md
    │       ├── Claude-02.md
    │       ├── Codex-02.md          ← APPROVED
    │       └── Claude-03.md         ← final (→ Round-02.md)
    │
    └── UserFeedback/
        └── Feedback-01.md           ← (if user gave feedback after PASS)
```

---

## What Gets Deleted (v1 → v2)

| File/Concept | Why |
|---|---|
| `scripts/wait-for-turn.sh` | No separate sessions to coordinate |
| `scripts/signal-step.sh` | No dual-session status files |
| `scripts/render-secondary-prompt.sh` | No manual Codex B prompts |
| `protocol/Dual-Session-Protocol.md` | Replaced by Convergence Protocol |
| `Status-A.json`, `Status-B.json`, `Coordination.json` | No dual-session coordination |
| Dual-session sections in all SKILL.md files | Replaced by Codex plugin integration |
| `create-mission.sh` dual mode | Simplified (no dual arg) |
| All rename/prompt choreography for Codex B | No separate Codex sessions |

## What Stays

| File/Concept | Why |
|---|---|
| `scripts/wait-for-state.sh` | Generator↔Evaluator coordination (enhanced with `--round`) |
| `scripts/create-mission.sh` | Creates mission folder + State.json (simplified) |
| `State.json` | Cross-session coordination |
| Mission folder structure | Audit trail |
| Project-specific role files | Deep project context |
| Evaluator system prompt | Hardened evaluation independence |
| Evaluation strategies (Apple, CLI, Web, Domain) | Per-project-type verification |
| Templates (Spec-Format, Summary-Format, Round-Format) | Standardized output |
| Visual handoff banners | UX consistency |
| Commit policy (always ask) | Battle-tested |
| Readiness gate (evaluator signals "watching") | Prevents premature Generator start |

## What's New

| Addition | Purpose |
|---|---|
| Convergence Protocol | Claude↔Codex back-and-forth with severity-based approval |
| Codex via `/codex:rescue` | Replaces manual Codex sessions |
| `Claude-NN.md` / `Codex-NN.md` naming | Clear authorship |
| Agreement Status (APPROVED/NOT APPROVED) | Mechanical convergence signal |
| Re-investigation rule | Prevents circular disagreements |
| Questions in every planning round | User available throughout planning |
| `ChangedFiles-NN.txt` manifest | Machine-readable changed-file list from Generator |
| `codex-meta.json` | Thread/job tracking for `--resume` |
| `--round N` in wait-for-state.sh | Exact round matching prevents stale signals |
| File reading limits | Prevent subagent hangs |
| Optional qualityScore (1-10) | Non-gating trend tracking |
| `-Discussion/` folders | Clear naming for inner Claude↔Codex convergence |

---

## File Reading Limits (All Skills)

Added to all three SKILL.md files:

```
## File Reading Limits

- **Max 5 files per parallel Read batch** — if more needed, read in sequential batches
- **Use Glob/Grep before Read** — identify relevant files first
- **Large files (>300 lines)** — read only relevant sections using offset/limit
- **Batch edits** — max 5 parallel Write/Edit operations per batch
```

---

## Design Decisions Log

### Why NOT fresh Codex threads per evaluation round

Considered: starting a fresh Codex thread for each evaluation round to preserve "fresh eyes."

Rejected because:
- Context accumulation is valuable — by Round 6, Codex knows the codebase and past issues
- "Fresh eyes" comes from two different models, not context amnesia
- The skill instruction "re-verify ALL criteria from scratch" enforces rigor without discarding context
- 30 fresh threads for 30 rounds = massive token waste from re-reading spec + source files each time
- The re-investigation rule (re-check facts when disagreeing) prevents lazy anchoring

### Why NOT solo-Claude fallback

HarnessKit requires both models. If Codex is unavailable, the session blocks. Rationale: the entire value proposition is multi-model verification. Solo Claude with no Codex is just regular Claude Code.

### Why NOT numeric score as pass gate

Scores (1-10) can hide criterion failures behind a good average. A score of 8/10 could mean 2 criteria completely failed. Criterion-by-criterion gating is fundamentally safer. The optional qualityScore is for trend tracking only.

### Why Generator doesn't use Codex

The Generator implements against a spec. Implementation correctness is verified by the Evaluator (with Codex). Adding Codex to the Generator would double the cost of every implementation round for marginal benefit — the same issues will be caught during evaluation.

---

## Migration: v1 → v2

### Prerequisites
1. Install `codex-plugin-cc` in Claude Code
2. Verify Codex CLI is authenticated (`/codex:setup`)

### File Changes

| File | Action |
|---|---|
| `skills/planner/SKILL.md` | **Rewrite** — Convergence Protocol, questions every round, Codex integration |
| `skills/evaluator/SKILL.md` | **Rewrite** — Convergence Protocol, Codex integration, Discussion folders |
| `skills/generator/SKILL.md` | **Simplify** — add ChangedFiles manifest, remove dual references |
| `scripts/wait-for-turn.sh` | **Delete** |
| `scripts/signal-step.sh` | **Delete** |
| `scripts/render-secondary-prompt.sh` | **Delete** |
| `protocol/` | **Delete** (entire directory) |
| `scripts/create-mission.sh` | **Simplify** — remove dual mode |
| `scripts/wait-for-state.sh` | **Enhance** — add `--round N` for exact round matching |
| `system-prompts/claude-evaluator.md` | **Keep** |
| `DESIGN.md` | **Rewrite** for v2 |
| `README.md` | **Rewrite** for v2 |

### Symlink Changes
- User-level Claude symlinks (`~/.claude/skills/`) — unchanged
- User-level Codex symlinks (`~/.codex/skills/`) — keep for now, may not be needed (Codex runs via plugin)
- Project-level `.agents/skills/` — keep for now

---

## Open Design Questions

1. **Codex prompt refinement**: The prompts need iteration based on real usage. Codex may need more/less context, different structure.

2. **Codex timeout handling**: If the background Codex Agent times out, retry once. If it times out again, tell the user to run `/codex:setup`. Do NOT proceed without Codex.

3. **`--resume` viability**: Needs testing on first real mission. If it doesn't work as expected, fall back to `--fresh` with full context in every prompt (costs more tokens but functionally equivalent).
