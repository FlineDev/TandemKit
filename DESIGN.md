# HarnessKit — Architecture

> **Current design:** See [REWORK.md](REWORK.md) for the full v2 architecture.

## Core Concept

Three specialized roles collaborate on missions:

| Role | Model | Purpose |
|---|---|---|
| **Planner** | Claude + Codex | Investigate, plan, produce Spec.md |
| **Generator** | Claude only | Implement against Spec.md |
| **Evaluator** | Claude + Codex | Verify against Spec.md, provide feedback |

The Planner and Evaluator use the **Convergence Protocol** — Claude and Codex independently investigate, then iteratively converge through structured back-and-forth with severity-based agreement (high/medium/low disagreements → APPROVED when no high/medium remain).

## Key Design Decisions

### Always dual-model (Claude + Codex)

There is no single-model mode. HarnessKit requires both models. Different models catch different things — Codex found real bugs that Claude missed in Missions 001 and 002. If Codex is unavailable, the session blocks until it's fixed.

### Codex runs inside Claude sessions (not as separate sessions)

v1 used manual dual sessions (Claude A + Codex B in separate terminals). This was fragile — Codex stopped watching, dropped protocol, needed manual nudging. v2 uses the `codex-plugin-cc` plugin: Claude invokes Codex via `/codex:rescue` and gets results back within the same session.

### Three persistent contexts per mission

One Claude Planner session, one Claude Generator session, one Claude Evaluator session (with one persistent Codex thread). We do NOT start fresh Codex threads per evaluation round — context accumulation is valuable, and "fresh eyes" comes from two different models, not context amnesia.

### Generator does not use Codex

The Generator implements faithfully. The Evaluator (with Codex) catches issues. Adding Codex to the Generator would slow implementation for marginal benefit.

### User is present during planning, absent during execution

The Planner phase is interactive — the user answers questions between rounds. The Generator↔Evaluator phase is fully autonomous — the user reviews only at the end (Review Briefing).

### File-based coordination between Generator and Evaluator

State.json remains the cross-session signaling mechanism. The Generator signals `ready-for-eval`, the Evaluator signals `done` with a verdict. Round-aware waiting (`--round N`) prevents stale-signal false triggers.

### Severity-based convergence, not numeric scores

Codex reviews use high/medium/low disagreements with an APPROVED/NOT APPROVED gate. This is more precise than a blended 1-10 score (which can hide criterion failures behind a good average). An optional non-gating qualityScore (1-10) is available for trend tracking.

### Re-investigation rule

When Claude and Codex disagree on a point, both MUST re-read the relevant source files before responding. This prevents circular disagreements and helps discover who's actually right.

## Mission Lifecycle

```
/planner → investigation → Codex convergence → user approval → Spec.md
                                                                   ↓
/generator → implement milestone → signal evaluator ──────────────→↓
                ↑                                                  ↓
                └──── fix ←── FAIL ←── evaluation ←── /evaluator ←─┘
                                          ↓
                                       PASS → Review Briefing → user approval → done
```

## File Structure

See [REWORK.md — Complete Sample File Tree](REWORK.md#complete-sample-file-tree-theoretical-mission) for the full artifact layout.

## Scripts

| Script | Purpose |
|---|---|
| `create-mission.sh` | Scaffold mission folder + State.json + update Config.json |
| `wait-for-state.sh` | Block until State.json field matches value (with `--round N` for exact round matching) |

## History

- **v1** (March-April 2026): Manual dual sessions with file-based coordination (Status-A/B.json, Coordination.json, wait-for-turn.sh, signal-step.sh). Worked but fragile — Codex sessions stopped watching, dropped protocol, needed user intervention.
- **v2** (April 2026): Codex plugin integration. Single sessions with internal Codex invocation. Convergence Protocol replaces dual-session protocol. Deleted: wait-for-turn.sh, signal-step.sh, render-secondary-prompt.sh, Dual-Session-Protocol.md.
