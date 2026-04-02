# Self-Learning — Automatic Documentation of Learnings

HarnessKit sessions continuously improve by documenting what they learn. This happens automatically — no need to ask the user for role-file updates.

## What To Document

- **Build/test commands** that work (or don't) for this project
- **Tools that are effective** (or broken/unreliable) — e.g., "mobile-mcp hangs on Xcode 26, use ExecuteSnippet instead"
- **Workarounds** for broken tools or infrastructure
- **User corrections** — if the user corrects your approach, document it so it's never repeated. Highest priority.
- **Evaluation approaches** that proved effective — e.g., "ExecuteSnippet with batch test cases is effective for algorithm verification"
- **Project conventions** discovered during investigation that weren't documented before
- **Repeated user feedback patterns** — if the user gives similar feedback multiple times, it's a persistent preference
- **Evaluation depth failures** — if the user notes that verification was too shallow, document the specific deeper checks that should have been done, so future evaluations don't repeat the mistake

## Where To Document

| Learning Type | Where | Ask User? |
|---|---|---|
| Evaluator-specific (tools, verification approaches, what to always check) | `HarnessKit/Evaluator.md` | No — update automatically |
| Generator-specific (build conventions, commit patterns, code style) | `HarnessKit/Generator.md` | No — update automatically |
| Planner-specific (investigation patterns, question strategies) | `HarnessKit/Planner.md` | No — update automatically |
| Project-wide (benefits sessions NOT using HarnessKit too) | `AGENTS.md` | **Yes — explain why and ask first** |

**Heuristic for AGENTS.md vs role files:** If a future session that is NOT using HarnessKit would benefit from knowing this, it belongs in AGENTS.md. If it only matters during HarnessKit missions, it belongs in the role file.

## How To Document

Append learnings to a `## Learnings` section at the bottom of the relevant role file. Use YYYY-MM-DD date format:

```markdown
## Learnings

- **2026-04-01 Tool:** mobile-mcp hangs indefinitely on Xcode 26. Use Xcode MCP ExecuteSnippet for runtime verification instead.
- **2026-04-01 User Feedback:** User wants runtime verification for ALL algorithm changes, not just UI changes. Code review alone is never sufficient.
```

**Before appending:** Check if a similar learning already exists. Update the existing entry rather than creating a duplicate.

## When To Document

Write learnings **after** writing your round report/verdict **and after** updating State.json. Learning documentation is a non-blocking post-processing step — the other session can proceed while you document.

- **After each round** — if you discovered effective techniques or tools that failed
- **After user feedback** — especially corrections to approach or style (highest priority)
- **After tool failures** — document what broke and what worked instead
- **After discovering undocumented project conventions** — save them for future sessions

## Maintenance

Periodically review the `## Learnings` section:
- **Consolidate** established patterns into the main body of the role file (e.g., an effective build command moves to the "Build & Test" section)
- **Remove** learnings that are no longer relevant (e.g., tool bugs that were fixed)
- **Deduplicate** similar entries

## AGENTS.md Updates (Require User Approval)

If you discover something that benefits the project beyond HarnessKit:
1. Explain in chat what you learned and why you think it belongs in AGENTS.md
2. Ask: "I noticed [X]. Should I add this to AGENTS.md, or would you prefer it in HarnessKit/[Role].md?"
3. Only edit AGENTS.md after explicit approval
