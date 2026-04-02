#!/bin/zsh
set -euo pipefail

# HarnessKit — render-secondary-prompt
# Generates a minimal, fixed-template Codex B prompt.
# No improvisation, no file writes.
#
# Usage: render-secondary-prompt.sh <role> <mission-name> <conversation-folder> <user-goal>
#   role:                 planner or evaluator
#   mission-name:         e.g., 001-ActivityToolsSkill
#   conversation-folder:  relative path from project root
#   user-goal:            the user's original task description
#
# Output: the prompt text to stdout + clipboard (if pbcopy available)

ROLE="$1"
MISSION="$2"
CONV_FOLDER="$3"
USER_GOAL="$4"

if [[ "$ROLE" != "planner" && "$ROLE" != "evaluator" ]]; then
  echo "ERROR: Role must be planner or evaluator, got: $ROLE" >&2
  exit 1
fi

# Capitalize role for display
ROLE_DISPLAY=$( [[ "$ROLE" == "planner" ]] && echo "Planner" || echo "Evaluator" )

# Fixed template — no improvisation
PROMPT="You are ${ROLE_DISPLAY} B for HarnessKit mission ${MISSION}.
Conversation folder: ${CONV_FOLDER}

${USER_GOAL}"

# Output to stdout
echo "$PROMPT"

# Copy to clipboard if pbcopy is available
if command -v pbcopy &>/dev/null; then
  echo "$PROMPT" | pbcopy
  echo "" >&2
  echo "✓ Copied to clipboard" >&2
fi
