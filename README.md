# HarnessKit

Multi-session Planner/Generator/Evaluator orchestration for Claude Code with Codex as a built-in second opinion.

## How It Works

Three Claude Code sessions collaborate on a mission. The Planner and Evaluator internally invoke Codex via the `codex-plugin-cc` plugin for independent verification. The Generator implements alone.

```
Planner (Claude + Codex) → Spec.md
Generator (Claude)       → implements against Spec.md
Evaluator (Claude + Codex) → verifies, provides feedback → Generator loops until PASS
```

## Prerequisites

- Claude Code with the `codex-plugin-cc` plugin installed
- Codex CLI authenticated (`/codex:setup` to verify)
- HarnessKit initialized in the project (role files in `HarnessKit/`)

## Quick Start

```bash
# 1. Start a Planner session
/planner Add JWT authentication with refresh tokens

# 2. After spec is approved, start Generator and Evaluator
#    (Planner shows the exact commands to copy)

# 3. Generator and Evaluator work autonomously until PASS
#    User reviews the final result
```

## Architecture

See [REWORK.md](REWORK.md) for the full v2 design, including the Convergence Protocol, severity system, and detailed flow diagrams.

## Project Structure

```
HarnessKit/
├── scripts/
│   ├── create-mission.sh            # Scaffold new mission folder
│   └── wait-for-state.sh            # Generator↔Evaluator coordination
├── skills/
│   ├── planner/
│   │   ├── SKILL.md                 # Planning + Codex convergence
│   │   └── templates/Spec-Format.md
│   ├── generator/
│   │   ├── SKILL.md                 # Implementation loop
│   │   └── templates/
│   │       ├── Generator-Round-Format.md
│   │       └── Summary-Format.md
│   └── evaluator/
│       ├── SKILL.md                 # Evaluation + Codex convergence
│       ├── templates/Evaluator-Round-Format.md
│       └── strategies/
│           ├── Evaluation-Strategy-ApplePlatform.md
│           ├── Evaluation-Strategy-CLI.md
│           ├── Evaluation-Strategy-Domain.md
│           └── Evaluation-Strategy-Web.md
├── system-prompts/
│   └── claude-evaluator.md          # Hardened evaluator system prompt
└── commands/
    └── init.md                      # Project initialization (legacy/distribution)
```

## Development Setup (Symlinks)

For local development, symlink the skills directly:

```bash
# Claude Code (user-level — works in all projects)
ln -sf /path/to/HarnessKit/skills/planner ~/.claude/skills/planner
ln -sf /path/to/HarnessKit/skills/generator ~/.claude/skills/generator
ln -sf /path/to/HarnessKit/skills/evaluator ~/.claude/skills/evaluator

# Codex (user-level)
mkdir -p ~/.codex/skills
ln -sf /path/to/HarnessKit/skills/planner ~/.codex/skills/planner
ln -sf /path/to/HarnessKit/skills/generator ~/.codex/skills/generator
ln -sf /path/to/HarnessKit/skills/evaluator ~/.codex/skills/evaluator
```

## License

MIT
