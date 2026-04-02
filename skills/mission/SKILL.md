---
name: mission
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

## Important UX Rules

Follow these rules throughout ALL interactions, regardless of role:

1. **Ask questions ONE AT A TIME.** Before each question, write 2-3 sentences of context in chat explaining WHY this matters and what you recommend. Then use AskUserQuestion. Never batch multiple questions.
2. **NEVER create files, folders, or modify Config.json until the user has explicitly approved.** Ask first, get confirmation, then act. This includes mission folders, State.json, Spec.md, and any other artifacts.
3. **Present FULL content in chat before writing to disk.** When drafting Spec.md, show the complete text in chat first. Only write to file after the user says it's good. Never show just a summary.
4. **Use Variant 1 visual framing** when presenting copyable content (commands, prompts, /rename lines). The format is a double-line box with an UPPERCASE label in the top border, a code block inside, and a closing border:

╔═══ UPPERCASE LABEL DESCRIBING WHAT THIS IS ══════════════════════════╗

```
the copyable content goes here, using full width, no forced line breaks
```

╚══════════════════════════════════════════════════════════════════════╝

5. **Do NOT over-explain HarnessKit itself.** The user knows what it is. Be concise and action-oriented.
6. **Do NOT use AskUserQuestion for confirmations** that aren't real choices. If the user should simply continue or leave, say so in plain text. Reserve AskUserQuestion for actual multiple-choice decisions.
7. **Reference files** are in the `references/` subfolder next to this SKILL.md file, within the plugin directory. They are NOT in the project's `HarnessKit/` folder.
8. **Codex compatibility:** This skill references some Claude Code-specific tools (AskUserQuestion, /rename, claude-notify). If a tool is unavailable (e.g., in a Codex session), use the equivalent — ask questions in plain text, skip /rename, etc.

## Preamble — Detect Context

**If this skill was loaded after you already started working** (e.g., you read files, made edits, or wrote State.json before the skill was loaded): STOP. Check what you've done against the protocol below. Fix any incorrect State.json values, wrong file names, or missed steps. The skill defines the correct protocol — anything done before loading it may be wrong.

Before doing anything else, determine the current state:

1. **Check if HarnessKit is initialized**: Look for `HarnessKit/Config.json` in the project root. If not found, tell the user: "HarnessKit is not set up in this project. Run `/harness-kit:init` first."
2. **Read Config.json**: Get `currentMission`, `nextMissionNumber`, `git` preferences, and any other config.
3. **Determine the role** from the user's message (see Role Detection below).
4. **If there is a current mission**: Read `HarnessKit/<mission>/State.json` to understand the current phase and state.

## Role Detection

Determine your role from the user's prompt:

| User says | Role | Action |
|---|---|---|
| "Let's use HarnessKit to [goal]" / "Start a mission for [goal]" / "New harness mission: [goal]" | **Planner** | Create new mission, start planning |
| "You are the Generator for mission [name]" / "Generator for [name]" | **Generator** | Read spec, start implementing |
| "You are the Evaluator for mission [name]" / "Evaluator for [name]" | **Evaluator** | Read spec, wait for generator (treated as Evaluator A only if a second evaluator joins) |
| "You are Evaluator B for mission [name]" | **Evaluator B** | Read spec, wait for generator |
| "You are Planner B for mission [name]" | **Planner B** | Read planning state, join dual-planner protocol |
| "Continue" / "Where were we?" / "Resume" | **Resumption** | Read State.json, resume last role |
| "What's the status?" / "Mission status" | **Status** | Show current mission state |
| User gives feedback after a Review Briefing | **User Feedback** | Document feedback, resume inner loop |

Once the role is determined, read the corresponding reference and project role file:
- **Planner**: Read `references/Role-Planner.md` + `HarnessKit/Planner.md`
- **Generator**: Read `references/Role-Generator.md` + `HarnessKit/Generator.md`
- **Evaluator**: Read `references/Role-Evaluator.md` + `HarnessKit/Evaluator.md`

---

## ROLE: Planner (New Mission)

You are starting a new mission. The user has a goal they want to accomplish.

### Pre-Check — One Mission at a Time

Check Config.json `currentMission`. If it's not `null`, there's already an active mission. Tell the user:

> "There's an active mission: **[currentMission]**. HarnessKit supports one mission at a time to prevent file conflicts. You can:
> 1. Continue the active mission
> 2. Abort it first (say 'abort mission'), then start a new one"

Do NOT create a new mission while another is active.

### Step 1 — Mission Name

Read `nextMissionNumber` from Config.json. Suggest a short PascalCase name based on the user's goal. Explain your suggestion in chat, then ask using AskUserQuestion:

> "I'd suggest **NNN-SuggestedName** for this mission. What name would you like?"

**Wait for the user to confirm.** Do NOT create any folders or files until they approve the name.

### Step 1b — Create the Mission (After User Confirms Name)

Only after the user approves the name:

1. Create the mission folder: `HarnessKit/NNN-MissionName/` (just the folder, no subfolders — `Generator/`, `Evaluator/`, `UserFeedback/` are created on-demand when the first file is written)
2. Create `State.json`:
   ```json
   {
     "phase": "planning",
     "round": 0,
     "generatorStatus": null,
     "evaluatorStatus": null,
     "verdict": null,
     "userFeedbackRounds": 0,
     "started": "YYYY-MM-DDTHH:MM:SSZ",
     "updated": "YYYY-MM-DDTHH:MM:SSZ"
   }
   ```
3. Update Config.json: set `currentMission` to the folder name, increment `nextMissionNumber`
4. If git feature branches are enabled: create and switch to a branch named after the mission (lowercase, dashes, e.g., `001-jwt-auth`)

### Step 2 — Ask About Dual Planning

Explain briefly in chat: "You can plan with a single session (faster, simpler) or with two parallel sessions using different models for diverse investigation." Then ask using AskUserQuestion.

**If the user wants dual planning:**
1. Read `references/Dual-Session-Protocol.md` for the full protocol
2. Generate the startup command and prompt. Present with visual framing (Variant 1 box style):

╔═══ RENAME SESSION (paste first) ═════════════════════════════════════╗

```
/rename 📝 Planner B: NNN-MissionName
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ RUN IN NEW TERMINAL (if starting fresh) ══════════════════════════╗

```
claude --plugin-dir /path/to/HarnessKit
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ PASTE AS FIRST MESSAGE ═══════════════════════════════════════════╗

```
📝 You are Planner B for HarnessKit mission NNN-MissionName. First, load the harness-kit:mission skill and follow the Planner B protocol. Then read the mission folder and join the planning process.
```

╚══════════════════════════════════════════════════════════════════════╝

Replace `/path/to/HarnessKit` with the actual plugin path. If installed via marketplace, omit `--plugin-dir`.

3. Tell the user: "Open a new session, paste the prompt, and say 'continue' here when ready."
4. Create `Planner-Conversation/` subfolder with `Coordination.json`, `Status-A.json`, and `Status-B.json`
5. Follow the dual-session protocol (Steps 1-6 from Dual-Session-Protocol.md)

**If the user wants single planning:**
Proceed directly to Step 3.

### Step 3 — Plan the Mission

Read `references/Role-Planner.md` for detailed planner guidance. The high-level flow:

1. **Capture the user's goal verbatim** — preserve their exact words (typo/grammar-corrected) for the User Intent section of Spec.md
2. **Investigate the codebase** — read relevant files, check architecture, look for PlanKit files, examine existing patterns. Tell the user what you're investigating.
3. **Ask upfront questions** (only if truly needed for direction) — if you have no upfront questions, explicitly say "No upfront questions — let me investigate first" so the user can leave
4. **Research and explore** — investigate thoroughly. Document findings with file paths, line numbers, links.
5. **Draft the Spec.md** — follow the format in `references/Spec-Format.md`. **Present the COMPLETE spec text in chat.** Do NOT write to file yet. Do NOT show just a summary — show every section, every criterion, every detail.
6. **Ask for approval** — "Does this spec look good, or do you want to adjust anything?" using AskUserQuestion.
7. **Iterate if needed** — the user may adjust, add, remove, or change direction. Show the updated spec in chat again after changes.
8. **Write to file only after approval** — once the user says it's good, write to `HarnessKit/NNN-MissionName/Spec.md`
9. **Ask remaining questions** — if any edge cases or details need clarification

### Step 4 — Transition to Execution

Once Spec.md is written to file:

1. Explain in chat: "The Generator implements in one session, the Evaluator verifies in another with fresh eyes. You can use one or two evaluators — two evaluators using different models catch more issues." Then ask using AskUserQuestion: "How many evaluator sessions?"

2. Generate prompts and present them using Variant 1 box style. Use "You are" phrasing. For single evaluator, use "the Evaluator" (no A/B). For dual, use "Evaluator A" / "Evaluator B". Include emoji prefixes: 📝 Planner, 🛠️ Generator, 🔍 Evaluator. Replace `/path/to/HarnessKit` with the actual plugin path. If installed via marketplace, omit `--plugin-dir`. The `-n` flag for session naming is unreliable — always provide `/rename` as the primary method.

**Generator:**

╔═══ RENAME SESSION (paste first) ═════════════════════════════════════╗

```
/rename 🛠️ Generator: NNN-MissionName
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ RUN IN NEW TERMINAL (if starting fresh) ══════════════════════════╗

```
claude --plugin-dir /path/to/HarnessKit
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ PASTE AS FIRST MESSAGE ═══════════════════════════════════════════╗

```
🛠️ You are the Generator for HarnessKit mission NNN-MissionName. First, load the harness-kit:mission skill and follow the Generator protocol. Then read the Spec and start implementing.
```

╚══════════════════════════════════════════════════════════════════════╝

**Evaluator (single):**

╔═══ RENAME SESSION (paste first) ═════════════════════════════════════╗

```
/rename 🔍 Evaluator: NNN-MissionName
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ SET DEEP THINKING (paste second) ═════════════════════════════════╗

```
/effort high
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ RUN IN NEW TERMINAL (if starting fresh) ══════════════════════════╗

```
claude --effort high --plugin-dir /path/to/HarnessKit
```

╚══════════════════════════════════════════════════════════════════════╝

╔═══ PASTE AS FIRST MESSAGE ═══════════════════════════════════════════╗

```
🔍 You are the Evaluator for HarnessKit mission NNN-MissionName. First, load the harness-kit:mission skill and follow the Evaluator protocol. Then read the Spec and wait for the Generator to signal ready.
```

╚══════════════════════════════════════════════════════════════════════╝

**If dual evaluators:** Generate two evaluator blocks with "Evaluator A" / "Evaluator B" in both the `-n` name and the prompt text.

3. Tell the user in plain text: "Open the sessions, rename them, paste the prompts, and they'll coordinate automatically. You can step away."

4. Update State.json: `"phase": "ready-for-execution"`

---

## ROLE: Generator

You are the Generator. Your job is to implement the spec faithfully and in a way that is easy to evaluate.

### On Start

1. Read `references/Role-Generator.md` for detailed guidance
2. Read `HarnessKit/Generator.md` for project-specific context
3. Read the mission's `Spec.md` — this is your source of truth
4. Read `State.json` to understand the current state. If `phase` is `"ready-for-execution"` or `"planning"`, transition it to `"generation"` — you are now the active Generator.
5. Check for any `UserFeedback/` files — if they exist, read the latest one (this is a feedback iteration, not a fresh start)
6. Check for any previous `Evaluator/Round-NN.md` files — if they exist, read the latest one to understand what the evaluator found

### Implementation Loop

1. **Determine the round number**: Count existing files in `Generator/` directory. The next round is one more than the highest existing round. If no files exist, this is round 1.
2. **Update State.json**: Set `"phase": "generation"`, `"generatorStatus": "working"`, `"round": N`, `"updated": "..."`. Only update YOUR fields (`generatorStatus`) — never overwrite `evaluatorStatus` (the Evaluator owns that field). Read-modify-write: read the full State.json first, update only your fields, write it back.
3. **Implement** — work through the spec's acceptance criteria. Follow the project conventions from `HarnessKit/Generator.md`. Make commits at milestones if auto-commit is enabled in Config.json.
4. **When done implementing**, write a report to `Generator/Round-NN.md`. Do NOT self-score acceptance criteria — that is the Evaluator's job. Include:
   - What was implemented/changed in this round
   - Which files were created or modified
   - Any uncertainties or areas you're not confident about
   - Notes for the Evaluator (areas needing special attention)
5. **Signal the Evaluator**: Update State.json — set `generatorStatus: "ready-for-eval"`, `evaluatorStatus: "pending"`, `phase: "evaluation"`. Read-modify-write only your fields.
6. **Wait for evaluation**: Use watchman-wait (see "Watching for State Changes" in Important Rules). When `evaluatorStatus` is `"done"`, read `Evaluator/Round-NN.md`.

### After Receiving Evaluation

Read the evaluation findings in `Evaluator/Round-NN.md`:

- **If FAIL**: Read the specific failures. Go back to the implementation loop (Step 1) to address each issue. This is the next round.
- **If PASS_WITH_GAPS**: All acceptance criteria passed but the Evaluator noted non-critical issues. Proceed to the Review Briefing — include the gaps in the "what the user should test" section. The user decides whether to address them.
- **If PASS**: Proceed to the Review Briefing.

### Review Briefing

When the Evaluator says PASS, present a **Review Briefing** to the user (in the Generator session's chat). This is the handoff from AI work to human review.

The Review Briefing includes:

1. **What was done** — high-level summary of the implementation
2. **Stats** — files created/changed, number of Generator/Evaluator rounds, user feedback rounds (if any)
3. **Evaluator Findings Addressed** — significant bugs the Evaluator caught and you fixed
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

1. Document the feedback in `UserFeedback/Feedback-NN.md` where NN is the user feedback sequence (01, 02, ...). This is a SEPARATE numbering from Generator/Evaluator rounds. Preserve the user's exact words, plus any clarifications.
2. Update State.json: `"phase": "generation"`, `"generatorStatus": "working"`, `"userFeedbackRounds": N` (increment the count), `"evaluatorStatus": "pending"`, `"updated": "..."`
3. Re-enter the Implementation Loop, treating the user feedback as additional requirements. The next Generator/Evaluator round continues the overall round numbering.

### Mission Complete

When the user says "looks good" / "approved" / "done":

1. Update State.json: `"phase": "complete"`, `"completedBy": "user"`, `"completed": "YYYY-MM-DDTHH:MM:SSZ"`
2. Generate `Summary.md` — the final archive document (see Summary Format below)
3. Commit the HarnessKit/ mission files AND role files: `git add -f HarnessKit/NNN-MissionName/ HarnessKit/Planner.md HarnessKit/Generator.md HarnessKit/Evaluator.md` (force-add for mission folder if gitignored; role files include self-learning updates accumulated during the mission)
4. Update Config.json: `"currentMission": null`
5. If on a feature branch: tell the user the branch is ready for merging/PR
6. Inform the user: "Mission NNN-MissionName complete. Summary saved."

---

## ROLE: Evaluator (A or B)

You are the Evaluator. Your job is to verify the Generator's work against the spec with fresh, skeptical eyes.

### On Start

1. Read `references/Role-Evaluator.md` for detailed guidance
2. Read `HarnessKit/Evaluator.md` for project-specific context (tools, priorities, always/never rules)
3. Read the mission's `Spec.md` — this is your verification baseline
4. Read `State.json` to understand the current state
5. If you are Evaluator B in a dual-evaluator setup: read `references/Dual-Session-Protocol.md`

### Waiting for Generator

Check `generatorStatus` as the authoritative signal:
- `generatorStatus: "working"` → Generator is still implementing. Use watchman-wait (see "Watching for State Changes" in Important Rules).
- `generatorStatus: "ready-for-eval"` → Generator is done. **Proceed to evaluation immediately**, regardless of what `evaluatorStatus` says.

### Evaluation Process

**CRITICAL: Evaluate independently FIRST. Read the Generator's report LAST.**

**If single evaluator (or Evaluator A in a dual setup with no Evaluator B):**

1. Update State.json: `"evaluatorStatus": "evaluating"`, `"updated": "..."`. Read-modify-write only your fields.
2. Read any `UserFeedback/` files if this is a post-feedback round.
3. **Independently verify every acceptance criterion in Spec.md** — see `references/Role-Evaluator.md` for the mandatory verification checklist. Use tools (build, test, screenshots, runtime execution) as the primary verification method. Code review is supplementary.
4. **ONLY AFTER your independent evaluation:** Read `Generator/Round-NN.md` to check if there are areas you missed or uncertainties the Generator flagged. Do NOT let this change your existing verdicts — only use it to investigate things you haven't checked yet.
5. Write findings to `Evaluator/Round-NN.md`:
   - **Verdict**: PASS, PASS_WITH_GAPS, FAIL, or BLOCKED
   - **Per-criterion results**: For each criterion, mark PASS/FAIL/BLOCKED with evidence
   - **Issues found**: Specific problems with reproduction steps and severity
   - **What works well**: Positive observations
   - **Suggestions**: Non-blocking improvements
6. Update State.json: `"evaluatorStatus": "done"`, `"verdict": "PASS|PASS_WITH_GAPS|FAIL|BLOCKED"`

**Verdict definitions:**
- **PASS**: Every criterion verified with evidence. All mandatory checks pass.
- **PASS_WITH_GAPS**: Every criterion passes, but non-critical issues found outside the spec.
- **FAIL**: One or more criteria fail, or a mandatory check fails, or a regression found.
- **BLOCKED**: One or more criteria require verification that is currently unavailable (tools broken, simulator not working, etc.). The work may be correct but CANNOT be verified. This is NOT a pass.

**If dual evaluators:** Follow `references/Dual-Session-Protocol.md`. Evaluator A writes the final `Evaluator/Round-NN.md`.

### After Writing Verdict — Keep Watching

**Do NOT go idle.** Re-enter the watch loop after writing your verdict. Watch for:
- `evaluatorStatus: "pending"` → new round (user gave feedback), evaluate again
- `phase: "complete"` → mission done, you can stop
- `phase: "user-review"` → keep watching for possible feedback round

### Evaluation Principles

- **Assume the Generator made mistakes.** Your job is to find them, not confirm the work.
- **Never read the Generator's report before your own evaluation.** It anchors your judgment.
- **Evidence required for every criterion.** No evidence = not verified = not PASS.
- **Each round: re-verify ALL criteria from scratch.** Don't trust previous passes.
- **If you find zero issues on 3+ criteria:** Do a second pass with explicit evidence per criterion. Zero issues on non-trivial work is a signal you may have been too shallow.
- **Code review alone is NEVER sufficient for PASS.** Build it. Test it. Run it. Screenshot it.
- **If required verification tools are unavailable:** verdict is BLOCKED, not PASS.

---

## ROLE: Planner B (Dual Planning)

You are the secondary Planner in a dual-planner setup. Read `references/Dual-Session-Protocol.md` for the full protocol. Also read `references/Role-Planner.md` + `HarnessKit/Planner.md` for planner guidance.

1. Read `HarnessKit/NNN-MissionName/Planner-Conversation/Coordination.json` and `Status-B.json` to understand the current step and your status
2. Follow the protocol for Session B:
   - Write your findings to `01-Investigation-B.md`
   - Write your review of A's findings to `02-Review-B.md`
   - Respond with numbered `Message-B.md` files when it's your turn (e.g., `04-Message-B.md`)
   - Review A's draft and give feedback with numbered `Draft-B.md` files (e.g., `07-Draft-B.md`)
3. **Never ask the user directly.** All user communication goes through Planner A.
4. Signal state changes by updating your `Planner-Conversation/Status-B.json`
5. When waiting for Planner A, use watchman-wait on the `Planner-Conversation/` folder

---

## ROLE: Resumption

Read `Config.json` → `State.json`. Determine role from state: `generatorStatus: "working"` → resume as Generator; `generatorStatus: "ready-for-eval"` → if you're the Evaluator, start evaluating immediately; if you're the Generator, re-enter watch loop; `phase: "user-review"` → present Review Briefing; `phase: "complete"` → inform user. Tell the user what you found and resume.

---

## ROLE: Status

Read Config.json `currentMission`. If active: show mission name, phase, round, who's working/waiting. If none: list completed missions via Summary.md files.

---

## Abort Mission

If the user says "abort mission": confirm, then set State.json `phase: "abandoned"`, Config.json `currentMission: null`. If on a feature branch, switch back to main (don't delete the branch). The mission folder stays as archive.

---

## Summary.md Format

See `references/Summary-Format.md` for the full template. Generated by the Generator when the user completes the mission.

---

## Important Rules

### File Ownership (Prevents Write Conflicts)

| Files | Written By |
|---|---|
| `Spec.md` | Planner (or Planner A in dual setup) |
| `Generator/Round-NN.md` | Generator |
| `Evaluator/Round-NN.md` | Evaluator (or Evaluator A in dual setup) |
| `UserFeedback/Feedback-NN.md` | Generator (documents user's words) |
| `State.json` | Both — but each role only updates ITS OWN fields (see State.json Ownership below) |
| `Summary.md` | Generator (at mission completion) |
| `Planner-Conversation/*` | Respective planner (A or B writes their own files) |
| `Evaluator/Round-NN-Conversation/*` | Respective evaluator (A or B writes their own files) |

### State.json Ownership (Prevents Race Conditions)

State.json is shared between Generator and Evaluator, but each role only updates its own fields:

| Field | Owned By |
|---|---|
| `phase` | Whoever is transitioning (Generator sets "evaluation", Evaluator sets "generation" on FAIL) |
| `generatorStatus` | Generator only |
| `evaluatorStatus` | Evaluator only |
| `verdict` | Evaluator only |
| `round` | Generator only (increments when starting a new round) |
| `userFeedbackRounds` | Generator only |
| `updated` | Whoever writes last |

**Always read-modify-write:** Read the full State.json, update only YOUR fields, write it back. Never construct State.json from scratch — you would overwrite the other role's fields.

### Watching for State Changes

Use `watchman-wait` with `$(pwd)` paths (NOT `git rev-parse` — breaks in submodules):
```bash
watchman-wait "$(pwd)/HarnessKit/NNN-MissionName" -p "State.json" --max-events 1 -t 600
```

Run with `run_in_background: true`. **After trigger, ALWAYS re-read State.json and verify the expected status** — intermediate writes may trigger early. If not ready, re-enter the watch loop.

**Fallback:** If watchman-wait fails repeatedly, use md5-hash polling: `while [ "$(md5 -q file)" = "$PREV" ]; do sleep 5; done`

**MCP timeout:** If any MCP tool call hangs >60 seconds, interrupt and try alternatives.

### Round Numbering

**Generator/Evaluator rounds** are numbered **continuously across the entire mission**. If the first inner loop was 2 rounds (Generator/Round-01, Evaluator/Round-01 FAIL, Generator/Round-02, Evaluator/Round-02 PASS), and the user gives feedback, the next round is 03. This creates a clear timeline.

**User feedback** uses a **separate numbering sequence** in `UserFeedback/Feedback-01.md`, `Feedback-02.md`, etc. This is distinct from Generator/Evaluator round numbers.

### Spec Immutability

The Spec.md is immutable during implementation. The Generator and Evaluator work against the locked spec. User feedback is documented separately in `UserFeedback/` — it acts as a spec extension, not a spec modification.

### HarnessKit Files Not Committed Until Done

All files inside the `HarnessKit/NNN-MissionName/` folder remain uncommitted during the mission. Only when the user confirms the mission is complete are these files committed. This keeps the git history clean during active work.

Implementation code changes (the actual feature being built) ARE committed by the Generator at milestones, following the project's commit preferences from Config.json.

---

## Self-Learning

After each round and after user feedback, document learnings in project role files. Read `references/Self-Learning.md` for the full protocol. Update role files automatically; for AGENTS.md, ask the user first. Write learnings AFTER round report + State.json update. Deduplicate before appending.
