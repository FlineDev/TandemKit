#!/usr/bin/env bash
# TandemKit — setup-codex-skills
# Sets up or repairs ~/.agents/skills/ symlinks so Codex can access TandemKit skills.
#
# Idempotent — safe to run at any time:
#   - If symlinks are missing:       creates them
#   - If symlinks are stale/wrong:   updates them
#   - If everything is up to date:   does nothing (silent)
#
# Uses a version-agnostic 'latest' indirection:
#   ~/.agents/skills/<skill>  →  ~/.claude/plugins/cache/FlineDev/tandemkit/latest/skills/<skill>
#   ~/.claude/.../tandemkit/latest  →  1.0.0  (or whichever version is newest)
#
# This means after a plugin upgrade only 'latest' needs updating —
# the ~/.agents/skills/ symlinks stay valid forever.
#
# Usage (from SKILL.md preflight):
#   bash "${CLAUDE_PLUGIN_ROOT:-${CLAUDE_SKILL_DIR}/../..}/scripts/setup-codex-skills.sh"
#
# Usage (standalone repair):
#   bash ~/.claude/plugins/cache/FlineDev/tandemkit/latest/scripts/setup-codex-skills.sh
#   bash ~/path/to/TandemKit/scripts/setup-codex-skills.sh
#
# Exit 0 = success (with or without changes made)
# Exit 1 = error (plugin not found, symlinks broken after repair)

TANDEM_CACHE="$HOME/.claude/plugins/cache/FlineDev/tandemkit"
SKILLS_DIR="$HOME/.agents/skills"
SKILLS=(planner generator evaluator)
CHANGED=false

# ── 1. Find the current installed version ────────────────────────────────────
# Sort version directories by version number; pick the newest.
# Excludes the 'latest' symlink itself.
CURRENT_VER=$(ls "$TANDEM_CACHE" 2>/dev/null | grep -v '^latest$' | sort -V | tail -1)
if [[ -z "$CURRENT_VER" ]]; then
    echo "ERROR: TandemKit plugin not found at $TANDEM_CACHE" >&2
    echo "       Install the TandemKit plugin first, then re-run." >&2
    exit 1
fi

# ── 2. Keep 'latest' pointing at the newest version ──────────────────────────
LATEST_LINK="$TANDEM_CACHE/latest"
CURRENT_TARGET=$(readlink "$LATEST_LINK" 2>/dev/null || echo "")
if [[ "$CURRENT_TARGET" != "$CURRENT_VER" ]]; then
    ln -sf "$CURRENT_VER" "$LATEST_LINK"
    if [[ -n "$CURRENT_TARGET" ]]; then
        echo "Updated:  tandemkit/latest → $CURRENT_VER  (was: $CURRENT_TARGET)"
    else
        echo "Created:  tandemkit/latest → $CURRENT_VER"
    fi
    CHANGED=true
fi

# ── 3. Ensure ~/.agents/skills/ exists ───────────────────────────────────────
mkdir -p "$SKILLS_DIR"

# ── 4. Check/repair each skill symlink ───────────────────────────────────────
EXPECTED_BASE="$TANDEM_CACHE/latest/skills"
for skill in "${SKILLS[@]}"; do
    LINK="$SKILLS_DIR/$skill"
    EXPECTED_TARGET="$EXPECTED_BASE/$skill"
    CURRENT_LINK_TARGET=$(readlink "$LINK" 2>/dev/null || echo "")

    # Up to date: correct target AND SKILL.md resolves → nothing to do
    if [[ "$CURRENT_LINK_TARGET" == "$EXPECTED_TARGET" && -f "$LINK/SKILL.md" ]]; then
        continue
    fi

    rm -f "$LINK"
    ln -s "$EXPECTED_TARGET" "$LINK"

    if [[ -n "$CURRENT_LINK_TARGET" ]]; then
        echo "Updated:  ~/.agents/skills/$skill → ...latest/skills/$skill  (was: $CURRENT_LINK_TARGET)"
    else
        echo "Created:  ~/.agents/skills/$skill → ...latest/skills/$skill"
    fi
    CHANGED=true
done

# ── 5. Verify all symlinks actually resolve ───────────────────────────────────
BROKEN=()
for skill in "${SKILLS[@]}"; do
    [[ ! -f "$SKILLS_DIR/$skill/SKILL.md" ]] && BROKEN+=("$skill")
done
if [[ ${#BROKEN[@]} -gt 0 ]]; then
    echo "ERROR: The following skill symlinks do not resolve after repair: ${BROKEN[*]}" >&2
    echo "       Verify TandemKit is properly installed at $TANDEM_CACHE" >&2
    exit 1
fi

# ── 6. Done — silent when nothing changed ────────────────────────────────────
# (intentionally no output when CHANGED=false)
exit 0
