# Spec.md Format

The Spec.md is the central artifact of every mission. The Planner creates it, the Generator implements against it, and the Evaluator verifies against it. It must be clear enough that all three roles can do their job without ambiguity.

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

```markdown
## Context & Investigation Findings

### Existing Architecture
- The API currently has no auth (all endpoints are public)
- User model exists at `Sources/Models/User.swift:12` with email and
  password_hash fields but no token-related fields
- Routes are defined in `Sources/Routes/` using the existing middleware
  pattern (see `Sources/Middleware/RateLimiter.swift` for reference)

### Relevant Resources
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/...)
- The project already uses `swift-jwt` (v4.2) as a dependency

### Considerations Explored During Planning
- **RS256 vs HS256**: RS256 enables key rotation without redeployment.
  HS256 simpler but creates key distribution problems later.
- **Token lifetime**: Short JWTs (15min) + long refresh (7 days) balances
  security with UX. Discussed 1h JWT — rejected for security reasons.
```

Always include:
- File paths with line numbers
- Links to external resources
- Tradeoffs that were discussed (not just the winner)
- Related PlanKit features if PlanKit is present

### 4. Acceptance Criteria

Numbered, unambiguous pass/fail statements. The Evaluator checks each one independently. Two independent evaluators must reach the same verdict on each criterion.

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
- Focus on observable behavior, not implementation details
- Don't specify HOW — specify WHAT
- Keep them lean — the Evaluator figures out how to verify
- Number them — the Evaluator references them by number

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

Soft suggestions from the Planner. Non-binding. The Generator can take these or ignore them.

```markdown
## Possible Directions & Ideas

- Consider using the existing `RateLimiter.swift` middleware pattern as
  a template for the auth middleware
- The `swift-jwt` library already in the project supports RS256 natively
- A `TokenService` actor might be a clean way to encapsulate token
  creation/validation/rotation logic

**Suggested milestones for the Generator:**
1. Data model and token service
2. Auth endpoints (login, refresh, logout)
3. Middleware for protected routes
4. Tests
```

## Principles

1. **Constrain deliverables, not implementation** — specify WHAT and WHY, never HOW (unless there's a specific constraint)
2. **Two evaluators must agree on pass/fail** — if criteria are ambiguous enough for disagreement, rewrite them
3. **Include negative cases** — what must NOT happen is as important as what must happen
4. **Investigation findings are rich** — preserve the Planner's work with links, paths, tradeoffs
5. **Spec is immutable during implementation** — user feedback goes to UserFeedback/ files, not spec edits
6. **Prune ruthlessly** — if removing a line would not cause the Generator to make mistakes, remove it
7. **Preserve user's words** — User Intent is exact quotes, Key Decisions note when they changed their mind
