# Dual-Session Protocol

When two sessions share the same role (two Planners or two Evaluators), they follow this structured protocol. Session A is always the primary. Session B is always the secondary.

## Roles

- **Session A (Primary):** Asks the user (planners only), writes the final document, goes first in sequential phases, reconciles disagreements.
- **Session B (Secondary):** Never talks to the user directly. Reviews A's work. Provides independent perspective.

## The 6-Step Protocol

### Step 1 — Upfront Questions (Planners Only)

Both sessions independently think about whether the user needs to clarify direction before investigation begins.

1. **Session A** writes questions (if any) to `UpfrontQuestions-A.md`
2. **Session B** writes questions (if any) to `UpfrontQuestions-B.md`
3. Each signals completion:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "<A-or-B>" "upfront-done"
   ```
4. **Wait for each other:**
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/wait-for-turn.sh" "<conv-folder>" "<A-or-B>" "parallel" --wait-for upfront-done
   ```
   Codex sessions: add `--quiet`. Claude sessions: use `run_in_background: true`.
5. **Session A collects all questions** from both files. If there are questions, asks the user in its chat and documents answers in `UserAnswers.md`. If no questions from either session, A explicitly tells the user: "No upfront questions — I'll investigate first. You can step away."
6. **Session A advances the step:**
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "A" "upfront-done" --step parallel-investigation
   ```

**Evaluators skip this step entirely** — they never ask the user.

### Step 2 — Parallel Investigation

Both sessions investigate independently and simultaneously. They do NOT wait for each other during this step.

**For Planners:** Investigate the codebase, read relevant files, explore architecture, check existing documentation, research external resources. Document everything with file paths, line numbers, and links.

**For Evaluators:** Independently evaluate the implementation against the spec. Use available tools (build, test, screenshots, UI interaction). Document each acceptance criterion's pass/fail status with evidence.

1. **Session A** writes findings to `01-Investigation-A.md`
2. **Session B** writes findings to `01-Investigation-B.md`
3. Each signals completion:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "<A-or-B>" "investigation-done"
   ```
4. **Wait for each other:**
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/wait-for-turn.sh" "<conv-folder>" "<A-or-B>" "parallel" --wait-for investigation-done
   ```
   Codex sessions: add `--quiet`. Claude sessions: use `run_in_background: true`.
5. **Session A advances the step:**
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "A" "investigation-done" --step parallel-review
   ```

### Step 3 — Parallel Cross-Review

Both sessions read the other's investigation and write a review. This happens in parallel.

1. **Session A** reads `01-Investigation-B.md`, writes review to `02-Review-A.md`
   - What B found that A missed
   - What A disagrees with in B's findings
   - What A would add or clarify
   - Specific questions for B
2. **Session B** reads `01-Investigation-A.md`, writes review to `02-Review-B.md`
   - Same structure
3. Each signals completion:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "<A-or-B>" "review-done"
   ```
4. **Wait for each other:**
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/wait-for-turn.sh" "<conv-folder>" "<A-or-B>" "parallel" --wait-for review-done
   ```
   Codex sessions: add `--quiet`. Claude sessions: use `run_in_background: true`.
5. **Session A advances the step:**
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "A" "review-done" --step sequential-conversation --next-turn A
   ```

### Step 4 — Sequential Conversation

From here, sessions alternate messages. **A always goes first.**

1. **Session A** reads `02-Review-B.md`, responds in `03-Message-A.md`
   - Addresses B's questions and disagreements
   - Incorporates B's findings that A agrees with
   - States remaining disagreements clearly
2. Signal and wait:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "A" "message-done" --next-turn B --message-round 3
   ```
   Then run `wait-for-turn.sh` in sequential mode.
3. **Session B** reads `03-Message-A.md`, responds in `04-Message-B.md`
4. Signal and wait:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "B" "message-done" --next-turn A --message-round 4
   ```
   Then run `wait-for-turn.sh` in sequential mode.
5. Continue alternating until **both sessions agree on all points**
   - Each message must state what is now agreed and what remains unresolved
   - When fully agreed, the last message states: "Full agreement reached on all points."
   - **Deadlock prevention:** If no agreement after 5 exchanges (10 messages), Session A writes the final document noting disagreements and lets the user decide.

### Step 5 — Documentation

Session A writes the final document. Session B reviews it.

1. **Session A** writes the complete draft (next numbered file, e.g., `05-Draft-A.md`)
2. Signal and wait:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "A" "draft-done" --step documentation --next-turn B
   ```
   Then run `wait-for-turn.sh` in sequential mode.
3. **Session B** reads the draft, writes feedback (e.g., `06-Draft-B.md`). Signal:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "B" "reviewing-draft" --next-turn A
   ```
   Or if approved:
   ```bash
   bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "B" "approved" --next-turn A
   ```
   - Points out anything missing, incorrect, or inconsistent
   - Verifies all agreed-upon points are captured
   - Says "Approved" if the draft is complete and correct
4. If B has feedback: **Session A** revises (e.g., `07-Draft-A.md`), B re-reviews (`08-Draft-B.md`)
5. Continue until B approves
6. **Session A** writes the final document to its proper location:
   - Planners: `Spec.md` in the mission folder
   - Evaluators: `Evaluator/Round-NN.md` in the mission folder

### Step 6 — End Questions (Planners Only, Optional)

If questions arose during investigation and discussion that weren't resolved:

1. **Session A** collects remaining questions, presents to the user, documents answers in `EndQuestions.md`
2. If answers require significant changes: go back to Step 2
3. If minor: Session A updates Spec.md directly

If no unresolved questions (the common case), skip this step.

**Session A MUST signal terminal state when planning/evaluation is complete:**
```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/signal-step.sh" "<conv-folder>" "A" "done" --step done
```
This ensures Coordination.json reaches `step: "done"`. Without this, B cannot detect completion.

**Evaluators skip this step** — they write the final evaluation and signal done.

---

## File Numbering Convention

All working files in the conversation folder use a **continuous two-digit numbering** that shows the order of work:

- **Same number = parallel** (01-Investigation-A + 01-Investigation-B happened simultaneously)
- **Incrementing numbers = sequential** (03-Message-A, then 04-Message-B, then 05-Message-A)
- **Unnumbered files** (UpfrontQuestions, UserAnswers, EndQuestions, Coordination.json, Status files) are bookends/infrastructure, not part of the main sequence

Example sequence for a dual-planner conversation:
```
01-Investigation-A.md       # Parallel: both investigate
01-Investigation-B.md
02-Review-A.md              # Parallel: both cross-review
02-Review-B.md
03-Message-A.md             # Sequential: A responds to B's review
04-Message-B.md             # Sequential: B responds
05-Message-A.md             # Sequential: agreement reached
06-Draft-A.md               # A writes spec draft
07-Draft-B.md               # B approves → becomes Spec.md
```

---

## Coordination Files

### Separate Signal Files (Prevents Race Conditions)

During parallel phases (Steps 1-3), both sessions work simultaneously and signal completion independently. To avoid race conditions, each session writes its own signal file:

- **Status-A.json** — Session A's status (only Session A writes this)
- **Status-B.json** — Session B's status (only Session B writes this)
- **Coordination.json** — Shared state (step, message round). Written only during sequential phases (Steps 4-6) where turn-taking prevents conflicts.

**Why separate files:** During parallel phases, both sessions finish at unpredictable times. If both read-modify-write a shared file, one session's update gets lost. Separate files eliminate this entirely.

### Status-A.json / Status-B.json

```json
{
  "status": "investigation-done",
  "tool": "claude-code",
  "updated": "2026-03-31T14:30:00Z"
}
```

**Status values by step:**

| Step | Possible Statuses |
|---|---|
| upfront-questions | `thinking`, `upfront-done` |
| parallel-investigation | `investigating`, `investigation-done` |
| parallel-review | `reviewing`, `review-done` |
| sequential-conversation | `composing`, `message-done`, `waiting` |
| documentation | `drafting`, `draft-done`, `reviewing-draft`, `approved` |
| end-questions | `collecting`, `asking-user`, `done` |

### Coordination.json

```json
{
  "step": "parallel-investigation",
  "nextTurn": "A",
  "messageRound": 0,
  "updated": "2026-03-31T14:30:00Z"
}
```

**Step values:** `upfront-questions` → `parallel-investigation` → `parallel-review` → `sequential-conversation` → `documentation` → `end-questions` → `done`

**`nextTurn`** is the authoritative handoff field. When you write an artifact, set `nextTurn` to the other session's letter. The other session checks `nextTurn` to know if it's their turn. Do NOT rely on timestamps — they can drift. `nextTurn` is the source of truth for turn-taking.

During parallel phases (Steps 1-3), `nextTurn` is not used — both sessions work independently and watch for the other's `-done` status.

---

## Active Watching (MANDATORY)

**After EVERY `-done` state write, IMMEDIATELY enter a watch loop.** Do not go idle. Do not wait passively. Do not stop.

**Before claiming you are waiting**, re-read Coordination.json, Status-A.json, and Status-B.json. If it's already your turn (`nextTurn` matches you, or both are `-done` for parallel phases), proceed immediately.

**Session B must NEVER stop watching** until Session A reaches the user-approval boundary. Only Session A can stop — and only at that specific point.

Use the plugin's `scripts/wait-for-turn.sh` script to block until it's your turn:

```bash
# Parallel phases — always specify --wait-for with the expected status
bash "${CLAUDE_SKILL_DIR}/../../scripts/wait-for-turn.sh" "<conv-folder>" "<A-or-B>" "parallel" --wait-for <expected-status>

# Sequential phases
bash "${CLAUDE_SKILL_DIR}/../../scripts/wait-for-turn.sh" "<conv-folder>" "<A-or-B>" "sequential"
```

**Claude (Session A, sole sessions):** Run with `run_in_background: true`.

**Codex (Session B):** Run as a blocking call with `--quiet` — do NOT use `run_in_background`:
```bash
bash "${CLAUDE_SKILL_DIR}/../../scripts/wait-for-turn.sh" "<conv-folder>" "B" "parallel" --wait-for investigation-done --quiet
```

Use `scripts/signal-step.sh` for ALL status/coordination updates. Do NOT hand-edit Status or Coordination JSON files directly.

Do NOT implement your own watching logic. Use the scripts.

---

## File Structure

### Planner-Conversation/ (dual planners → produces Spec.md)

```
Planner-Conversation/
├── Coordination.json
├── Status-A.json
├── Status-B.json
├── UpfrontQuestions-A.md
├── UpfrontQuestions-B.md
├── UserAnswers.md
├── 01-Investigation-A.md
├── 01-Investigation-B.md
├── 02-Review-A.md
├── 02-Review-B.md
├── 03-Message-A.md
├── 04-Message-B.md
├── 05-Message-A.md              # Agreement reached
├── 06-Draft-A.md
├── 07-Draft-B.md                # Approved → becomes Spec.md
└── EndQuestions.md
```

### Round-NN-Conversation/ inside Evaluator/ (dual evaluators → produces Round-NN.md)

```
Evaluator/
├── Round-01.md                  # Final eval verdict (produced by the conversation)
├── Round-01-Conversation/       # The process that produced Round-01.md
│   ├── Coordination.json
│   ├── Status-A.json
│   ├── Status-B.json
│   ├── 01-Investigation-A.md
│   ├── 01-Investigation-B.md
│   ├── 02-Review-A.md
│   ├── 02-Review-B.md
│   ├── 03-Message-A.md
│   ├── 04-Message-B.md         # Agreement reached
│   ├── 05-Draft-A.md
│   └── 06-Draft-B.md           # Approved → becomes Round-01.md
├── Round-02.md
└── Round-02-Conversation/
    └── ...
```

**The relationship is obvious:** `Round-01-Conversation/` is the conversation that produced `Round-01.md`. `Planner-Conversation/` is the conversation that produced `Spec.md`.

---

## Key Rules

- **All findings must include source references** — file paths with line numbers, links, command outputs. The other session must be able to verify without re-investigating everything.
- **No skipping disagreements** — every point of disagreement must be explicitly resolved in the sequential conversation.
- **Session A always writes the final document** — B reviews and approves, but A is the author.
- **Session B never talks to the user** — all user communication goes through A.
- **The user can leave after upfront questions** — the dual-session protocol runs autonomously until documentation is complete (planners) or evaluation is done (evaluators).
