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
3. Each updates their own signal file: Session A writes `StatusA.json` with `"status": "upfront-done"`, Session B writes `StatusB.json` with `"status": "upfront-done"`
4. **Wait for each other**: Use `watchman-wait` on the protocol folder. When a file changes, read both StatusA.json and StatusB.json. Proceed when both show `"upfront-done"`.
5. **Session A collects all questions** from both files. If there are questions, asks the user in its chat and documents answers in `UserAnswers.md`. If no questions from either session, A explicitly tells the user: "No upfront questions — I'll investigate first. You can step away."
6. **Session A signals** the answers are ready by updating Protocol.json: `"step": "parallel-investigation"`

**Evaluators skip this step entirely** — they never ask the user.

### Step 2 — Parallel Investigation

Both sessions investigate independently and simultaneously. They do NOT wait for each other during this step.

**For Planners:** Investigate the codebase, read relevant files, explore architecture, check existing documentation, research external resources. Document everything with file paths, line numbers, and links.

**For Evaluators:** Independently evaluate the implementation against the spec. Use available tools (build, test, screenshots, UI interaction). Document each acceptance criterion's pass/fail status with evidence.

1. **Session A** writes findings to `Investigation-A.md`
2. **Session B** writes findings to `Investigation-B.md`
3. Each updates their own signal file with `"status": "investigation-done"`
4. **Wait for each other**: Watch for file changes, check both StatusA.json and StatusB.json

### Step 3 — Parallel Cross-Review

Both sessions read the other's investigation and write a review. This happens in parallel.

1. **Session A** reads `Investigation-B.md`, writes review to `Review-A.md`
   - What B found that A missed
   - What A disagrees with in B's findings
   - What A would add or clarify
   - Specific questions for B
2. **Session B** reads `Investigation-A.md`, writes review to `Review-B.md`
   - Same structure
3. Each updates their own signal file with `"status": "review-done"`
4. **Wait for each other**: Watch for file changes, check both signal files

### Step 4 — Sequential Discussion

From here, sessions alternate. **A always goes first.**

1. **Session A** reads `Review-B.md`, responds in `Discussion/001-A.md`
   - Addresses B's questions and disagreements
   - Incorporates B's findings that A agrees with
   - States remaining disagreements clearly
2. Update Protocol.json: `"discussionRound": 1`. Update StatusA.json: `"status": "discussion-done"`
3. **Session B** reads `Discussion/001-A.md`, responds in `Discussion/002-B.md`
4. Update Protocol.json: `"discussionRound": 2`. Update StatusB.json: `"status": "discussion-done"`
5. Continue alternating until **both sessions agree 100% on every aspect**
   - No skipping disagreements — everything must be explicitly resolved
   - Each response must state what is now agreed and what remains unresolved
   - When fully agreed, the last response states: "Full agreement reached on all points."

### Step 5 — Documentation

Session A writes the final document. Session B reviews it.

**For Planners:** Session A writes the draft Spec.md to `Draft/001-A.md`
**For Evaluators:** Session A writes the draft Eval/Round-NNN.md to `Draft/001-A.md`

1. **Session A** writes the complete draft based on all investigations, reviews, and discussion
2. Update Protocol.json: `"draftRound": 1`, `"step": "documentation"`. Update StatusA.json: `"status": "draft-done"`
3. **Session B** reads the draft, writes feedback to `Draft/002-B.md`
   - Points out anything missing, incorrect, or inconsistent
   - Verifies all agreed-upon points are captured
   - Says "Approved" if the draft is complete and correct
4. If B has feedback: **Session A** revises in `Draft/003-A.md`, B re-reviews in `Draft/004-B.md`
5. Continue until B approves
6. **Session A** writes the final document to its proper location:
   - Planners: `Spec.md` in the mission folder
   - Evaluators: `Eval/Round-NNN.md` in the mission folder

### Step 6 — End Questions (Planners Only)

After the spec draft is approved by both planners:

1. **Session A** collects any remaining questions that arose during investigation and discussion
2. Presents these to the user in A's chat, documents answers in `EndQuestions.md`
3. If answers require significant changes: update Protocol.json to go back to Step 2 (re-investigation)
4. If answers are minor clarifications: Session A updates the Spec.md directly

**Evaluators skip this step** — they write the final evaluation and signal done.

---

## Coordination Files

### Separate Signal Files (Prevents Race Conditions)

During parallel phases (Steps 1-3), both sessions work simultaneously and signal completion independently. To avoid race conditions on a shared State.json, each session writes its own signal file:

- **StatusA.json** — Session A's status (only Session A writes this)
- **StatusB.json** — Session B's status (only Session B writes this)
- **Protocol.json** — Shared protocol state (step, discussion round, draft round). Written only during sequential phases (Steps 4-6) where turn-taking prevents conflicts.

**Why separate files:** During parallel phases, both sessions finish at unpredictable times. If both read-modify-write a shared State.json, one session's update gets lost. Separate files eliminate this entirely — each session only writes its own file.

### StatusA.json / StatusB.json

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
| sequential-discussion | `discussing`, `discussion-done`, `waiting` |
| documentation | `drafting`, `draft-done`, `reviewing-draft`, `approved` |
| end-questions | `collecting`, `asking-user`, `done` |

### Protocol.json

```json
{
  "step": "parallel-investigation",
  "discussionRound": 0,
  "draftRound": 0,
  "updated": "2026-03-31T14:30:00Z"
}
```

**Step values:** `upfront-questions` → `parallel-investigation` → `parallel-review` → `sequential-discussion` → `documentation` → `end-questions` → `done`

Protocol.json is updated when transitioning between steps. During parallel phases, the session that detects both are done advances the step. During sequential phases, the current speaker advances the step.

---

## Watching for State Changes

To detect when the other session finishes, watch the protocol folder for ANY file change:

```bash
GIT_ROOT=$(git rev-parse --show-toplevel)
watchman-wait "$GIT_ROOT/<path-to-protocol-folder>" -p "StatusA.json" -p "StatusB.json" -p "Protocol.json" --max-events 1 -t 600
```

Run this with `run_in_background: true` so the session stays responsive. When a file changes, read both StatusA.json and StatusB.json (and Protocol.json for sequential phases) to determine if it's your turn.

If the timeout expires (10 minutes), re-read all status files anyway and restart the watch if still waiting.

---

## File Structure

```
Planning/                              # For dual planners
├── Protocol.json                      # Shared protocol state (step, rounds)
├── StatusA.json                       # Session A's status
├── StatusB.json                       # Session B's status
├── UpfrontQuestions-A.md
├── UpfrontQuestions-B.md
├── UserAnswers.md
├── Investigation-A.md
├── Investigation-B.md
├── Review-A.md
├── Review-B.md
├── Discussion/
│   ├── 001-A.md
│   ├── 002-B.md
│   ├── 003-A.md
│   └── 004-B.md
├── EndQuestions.md
└── Draft/
    ├── 001-A.md
    ├── 002-B.md
    └── 003-A.md

EvalDiscussion/Round-NNN/              # For dual evaluators, per eval round
├── Protocol.json
├── StatusA.json
├── StatusB.json
├── Investigation-A.md
├── Investigation-B.md
├── Review-A.md
├── Review-B.md
├── Discussion/
│   ├── 001-A.md
│   └── 002-B.md
└── Draft/
    ├── 001-A.md
    └── 002-B.md
```

## Key Rules

- **All findings must include source references** — file paths with line numbers, links, command outputs. The other session must be able to verify without re-investigating everything.
- **No skipping disagreements** — every point of disagreement must be explicitly resolved in the sequential discussion.
- **Session A always writes the final document** — B reviews and approves, but A is the author.
- **Session B never talks to the user** — all user communication goes through A.
- **The user can leave after upfront questions** — the dual-session protocol runs autonomously until documentation is complete (planners) or evaluation is done (evaluators).
