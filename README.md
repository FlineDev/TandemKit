# HarnessKit

Planner / Implementer / Evaluator orchestration harness for Claude Code (and Codex).

> Work in progress. Architecture being designed.

## Concept

HarnessKit coordinates two (or three) parallel sessions for structured implementation and evaluation:

1. **Planning Phase** — Interactive spec creation with acceptance criteria
2. **Execution Phase** — Implementer + Evaluator(s) coordinate via file-based protocol

The evaluator runs in a **separate session** for fresh-perspective review, communicating through structured files in the project's `HarnessKit/` directory.

## License

MIT
