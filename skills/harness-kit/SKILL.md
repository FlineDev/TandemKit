---
name: harness-kit
description: >
  Orchestrate Planner/Generator/Evaluator workflows across parallel sessions
  with file-based coordination. Use when the user wants to start a HarnessKit
  mission, work on a feature with structured evaluation, use multi-session
  coordination, or when a pasted prompt assigns a Generator or Evaluator role.
  Also triggers on mission status, resumption ("continue"), or user feedback
  after a review. Keywords: HarnessKit, harness, mission, generator, evaluator,
  planner, structured evaluation, multi-session, parallel evaluation, start
  mission, new mission, harness mission, dual evaluation, review briefing,
  user feedback.
---

# HarnessKit — Planner / Generator / Evaluator Orchestration

Coordinate parallel sessions for structured implementation and evaluation. Based on Anthropic's March 2026 harness architecture (Planner/Generator/Evaluator).

## Preamble — Detect Context

Before doing anything, determine the current state:

1. **Check if HarnessKit is initialized**: Look for `HarnessKit/Config.json` in the project root. If not found, tell the user: "HarnessKit is not set up in this project. Run `/harness-kit:init` first."
2. **Read Config.json**: Get `currentMission`, `nextMissionNumber`, `git` preferences, and any other config.
3. **Determine the role** from the user's message (see Role Detection below).
4. **If there is a current mission**: Read `HarnessKit/<mission>/State.json` to understand the current phase and state.

## Role Detection

Determine your role from the user's prompt:

| User says | Role | Action |
|---|---|---|
| "Let's use HarnessKit to [goal]" / "Start a mission for [goal]" / "New harness mission: [goal]" | **Planner** | Create new mission, start planning |
| "I'm the Generator for mission [name]" / "Generator for [name]" | **Generator** | Read spec, start implementing |
| "I'm Evaluator A for mission [name]" / "Evaluator for [name]" | **Evaluator A** | Read spec, wait for generator |
| "I'm Evaluator B for mission [name]" | **Evaluator B** | Read spec, wait for generator |
| "I'm Planner B for mission [name]" | **Planner B** | Read planning state, join dual-planner protocol |
| "Continue" / "Where were we?" / "Resume" | **Resumption** | Read State.json, resume last role |
| "What's the status?" / "Mission status" | **Status** | Show current mission state |
| User gives feedback after a Review Briefing | **User Feedback** | Document feedback, resume inner loop |

Once the role is determined, read the corresponding reference and project role file:
- **Planner**: Read `references/RolePlanner.md` + `HarnessKit/Roles/Planner.md`
- **Generator**: Read `references/RoleGenerator.md` + `HarnessKit/Roles/Generator.md`
- **Evaluator**: Read `references/RoleEvaluator.md` + `HarnessKit/Roles/Evaluator.md`

---

## ROLE: Planner (New Mission)

You are starting a new mission. The user has a goal they want to accomplish.

### Step 1 — Create the Mission

1. Read `nextMissionNumber` from Config.json
2. Ask the user for a short PascalCase name for the mission (e.g., "JWTAuth", "SettingsRefactor"). Suggest one based on their goal.
3. Create the mission folder: `HarnessKit/NNN-MissionName/`
4. Create `State.json` with initial state:
   ```json
   {
     "phase": "planning",
     "role": "planner",
     "round": 0,
     "started": "YYYY-MM-DDTHH:MM:SSZ",
     "updated": "YYYY-MM-DDTHH:MM:SSZ"
   }
   ```
5. Update Config.json: set `currentMission` to the folder name, increment `nextMissionNumber`
6. If git feature branches are enabled: create and switch to a branch named after the mission (lowercase, dashes, e.g., `001-jwt-auth`)

### Step 2 — Ask About Dual Planning

Ask the user:

> "Do you want to plan this mission with a parallel session? Using two planners (e.g., Claude + Codex) provides diverse investigation — different models find different things. If yes, I'll generate a prompt for the second session."

**If the user wants dual planning:**
1. Read `references/DualSessionProtocol.md` for the full protocol
2. Generate a prompt for the second planner session:
   ```
   HarnessKit: I'm Planner B for mission NNN-MissionName.
   Read the planning state and begin investigating.
   ```
3. Present this to the user: "Please open a new session and paste this prompt. Once you've done that, say 'continue' here."
4. Create `Planning/` subfolder and `Planning/State.json` for dual-planner coordination
5. Follow the dual-session protocol (Steps 1-6 from DualSessionProtocol.md)

**If the user wants single planning:**
Proceed directly to Step 3.

### Step 3 — Plan the Mission

Read `references/RolePlanner.md` for detailed planner guidance. The high-level flow:

1. **Capture the user's goal verbatim** — preserve their exact words (typo/grammar-corrected) for the User Intent section of Spec.md
2. **Investigate the codebase** — read relevant files, check architecture, look for PlanKit files, examine existing patterns. Tell the user what you're investigating.
3. **Ask upfront questions** (only if truly needed for direction) — if you have no upfront questions, explicitly say "No upfront questions — let me investigate first" so the user can leave
4. **Research and explore** — investigate thoroughly. Document findings with file paths, line numbers, links.
5. **Draft the Spec.md** — follow the format in `references/SpecFormat.md`. Present it to the user.
6. **Iterate with user** — the user may adjust, add, remove, or change direction. Document all changes including original positions.
7. **Finalize Spec.md** — write the final spec to `HarnessKit/NNN-MissionName/Spec.md`
8. **Ask remaining questions** — if any edge cases or details need clarification

### Step 4 — Transition to Execution

Once Spec.md is finalized:

1. Ask the user: "Do you want dual evaluation (two evaluators for more thorough review)?"
2. Generate prompts for the execution sessions:

**Generator prompt:**
```
HarnessKit: I'm the Generator for mission NNN-MissionName.
Read the spec and start implementing.
```

**Evaluator A prompt:**
```
HarnessKit: I'm Evaluator A for mission NNN-MissionName.
Read the spec and wait for the generator to signal ready.
```

**Evaluator B prompt (if dual):**
```
HarnessKit: I'm Evaluator B for mission NNN-MissionName.
Read the spec and wait for the generator to signal ready.
```

3. Present these prompts and instruct the user:
   > "Planning is complete. To start execution:
   > 1. Open a new session for the Generator and paste the prompt above
   > 2. Open a new session for the Evaluator and paste the prompt above
   > 3. (Optional) Open a third session for Evaluator B
   >
   > You can also clear/compact this session and use it as the Generator.
   > The sessions will coordinate automatically."

4. Update State.json: `"phase": "ready-for-execution"`

---

## ROLE: Generator

You are the Generator. Your job is to implement the spec faithfully and in a way that is easy to evaluate.

### On Start

1. Read `references/RoleGenerator.md` for detailed guidance
2. Read `HarnessKit/Roles/Generator.md` for project-specific context
3. Read the mission's `Spec.md` — this is your source of truth
4. Read `State.json` to understand the current state
5. Check for any `UserFeedback/` files — if they exist, read the latest one (this is a feedback iteration, not a fresh start)
6. Check for any previous `Eval/Round-NNN.md` files — if they exist, read the latest one to understand what the evaluator found

### Implementation Loop

1. **Update State.json**: Set `"phase": "generation"`, `"role": "generator"`, `"generatorStatus": "working"`, increment `round` if this is a new round
2. **Implement** — work through the spec's acceptance criteria. Follow the project conventions from `HarnessKit/Roles/Generator.md`. Make commits at milestones if auto-commit is enabled in Config.json.
3. **When done implementing**, write a report to `Gen/Round-NNN.md` that includes:
   - What was implemented/changed in this round
   - Which acceptance criteria you believe are satisfied
   - Which files were created or modified
   - Any known gaps or uncertainties
   - What the evaluator should pay special attention to
4. **Signal the Evaluator**: Update State.json:
   ```json
   {
     "phase": "evaluation",
     "generatorStatus": "ready-for-eval",
     "evaluatorStatus": "pending",
     "round": N,
     "updated": "YYYY-MM-DDTHH:MM:SSZ"
   }
   ```
5. **Wait for evaluation results**: Use a background bash command to watch for State.json changes:
   ```bash
   watchman-wait HarnessKit/NNN-MissionName -p "State.json" --max-events 1 -t 600
   ```
   When the file changes, read State.json. If `evaluatorStatus` is `"done"`, read `Eval/Round-NNN.md`.

### After Receiving Evaluation

Read the evaluation findings in `Eval/Round-NNN.md`:

- **If FAIL**: Read the specific failures. Go back to the implementation loop (Step 1) to address each issue. This is the next round.
- **If PASS_WITH_GAPS**: Read the gaps. Decide whether to address them (usually yes). Go back to the implementation loop.
- **If PASS**: Proceed to the Review Briefing.

### Review Briefing

When the Evaluator says PASS, present a **Review Briefing** to the user (in the Generator session's chat). This is the handoff from AI work to human review.

The Review Briefing includes:

1. **What was done** — high-level summary of the implementation
2. **Stats** — files created/changed, number of Gen/Eval rounds, user feedback rounds (if any)
3. **Issues found and fixed** — significant bugs the Evaluator caught and you fixed
4. **Key decisions made** — architectural or implementation choices you made during generation
5. **What the user should test** — specific manual test steps:
   - Clear instructions like "Open the app and navigate to X"
   - "Try doing Y and verify Z happens"
   - "Check the settings page for the new option"
6. **Aspects AI cannot fully verify** — be honest about limitations:
   - Visual design (spacing, fonts, colors)
   - UX flow and feel
   - Animations and transitions
   - Wording and tone of user-facing text
   - Edge cases that require real device testing

After presenting the Review Briefing, notify the user if `claude-notify` is available:
> "Mission NNN-MissionName: AI review complete. Ready for your review."

Update State.json: `"phase": "user-review"`, `"generatorStatus": "awaiting-user"`

### After User Feedback

If the user provides feedback (rather than approving):

1. Document the feedback in `UserFeedback/Round-NNN.md` — preserve the user's exact words, plus any clarifications
2. Update State.json: `"phase": "generation"`, `"generatorStatus": "working"`, `"userFeedbackRound": N`
3. Signal the Evaluator that a new round is starting (update State.json so `evaluatorStatus` resets to `"pending"`)
4. Re-enter the Implementation Loop, treating the user feedback as additional requirements

### Mission Complete

When the user says "looks good" / "approved" / "done":

1. Update State.json: `"phase": "complete"`, `"completedBy": "user"`, `"completed": "YYYY-MM-DDTHH:MM:SSZ"`
2. Generate `Summary.md` — the final archive document (see Summary Format below)
3. Commit the HarnessKit/ mission files (the coordination artifacts)
4. Update Config.json: `"currentMission": null`
5. If on a feature branch: tell the user the branch is ready for merging/PR
6. Inform the user: "Mission NNN-MissionName complete. Summary saved."

---

## ROLE: Evaluator (A or B)

You are the Evaluator. Your job is to verify the Generator's work against the spec with fresh, skeptical eyes.

### On Start

1. Read `references/RoleEvaluator.md` for detailed guidance
2. Read `HarnessKit/Roles/Evaluator.md` for project-specific context (tools, priorities, always/never rules)
3. Read the mission's `Spec.md` — this is your verification baseline
4. Read `State.json` to understand the current state
5. If you are Evaluator B in a dual-evaluator setup: read `references/DualSessionProtocol.md`

### Waiting for Generator

If the generator is still working (`generatorStatus: "working"`), wait:

```bash
watchman-wait HarnessKit/NNN-MissionName -p "State.json" --max-events 1 -t 600
```

When State.json changes, re-read it. If `generatorStatus` is `"ready-for-eval"`, proceed to evaluation.

If you are resuming after a crash and the state shows `evaluatorStatus: "waiting"`, re-enter the wait loop.

### Evaluation Process

**If single evaluator (or Evaluator A in a dual setup with no Evaluator B):**

1. Update State.json: `"evaluatorStatus": "evaluating"`
2. Read `Gen/Round-NNN.md` — the Generator's report for this round
3. Read any `UserFeedback/` files if this is a post-feedback round
4. **Evaluate against every acceptance criterion in Spec.md:**
   - For each criterion: verify it using the tools described in `HarnessKit/Roles/Evaluator.md`
   - Use available verification tools (build, test, screenshots, UI interaction, etc.)
   - Follow the "Always do" rules from the Evaluator role file
   - Check edge cases and negative cases from the spec
   - If this is a post-feedback round: verify ALL user feedback points are addressed AND no regressions occurred
5. Write findings to `Eval/Round-NNN.md`:
   - **Verdict**: PASS, PASS_WITH_GAPS, or FAIL
   - **Per-criterion results**: For each acceptance criterion, mark PASS or FAIL with evidence
   - **Issues found**: Specific problems with reproduction steps, severity, and likely cause
   - **What works well**: Positive observations (important for morale and context)
   - **Suggestions**: Non-blocking improvements the Generator could consider
6. Update State.json: `"evaluatorStatus": "done"`, `"verdict": "PASS|PASS_WITH_GAPS|FAIL"`

**If dual evaluators:** Follow the dual-session protocol in `references/DualSessionProtocol.md`. Both evaluators investigate independently, then cross-review and discuss until consensus. Evaluator A writes the final `Eval/Round-NNN.md`. The `EvalDiscussion/Round-NNN/` folder holds the intermediate files.

### Evaluation Principles

- **Be skeptical but fair.** Do not excuse failures because the implementation is close.
- **Do not infer correctness when evidence is missing.** If you cannot verify a criterion, mark it as unverifiable and explain why.
- **Every failure needs reproduction steps.** "It looks wrong" is not a valid finding.
- **Do not mark PASS if ANY acceptance criterion fails.** Use PASS_WITH_GAPS only if all criteria pass but you found non-critical issues.
- **Check for regressions.** Especially in feedback rounds — verify existing functionality still works.
- **Use the tools.** Build the project. Run the tests. Take screenshots. Interact with the UI. Don't evaluate based on code reading alone.

---

## ROLE: Planner B (Dual Planning)

You are the secondary Planner in a dual-planner setup. Read `references/DualSessionProtocol.md` for the full protocol.

1. Read `HarnessKit/NNN-MissionName/Planning/State.json` to understand the current step
2. Follow the protocol for Session B:
   - Write your findings to `Investigation-B.md`
   - Write your review of A's findings to `Review-B.md`
   - Respond in `Discussion/` when it's your turn
   - Review A's draft of Spec.md and give feedback in `Draft/`
3. **Never ask the user directly.** All user communication goes through Planner A.
4. Signal state changes by updating `Planning/State.json`
5. When waiting for Planner A, use watchman-wait on `Planning/State.json`

---

## ROLE: Resumption

The user is continuing after a session restart, crash, or interruption.

1. Read `Config.json` to find `currentMission`
2. If no current mission: tell the user "No active mission. Start a new one or ask about past missions."
3. Read the mission's `State.json`
4. Determine what this session was doing based on the state:
   - If `phase: "planning"`: resume as Planner (re-read Spec.md draft if exists)
   - If `phase: "generation"` and `generatorStatus: "working"`: resume as Generator
   - If `phase: "generation"` and `generatorStatus: "ready-for-eval"` or `phase: "evaluation"`: this might be the Generator waiting — re-enter the watch loop
   - If `phase: "evaluation"` and `evaluatorStatus: "evaluating"`: resume as Evaluator
   - If `phase: "evaluation"` and `evaluatorStatus: "waiting"`: re-enter the Evaluator watch loop
   - If `phase: "user-review"`: present the Review Briefing again or ask for feedback
   - If `phase: "complete"`: tell the user "Mission is complete. Start a new one?"
5. Tell the user what you found and what you're resuming as. Then proceed with that role.

---

## ROLE: Status

Show the current state of the active mission.

1. Read Config.json for `currentMission`
2. If no current mission: list completed missions from numbered subfolders, read their Summary.md files
3. If active mission:
   - Read State.json
   - Show: mission name, current phase, current round, who is working/waiting
   - Show: how many Gen rounds, how many Eval rounds, any user feedback rounds
   - Show: last update timestamp

---

## Summary.md Format

Generated when a mission is completed by the user:

```markdown
# NNN-MissionName — Summary

**Goal:** [one-line goal from Spec.md]
**Started:** YYYY-MM-DD
**Completed:** YYYY-MM-DD
**Rounds:** N total (M AI iterations + K user feedback rounds)
**Generator:** Claude Code
**Evaluator(s):** [Claude Code / Codex / dual]

## What Was Built
[2-3 paragraph summary of the implementation]

## Key Decisions
- [Decision 1 — rationale]
- [Decision 2 — rationale]

## Issues Found & Fixed
- Round 1: [issue] → [fix]
- Round 2: [issue] → [fix]

## User Feedback Addressed
- Feedback 1: [what the user said] → [what was changed]

## Files Changed
- [file list with brief descriptions]

## Acceptance Criteria Results
1. [criterion] — PASS
2. [criterion] — PASS
...
```

---

## Important Rules

### File Ownership (Prevents Write Conflicts)

| Files | Written By |
|---|---|
| `Spec.md` | Planner (or Planner A in dual setup) |
| `Gen/Round-NNN.md` | Generator |
| `Eval/Round-NNN.md` | Evaluator (or Evaluator A in dual setup) |
| `UserFeedback/Round-NNN.md` | Generator (documents user's words) |
| `State.json` | Whoever is transitioning state (Generator signals eval, Evaluator signals done) |
| `Summary.md` | Generator (at mission completion) |
| `Planning/*` | Respective planner (A or B writes their own files) |
| `EvalDiscussion/*` | Respective evaluator (A or B writes their own files) |

### watchman-wait Usage

Always use `watchman-wait` to watch for State.json changes instead of polling:
```bash
watchman-wait HarnessKit/NNN-MissionName -p "State.json" --max-events 1 -t 600
```

If the timeout expires (10 minutes), re-check State.json and restart the watch. This handles cases where watchman-wait misses an event.

When running `watchman-wait`, use the Bash tool with `run_in_background: true` so the session stays responsive. When the background task completes (file changed or timeout), read State.json and decide what to do next.

### Round Numbering

Round numbers are **continuous across the entire mission**. If the first inner loop was 2 rounds (Gen-001, Eval-001 FAIL, Gen-002, Eval-002 PASS), and the user gives feedback, the next round is 003. This creates a clear timeline.

### Spec Immutability

The Spec.md is immutable during implementation. The Generator and Evaluator work against the locked spec. User feedback is documented separately in `UserFeedback/` — it acts as a spec extension, not a spec modification.

### HarnessKit Files Not Committed Until Done

All files inside the `HarnessKit/NNN-MissionName/` folder remain uncommitted during the mission. Only when the user confirms the mission is complete are these files committed. This keeps the git history clean during active work.

Implementation code changes (the actual feature being built) ARE committed by the Generator at milestones, following the project's commit preferences from Config.json.
