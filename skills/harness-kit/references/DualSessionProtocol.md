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
3. Each updates their own status in State.json: `"sessionA": {"status": "upfront-done"}` / `"sessionB": {"status": "upfront-done"}`
4. **Wait for each other**: Use `watchman-wait` on State.json until both sessions show `"upfront-done"`
5. **Session A collects all questions** from both files. If there are questions, asks the user in its chat and documents answers in `UserAnswers.md`. If no questions from either session, A explicitly tells the user: "No upfront questions — I'll investigate first. You can step away."
6. **Session A signals** the answers are ready by updating State.json: `"step": "parallel-investigation"`

**Evaluators skip this step entirely** — they never ask the user.

### Step 2 — Parallel Investigation

Both sessions investigate independently and simultaneously. They do NOT wait for each other during this step.

**For Planners:** Investigate the codebase, read relevant files, explore architecture, check existing documentation, research external resources. Document everything with file paths, line numbers, and links.

**For Evaluators:** Independently evaluate the implementation against the spec. Use available tools (build, test, screenshots, UI interaction). Document each acceptance criterion's pass/fail status with evidence.

1. **Session A** writes findings to `Investigation-A.md`
2. **Session B** writes findings to `Investigation-B.md`
3. Each updates State.json when done: `"sessionA": {"status": "investigation-done"}` / `"sessionB": {"status": "investigation-done"}`
4. **Wait for each other**: Use `watchman-wait` on State.json until both are done

### Step 3 — Parallel Cross-Review

Both sessions read the other's investigation and write a review. This happens in parallel.

1. **Session A** reads `Investigation-B.md`, writes review to `Review-A.md`
   - What B found that A missed
   - What A disagrees with in B's findings
   - What A would add or clarify
   - Specific questions for B
2. **Session B** reads `Investigation-A.md`, writes review to `Review-B.md`
   - Same structure
3. Both update State.json when done: `"sessionA": {"status": "review-done"}` / `"sessionB": {"status": "review-done"}`
4. **Wait for each other**

### Step 4 — Sequential Discussion

From here, sessions alternate. **A always goes first.**

1. **Session A** reads `Review-B.md`, responds in `Discussion/001-A.md`
   - Addresses B's questions and disagreements
   - Incorporates B's findings that A agrees with
   - States remaining disagreements clearly
2. Update State.json: `"discussionRound": 1`, `"sessionA": {"status": "discussion-done"}`
3. **Session B** reads `Discussion/001-A.md`, responds in `Discussion/002-B.md`
4. Update State.json: `"discussionRound": 2`, `"sessionB": {"status": "discussion-done"}`
5. Continue alternating until **both sessions agree 100% on every aspect**
   - No skipping disagreements — everything must be explicitly resolved
   - Each response must state what is now agreed and what remains unresolved
   - When fully agreed, the last response states: "Full agreement reached on all points."

### Step 5 — Documentation

Session A writes the final document. Session B reviews it.

**For Planners:** Session A writes the draft Spec.md to `Draft/001-A.md`
**For Evaluators:** Session A writes the draft Eval/Round-NNN.md to `Draft/001-A.md`

1. **Session A** writes the complete draft based on all investigations, reviews, and discussion
2. Update State.json: `"draftRound": 1`, `"step": "documentation"`
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
3. If answers require significant changes: update State.json to go back to Step 2 (re-investigation)
4. If answers are minor clarifications: Session A updates the Spec.md directly

**Evaluators skip this step** — they write the final evaluation and signal done.

---

## State.json Schema for Dual-Session Protocol

```json
{
  "step": "parallel-investigation",
  "sessionA": {
    "status": "investigating",
    "tool": "claude-code"
  },
  "sessionB": {
    "status": "investigating",
    "tool": "codex"
  },
  "discussionRound": 0,
  "draftRound": 0,
  "updated": "2026-03-31T14:30:00Z"
}
```

**Step values:** `upfront-questions` → `parallel-investigation` → `parallel-review` → `sequential-discussion` → `documentation` → `end-questions` → `done`

**Session status values by step:**

| Step | Possible Statuses |
|---|---|
| upfront-questions | `thinking`, `upfront-done` |
| parallel-investigation | `investigating`, `investigation-done` |
| parallel-review | `reviewing`, `review-done` |
| sequential-discussion | `discussing`, `discussion-done`, `waiting` |
| documentation | `drafting`, `draft-done`, `reviewing-draft`, `approved` |
| end-questions | `collecting`, `asking-user`, `done` |

---

## Watching for State Changes

Use `watchman-wait` to block until the other session updates State.json:

```bash
watchman-wait "$(pwd)/<path-to-protocol-folder>" -p "State.json" --max-events 1 -t 600
```

Run this with `run_in_background: true` so the session stays responsive. When the background task completes, re-read State.json and determine if it's your turn.

If the timeout expires (10 minutes), re-read State.json anyway (the other session may have updated it while watchman-wait was starting up) and restart the watch if still waiting.

---

## File Structure

```
Planning/                              # For dual planners
├── State.json
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
├── State.json
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
