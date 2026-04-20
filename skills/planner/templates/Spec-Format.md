# Spec.md Format

The Spec.md is the central artifact of every mission. The Planner creates it, the Generator implements against it, and the Evaluator verifies against it. It must be clear enough that all three roles can do their job without ambiguity.

## The One Rule (read this first)

**The spec is REQUIREMENTS (WHAT and WHY), not implementation (HOW).** The Generator reads the spec AND the codebase, loads relevant skills, and decides HOW. Your job is to specify WHAT must be true when they're done — not to write the code for them.

This rule is the difference between a 100-line spec the Generator can execute against with judgment, and a 700-line spec that locks in your guesses and turns the Evaluator into a code-style checker. **A pre-written implementation in the spec becomes a contract** — the Generator will copy it verbatim and the Evaluator will check it byte-for-byte. If your implementation is wrong, the spec becomes a trap.

### What the spec MUST NOT contain

1. **No "Implementation Sketch" / "Code Examples" / "Reference Implementation" section.** These act as contracts even when labelled as drafts. If you find yourself writing one, stop and convert each idea into either an acceptance criterion (observable outcome) or a one-line note in §6 Key Decisions.
2. **No complete code blocks** — no full function bodies, full type definitions, full file contents. A 1–5 line snippet that pins down an exact API contract or shows a tricky edge case is fine. A 20-line block of "here's how the function should look" is not.
3. **No step-by-step implementation procedures.** "First call `foo()`, then construct `Bar`, then call `baz()` inside a `try` block" is HOW. Replace with WHAT: "the operation must be atomic and respect existing exclusion rules" — and let the Generator find the call sequence by reading the file you pointed to.
4. **No transcribed file contents.** If `auth_handler.py:42-78` is relevant, write that path and one sentence about WHY. Don't paste the 50 lines into the spec — the Generator will read the file.
5. **No "Style Guide Reminder" / "Skills to Load" / "Generator MUST..." sections as mandates.** Role-specific *instructions* belong in `TandemKit/Generator.md`, not the spec. The spec is mission-specific; role files are role-specific. **Allowed exception — non-binding suggestions:** skill names and reference files that may be relevant MAY appear in §8 "Possible Directions & Ideas" (or a similarly-named "Context the Generator Might Find Useful" section), provided they are clearly framed as starting points the Generator can ignore. The distinction is mandate vs. suggestion: *"The Generator MUST load `<style-guide-skill>`"* is a mandate (banned in the spec body). *"`<style-guide-skill>` is worth considering when writing the <relevant feature>"* in a non-binding section is a suggestion (allowed). Whatever example skill names appear in this template are illustrative placeholders — actual skills vary by project. The binding WHAT/WHY stays in Acceptance Criteria + Scope; skill and file hints stay explicitly non-binding.
6. **No acceptance criteria that prescribe implementation order or specific function calls.** ACs are about observable outcomes. (See §4 below for examples.)

### When implementation detail IS acceptable (rare exceptions)

- **A brief pseudocode block** for genuinely complex algorithms where a Generator without prior context could plausibly get the logic wrong. Label it "Pseudocode (illustrative)" so it's clearly not the implementation contract. Keep it under ~10 lines.
- **A 1–3 line API signature constraint** when an exact contract must be honored: "must be implemented as `static func parse(_:) -> Result<X, E>` (consumed by `Y.swift:42`)".
- **A short snippet showing a tricky edge case** the Generator might miss: "the date guard rejects `>= 2025-01-01 local`, NOT `> 2025-01-01`" with a 2-line example.

When in doubt: leave it out. Trust the Generator + the codebase + the skills they load.

### The "is this WHAT or HOW?" test

For any sentence in your spec, ask: **"If the Generator implemented this requirement using a totally different code path that still satisfies every acceptance criterion, would I object?"**

- **Yes** → you're prescribing HOW. Trim or convert to an observable outcome.
- **No** → it's requirement-level (WHAT/WHY). Keep it.

## Mission Type

Every Spec.md should declare its mission type near the top. This guides the Evaluator's verification path:

```markdown
**Mission Type:** code | documentation | domain | mixed
```

- **code** — the mission produces code changes. Evaluator: build, test, preview, runtime verification.
- **documentation** — the mission produces skill files, docs, or reference material. Evaluator: verify claims against source code, test results, and authoritative sources. Build/test is NOT required for PASS.
- **domain** — the mission involves domain-specific content (tax rules, knowledge bases). Evaluator: verify against primary sources, canonical cases, consistency checks.
- **mixed** — both code and content. Evaluator: apply both code and content verification paths.

## Required Sections

### 1. User Intent

The user's exact words (typo/grammar-corrected), preserved as blockquotes. Include all follow-up answers and clarifications. When the user changed their mind during planning, document both positions:

```markdown
## User Intent

> I want to add authentication to the API. Users should be able to log in
> with email and password, get a token, and stay logged in for a while
> without having to re-enter credentials constantly. It should be secure.

> [After discussion about token storage] Yeah, refresh tokens sound right.
> I don't need OAuth or social login for now, just email/password. And
> definitely HttpOnly cookies, not localStorage.
```

**Why this matters:** The user's original phrasing captures intent that gets lost in formal specification. When the Evaluator or Generator faces an ambiguous decision, the user's own words provide grounding. When the user changed their mind, documenting both positions prevents future confusion about why a decision was made.

### 2. Goal

One clear paragraph summarizing what we're building/fixing and why. This is NOT a copy of User Intent — it's a distilled, clarified version. Written so the Evaluator can understand the purpose without deep codebase knowledge.

```markdown
## Goal

Implement JWT-based authentication with refresh token rotation for the
existing FastAPI backend. Users authenticate with email/password and
receive short-lived JWTs with long-lived refresh tokens for seamless
session continuity.
```

### 3. Context & Investigation Findings

The Planner's actual findings from investigating the codebase. This section is rich — it preserves the Planner's investigation work so the Generator doesn't have to redo it.

**Reference, do NOT transcribe.** Point at relevant files with paths and line numbers, then explain in 1–3 sentences WHY they matter. Do not paste their contents into the spec. The Generator will read the files you point to.

```markdown
## Context & Investigation Findings

### Existing Architecture
- The API currently has no auth (all endpoints are public)
- User model: `Sources/Models/User.swift:12` — has `email` and `password_hash`
  fields but no token-related fields (the Generator will need to add those)
- Existing middleware pattern: `Sources/Middleware/RateLimiter.swift` —
  shows the request-handler convention; the new auth middleware should follow
  the same shape

### Relevant Resources
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/...)
- The project already uses `swift-jwt` (v4.2) as a dependency

### Considerations Explored During Planning
- **RS256 vs HS256**: RS256 enables key rotation without redeployment.
  HS256 simpler but creates key distribution problems later. → Decided RS256
  (see §6 Key Decisions).
- **Token lifetime**: Short JWTs (15min) + long refresh (7 days) balances
  security with UX. Discussed 1h JWT — rejected for security reasons.
```

Always include:
- File paths with line numbers — as **references**, not transcriptions
- One-line explanations of WHY each reference matters
- Links to external resources
- Tradeoffs that were discussed (not just the winner)
- Related PlanKit features if PlanKit is present

**Anti-pattern (do NOT do this):**

```markdown
### Existing Architecture

The User model looks like this (`Sources/Models/User.swift`):

\`\`\`swift
struct User {
    let id: UUID
    let email: String
    let passwordHash: String
    // ... 30 more lines transcribed verbatim ...
}
\`\`\`
```

Instead, write: "User model: `Sources/Models/User.swift:12` — has `email` and `password_hash` fields, no token-related fields yet." One sentence, one path. The Generator can read the file.

### 4. Acceptance Criteria

Numbered, unambiguous pass/fail statements describing **observable outcomes** (what's true after the work is done). The Evaluator checks each one independently. Two independent evaluators must reach the same verdict on each criterion.

```markdown
## Acceptance Criteria

1. Users can authenticate with email + password and receive a JWT
2. JWTs expire after 15 minutes
3. Refresh tokens enable obtaining new JWTs without re-authentication
4. Refresh tokens are delivered via HttpOnly secure cookies
5. Expired or invalid tokens produce clear 401 responses
6. All existing public endpoints continue to work without auth
7. Protected routes reject requests without valid JWTs
8. Auth-related functionality has test coverage
```

**Rules for acceptance criteria:**
- Each must be unambiguously pass/fail — no subjective language
- Focus on **observable behavior**, not implementation details
- **Don't specify HOW — specify WHAT**
- Keep them lean — the Evaluator figures out how to verify
- Number them — the Evaluator references them by number

**Good vs Bad examples:**

| ✅ Good (observable outcome) | ❌ Bad (and why) |
|---|---|
| "Invalid credentials produce a 401 response" | "The login handler should call `validatePassword()` then return `Response(.unauthorized)` on failure" — prescribes implementation |
| "New entries are visible to existing read endpoints and respect user filters" | "Handler, in order: (a) opens a transaction, (b) calls `validateInput()`, (c) constructs context, (d) invokes `processOrder()`, (e) commits" — this is HOW disguised as a checklist |
| "Order processing is atomic (rolled back on any failure)" | "The new database call is enclosed in a `with transaction.atomic():` block" — locks in exact source-level form |
| "Build succeeds in both debug and release configurations, and the feature is disabled in release builds" | "All references to the new module are wrapped in `#ifdef DEBUG ... #endif` blocks" — prescribes the gating mechanism |
| "Functions are no longer than 50 lines" | "The code should be clean" — subjective |
| "Response time under 200ms for the p95 case" | "Performance should be good" — unmeasurable |

**The two-evaluator test:** could two independent evaluators reach the same verdict on this criterion without consulting each other or the spec author? If no, the criterion is ambiguous — rewrite it.

**The HOW-vs-WHAT test:** if the Generator implemented the criterion using a completely different code path that still satisfies it, would you object? If yes → you're prescribing HOW. Convert it to an observable outcome.

### 5. Edge Cases & Boundaries

Non-obvious cases with expected behavior. Separate from acceptance criteria because these are supplementary verification points.

```markdown
## Edge Cases & Boundaries

- Concurrent refresh requests with the same token should not cause errors
- A user changing their password should invalidate all existing refresh tokens
- Malformed JWTs (not just expired) should return 401, not 500
- An empty email or password field should return 400 with a clear message
```

Include negative cases: "must NOT do X when Y."

### 6. Key Decisions

Decisions made during planning with rationale. When the user changed their mind, document both positions.

```markdown
## Key Decisions

- **RS256 over HS256** — enables future key rotation for multi-service setup
- **HttpOnly cookies for refresh tokens** — prevents XSS-based token theft
  (user originally considered localStorage, switched after discussing
  XSS risks: "Yeah, definitely HttpOnly cookies, not localStorage.")
- **15min JWT / 7-day refresh** — user confirmed this balance
```

### 7. Out of Scope

Explicit boundaries. The Generator must NOT implement these. The Evaluator must NOT flag their absence.

```markdown
## Out of Scope

- OAuth2 / social login (user: "just email/password for now")
- Token revocation admin UI
- Multi-device session management
- Rate limiting on auth endpoints (already handled by existing middleware)
```

### 8. Possible Directions & Ideas (Optional)

Soft suggestions from the Planner. Non-binding. The Generator can take these or ignore them. This is also the right place for **skill hints** and **reference files** — content that doesn't fit as a requirement but would save the Generator time if surfaced. Frame everything as "worth considering", not "must do".

Typical contents (all optional, all non-binding — use whichever sub-headings fit the mission):
- **Skills worth considering** — name the style-guide, testing, or domain skills that exist in this project and may help. The Generator decides whether to load them. Actual skill names depend on the project.
- **Files and folders worth reading** — documentation, prior missions, adjacent patterns.
- **Protocol or RFC references** — when the spec references a standard, point at it.
- **Tactical hints** — possible implementation directions, testing approaches, edge cases to be aware of.
- **Naming notes** — suggestions for tool names, branch names, enum values, with alternatives when any is fine.
- **Suggested milestones** — a possible implementation sequence.

Example — in a hypothetical auth-API mission:

```markdown
## Possible Directions & Ideas

**Skills worth considering**
- `<testing-skill-name>` — patterns for the test suite
- `<api-style-skill-name>` — HTTP handler conventions
(replace with the skills that actually exist in your project)

**Files worth reading**
- `Sources/Middleware/RateLimiter.swift` — reference pattern for the new middleware
- `Documentation/Toolbox.md` — reusable solutions

**Tactical hints**
- The `swift-jwt` library already in the project supports RS256 natively
- A `TokenService` actor might cleanly encapsulate token lifecycle

**Suggested milestones for the Generator:**
1. Data model and token service
2. Auth endpoints (login, refresh, logout)
3. Middleware for protected routes
4. Tests
```

**Key framing**: every item in this section is a starting point. If the Generator finds a better approach by reading the codebase, taking that better approach is not a spec violation — the binding content is only what's in Acceptance Criteria, Scope, and Edge Cases. Skill names shown in examples above are placeholders; actual skill names depend on what exists in the project's `.claude/skills/` directory.

## Principles

1. **Constrain deliverables, not implementation** — specify WHAT and WHY, never HOW. Re-read "The One Rule" at the top of this file before drafting any section.
2. **Detail UX richly, stay quiet on HOW** — UX/user-side requirements (what works, what error messages users see, what edge cases must be handled, what regressions to avoid, what side effects to watch for) should be detailed. Implementation should be minimal — ideally not present.
3. **References, not transcriptions** — file paths and line numbers as pointers, NOT as code blocks. The Generator reads the file you point to.
4. **Two evaluators must agree on pass/fail** — if criteria are ambiguous enough for disagreement, rewrite them. Apply the two-evaluator test from §4.
5. **Include negative cases** — what must NOT happen is as important as what must happen.
6. **Spec is immutable during implementation** — the Generator and Evaluator work against a locked spec. User feedback goes to UserFeedback/ files. Exception: the user may direct spec corrections (naming fixes, typos) if they explicitly request it. Document any spec edits in the current round's report.
7. **Prune ruthlessly** — if removing a line would not cause the Generator to make mistakes, remove it. If you find yourself writing an "Implementation Sketch" section, delete it entirely.
8. **Preserve user's words** — User Intent is exact quotes; Key Decisions note when the user changed their mind.

## Spec Length Sanity Check

Most well-scoped missions produce specs in the **150–400 line** range. If your spec is approaching 600+ lines and the mission isn't unusually large, **you are almost certainly over-specifying implementation**. Common culprits:

- An "Implementation Sketch" section (delete it entirely)
- Acceptance criteria that prescribe call sequences (rewrite as observable outcomes)
- Transcribed file contents in the Context section (replace with file path + 1 sentence)
- A "Style Guide" or mandatory "Skills to Load" section in the spec body (delete — that belongs in `TandemKit/Generator.md`, not the spec). Non-binding skill/file *suggestions* are fine in §8 "Possible Directions & Ideas" — the distinction is mandate vs. suggestion, not whether skills can be mentioned at all.

Before finalizing: scan your spec for any code block > 5 lines. For each one, ask "could the Generator have written this themselves after reading the codebase?" If yes — delete it.
