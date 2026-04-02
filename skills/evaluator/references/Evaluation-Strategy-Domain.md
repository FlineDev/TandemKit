# Evaluation Strategy: Domain Systems & Expert Systems

This document guides the evaluator setup and verification approach for domain-specific systems where correctness is judged by reasoning quality, case handling, and consistency — not by UI behavior.

Examples: tax advisors, health coaches, legal analysis tools, financial calculators, recommendation engines, decision support systems.

## What Makes Domain Evaluation Different

In domain systems, "correct" means:
- The system asks the right questions before giving answers
- It handles cases consistently (same input → same reasoning)
- It avoids unjustified certainty
- It doesn't fabricate rules or facts
- It flags missing information instead of guessing
- It handles edge cases and ambiguity explicitly

This is fundamentally different from "does the button work?" — it requires reasoning evaluation, not just functional verification.

## Verification Approach

### Canonical Case Testing

The most effective evaluation method for domain systems. During planning, the Planner (or user) defines canonical test cases:

```markdown
## Case: Freelancer Home Office Deduction

**Input:** "I am self-employed, work from home, and want to know
whether I can deduct my home office."

**Required follow-up questions:**
- What is your annual income?
- Is the room used exclusively for work?
- Do you have another workplace available?

**Expected properties:**
- Asks for missing information before answering
- Does NOT assume deductibility without knowing exclusivity
- References the correct legal basis

**Red flags:**
- Fabricated tax code references
- Giving a definitive answer without asking about room exclusivity
- Claiming certainty about deductibility without knowing income
```

### Consistency Testing

Run the same (or similar) cases multiple times and verify consistent reasoning:
- Same input → same conclusion (deterministic cases)
- Similar inputs with one difference → the reasoning should change in a predictable way
- Contradictory inputs → the system should flag the contradiction

### Edge Case Reasoning

Test cases designed to probe the boundaries:
- Incomplete information — does the system ask for clarification?
- Ambiguous situations — does the system acknowledge ambiguity?
- Rare but valid cases — does the system handle them without defaulting to the common case?
- Invalid inputs — does the system reject them gracefully?

### Negative Testing

Verify the system does NOT:
- Fabricate rules, laws, or facts that don't exist
- Give definitive answers when the situation is ambiguous
- Skip required questions to reach a faster answer
- Contradict its own earlier reasoning
- Show unjustified confidence in uncertain situations

## Evaluation Checklist for Domain Systems

### Always Do
1. **Run all canonical cases** — every defined case must produce the expected behavior
2. **Check for fabricated references** — verify any cited rules, laws, or sources actually exist
3. **Test with incomplete information** — the system should ask for missing data, not guess
4. **Run consistency checks** — same input should produce consistent reasoning
5. **Build and test** — the code must compile and pass its test suite

### When the Mission Involves New Domain Logic
6. **Trace the reasoning path** — can you follow how the system reaches its conclusion?
7. **Verify decision boundaries** — at what point does the answer change? Is it correct?
8. **Check for hallucinated rules** — domain systems are prone to inventing plausible-sounding rules
9. **Test with expert edge cases** — cases that require nuanced domain knowledge

### When the Mission Involves User Interaction
10. **Verify the question flow** — does the system ask questions in a logical order?
11. **Test early termination** — what if the user answers only some questions?
12. **Check information completeness** — does the system gather everything it needs?

### Never Do
- Never mark PASS if the system fabricates domain knowledge
- Never mark PASS if the system skips required follow-up questions
- Never mark PASS if the system gives definitive answers without sufficient information
- Never assume reasoning correctness without tracing the logic

## Case File Format

If the project uses case files for evaluation, they should follow this structure:

```markdown
# Case: [Descriptive Name]

## Input
[What the user says or provides to the system]

## Required Behavior
- [What the system MUST do]
- [Questions it MUST ask]
- [Information it MUST gather]

## Expected Properties
- [Qualities the response should have]
- [Reasoning patterns to look for]

## Red Flags
- [Things that indicate a FAIL if they occur]
- [Fabrication patterns to watch for]

## Verdict Criteria
- PASS if: [specific conditions]
- FAIL if: [specific conditions]
```

## Role File Template

During init, create `HarnessKit/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
Domain system: [specific domain, e.g., tax advisory, health coaching]

## Build & Test
- Build: [build command]
- Test: [test command]

## Domain Verification
- Canonical cases: [location of case files, if any]
- Domain references: [where to verify facts, e.g., tax code, medical guidelines]
- Consistency testing: [how to run the same case multiple times]

## Evaluation Priorities
1. Correctness of domain reasoning
2. Completeness of information gathering
3. Absence of fabricated rules or facts
4. Consistency across similar cases

## Always Do
- Run all canonical cases
- Verify any cited rules or references exist
- Test with incomplete information
- Check for consistency

## Never Do
- Mark PASS if the system fabricates domain knowledge
- Mark PASS if required follow-up questions are skipped
- Mark PASS if the system shows unjustified certainty
- Assume reasoning is correct because it sounds plausible
```
