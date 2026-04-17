# TandemKit — Agent Instructions

This file applies to AI agents working in the TandemKit plugin repo.

## Cutting a release

Releases of TandemKit are **three coupled actions**. Never do any of them in isolation — and in particular, do **not** bump `plugin.json` unless you are cutting a release in the same commit.

A release consists of:

1. **Bump `.claude-plugin/plugin.json` `version`** to the new release number.
2. **Create a git tag** at that commit, named with the bare version — e.g. `1.0.8`. **No `v` prefix.** All historical tags follow this convention; do not introduce a `v` prefix.
3. **Create a GitHub release** with the same name and tag (no `v` prefix in either).

If any of these three is missing or inconsistent, the release is broken. Regular commits between releases must leave `plugin.json` untouched.

### Picking the version

Standard SemVer:

- **Patch (X.Y.**Z**)** — bug fixes, doc polish, small DX tweaks that don't change how the plugin is used.
- **Minor (X.**Y**.0)** — new features, new skills, new strategies, new flags. Existing workflows keep working.
- **Major (**X**.0.0)** — breaking changes: removed skills, renamed commands, changed mission-folder schema, etc.

### Writing release notes — match the past

Before writing release notes, read the **most recent releases of the same type** to match tone, structure, and depth. `gh release view <tag> -R FlineDev/TandemKit` is the fastest way.

| Releasing | Read these past releases first |
|---|---|
| Patch | The last **three** patch releases |
| Minor | The last **two or three** minor releases |
| Major | **All** past major releases |

The goal is consistency across the changelog, not novelty. If you have a good reason to break style (e.g. a release that genuinely needs a different format — a security advisory, a big migration guide), that's fine, but the default is to match.

## Markdown style

**Never insert mid-sentence line breaks in Markdown.** One paragraph = one line. Do not hard-wrap prose at 72/80/any column.

Why: mid-sentence line breaks make edits painful (every word change shifts the wrapping), they render inconsistently across viewers, and the diff hides what actually changed. Let the editor or the viewer wrap.

This applies to every `.md` file in the repo — skills, strategies, templates, README, AGENTS.md itself. Code blocks and lists are not prose and follow their own layout; this rule is specifically about paragraph text.

If you see wrapped paragraphs in existing files, unwrap them when you touch that section.
