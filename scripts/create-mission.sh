#!/usr/bin/env bash
set -euo pipefail

# Self-heal the 'latest' symlink so it always points at the newest installed version.
_TC="$HOME/.claude/plugins/cache/FlineDev/tandemkit"
_NV=$(ls "$_TC" 2>/dev/null | grep -v '^latest$' | sort -V | tail -1)
[[ -n "$_NV" ]] && ln -sf "$_NV" "$_TC/latest" 2>/dev/null
unset _TC _NV

# TandemKit — create-mission
# Scaffolds a new mission folder with State.json and updates Config.json.
# Must be run from the project root (where TandemKit/ lives).
#
# Usage: create-mission.sh <mission-name>
#   mission-name:  e.g., 003-DebugActivityTool
#
# Exit 0 = success. Exit 1 = error.

if [[ $# -ne 1 ]]; then
   echo "Usage: create-mission.sh <mission-name>" >&2
   exit 1
fi

MISSION_NAME="$1"

# --- Validation ---

if [[ -z "$MISSION_NAME" ]]; then
   echo "ERROR: Mission name cannot be empty" >&2
   exit 1
fi

if [[ ! "$MISSION_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
   echo "ERROR: Mission name must only contain letters, digits, and hyphens: $MISSION_NAME" >&2
   exit 1
fi

CONFIG="./TandemKit/Config.json"
if [[ ! -f "$CONFIG" ]]; then
   echo "ERROR: TandemKit/Config.json not found. Run from the project root or run init first." >&2
   exit 1
fi

# Check currentMission is null
CURRENT=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('currentMission') or '')" 2>/dev/null)
if [[ -n "$CURRENT" ]]; then
   echo "ERROR: A mission is already active: $CURRENT" >&2
   echo "Complete or abort it before starting a new one." >&2
   exit 1
fi

# Validate mission name prefix matches nextMissionNumber
NEXT_NUM=$(python3 -c "import json; print(json.load(open('$CONFIG')).get('nextMissionNumber', 1))" 2>/dev/null)
EXPECTED_PREFIX=$(printf "%03d-" "$NEXT_NUM")
if [[ "$MISSION_NAME" != "$EXPECTED_PREFIX"* ]]; then
   echo "ERROR: Mission name must start with '$EXPECTED_PREFIX' (nextMissionNumber=$NEXT_NUM), got: $MISSION_NAME" >&2
   exit 1
fi

MISSION_DIR="./TandemKit/$MISSION_NAME"
if [[ -d "$MISSION_DIR" ]]; then
   echo "ERROR: Mission directory already exists: $MISSION_DIR" >&2
   exit 1
fi

# --- Create files ---

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$MISSION_DIR"
mkdir -p "$MISSION_DIR/Planner-Discussion"

cat > "$MISSION_DIR/State.json" << EOF
{
  "phase": "planning",
  "round": 0,
  "generatorStatus": null,
  "evaluatorStatus": null,
  "verdict": null,
  "userFeedbackRounds": 0,
  "started": "$NOW",
  "updated": "$NOW"
}
EOF

# --- Update Config.json atomically ---

NEW_NEXT=$((NEXT_NUM + 1))
TEMP_CONFIG=$(mktemp)

MISSION_NAME="$MISSION_NAME" NEW_NEXT="$NEW_NEXT" python3 -c "
import json, os
with open('$CONFIG') as f:
   config = json.load(f)
config['currentMission'] = os.environ['MISSION_NAME']
config['nextMissionNumber'] = int(os.environ['NEW_NEXT'])
with open('$TEMP_CONFIG', 'w') as f:
   json.dump(config, f, indent=2, ensure_ascii=False)
   f.write('\n')
" 2>/dev/null

mv "$TEMP_CONFIG" "$CONFIG"

# --- Output ---

echo ""
echo "✓ Created mission: $MISSION_NAME"
echo "  TandemKit/$MISSION_NAME/State.json"
echo "  TandemKit/$MISSION_NAME/Planner-Discussion/"
echo "  Config.json: currentMission=$MISSION_NAME, nextMissionNumber=$NEW_NEXT"
echo ""
echo "MISSION_CREATED: $MISSION_NAME"
