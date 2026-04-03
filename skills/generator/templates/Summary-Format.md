# Summary.md Format

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

## Evaluator Findings Addressed
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
