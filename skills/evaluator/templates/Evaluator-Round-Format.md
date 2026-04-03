# Evaluator Round Report Format

```markdown
# Evaluation Report — Round NN

**Verdict: PASS / PASS_WITH_GAPS / FAIL / BLOCKED**

## Mandatory Checks
- Build: PASS / FAIL — [details]
- Tests: PASS / FAIL — [N passed, M failed]

## Acceptance Criteria Results

### 1. [Criterion text from spec]
**Verdict: PASS / FAIL / BLOCKED**
Evidence: [What you observed, how you verified]

## Edge Cases & Boundaries
- [Edge case]: PASS / FAIL — [evidence]

## User Feedback Points (if applicable)
- [Point]: Addressed / Not addressed — [evidence]

## Issues Found (Not in Spec)
- [Issue]: [Severity], [Reproduction], [Suggestion]

## What Works Well
[Positive observations]

## Suggestions (Non-Blocking)
[Improvements that don't block PASS]
```
