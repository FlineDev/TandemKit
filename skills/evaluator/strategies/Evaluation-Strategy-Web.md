# Evaluation Strategy: Web Applications

This document guides the evaluator setup and verification approach for web applications (frontend, full-stack, static sites).

## Available Verification Tools

### browser-use CLI (Recommended)

The primary tool for web evaluation. Token-efficient browser automation that lets the evaluator interact with the running app like a real user: navigate pages, click buttons, fill forms, read content, take screenshots.

**Why browser-use over Playwright MCP:**
- `state` output is **10–50× smaller** than Playwright's `browser_snapshot` (only clickable elements, not the full accessibility tree)
- `eval` with targeted JS saves an additional **50–90%** over `state`
- No MCP server configuration needed — runs as a plain CLI command via Bash
- Built-in session management (`--session NAME`) replaces multi-instance reservation systems
- Simpler JS execution: plain DOM JavaScript, no `async (page) => {}` wrapper

**Token comparison (measured):**

| Site | Playwright `snapshot` | browser-use `state` | browser-use `eval` |
|------|-----------------------|--------------------|-------------------|
| Google Maps | ~50,000 chars | 2,380 chars | 339 chars |
| Booking.com | 272,142 chars | 5,744 chars | 1,849 chars |
| Swift Forums | ~60,000 chars | 21,244 chars | 2,061 chars |

**Setup:** browser-use CLI must be installed on the machine. Check with `which browser-use` or aliases `bu`, `browser`, `browseruse`. If not installed, see Installation below.

**Permission check:** The user's `settings.json` (user-level or project-level) must allow Bash commands for `browser-use`. This is satisfied if:
- `Bash(browser-use *)` is explicitly allowed, OR
- `Bash(*)` or `Bash` is allowed (all Bash commands permitted)

If neither is present, recommend adding `"Bash(browser-use *)"` to the `allow` list in settings.json.

#### Installation

```bash
# One-line install (recommended)
curl -fsSL https://browser-use.com/cli/install.sh | bash

# Or via uv (if already installed)
uv pip install browser-use
browser-use install   # installs bundled Chromium
browser-use doctor    # verify installation
```

No separate Playwright or Chromium install required — browser-use bundles its own Chromium.

#### Core Commands

```bash
browser-use open <url>              # navigate to URL (starts daemon automatically)
browser-use state                   # list clickable elements with indices
browser-use click <index>           # click element by index from state
browser-use input <index> "text"    # click element, then type text
browser-use eval "JS code"          # execute JavaScript on the page
browser-use screenshot [path]       # take screenshot
browser-use wait selector "css"     # wait for element to appear
browser-use wait text "string"      # wait for text to appear
browser-use close                   # close browser session
```

#### Key Workflow: Always `state` Before Interacting

```bash
browser-use open http://localhost:3000
browser-use state                    # discover element indices
browser-use click 5                  # click the element at index 5
```

#### Token-Optimized Data Extraction with `eval`

Use `eval` instead of `state` when extracting structured data — saves 50–90% tokens:

```bash
browser-use eval "JSON.stringify(
   Array.from(document.querySelectorAll('[data-testid=\"item\"]'))
      .slice(0, 10)
      .map(el => ({
         title: el.querySelector('h2')?.textContent?.trim()?.substring(0, 80),
         price: el.querySelector('[class*=\"price\"]')?.textContent?.trim(),
         link: el.querySelector('a')?.href
      }))
)"
```

Rules for eval:
- **Always wrap in `JSON.stringify(...)`** for structured data
- **Limit arrays** with `.slice(0, N)` — don't extract 100 items when 10 suffice
- **Truncate text** with `.substring(0, X)` for long content
- **Null-safe access** with `?.textContent?.trim()`

#### Headed Mode (For Login-Protected Pages)

```bash
browser-use --headed open https://site.com/login
# User logs in manually in the visible browser window
# Then continue with headless commands — session stays authenticated
browser-use eval "JSON.stringify({user: document.querySelector('.username')?.textContent})"
browser-use close
```

#### Parallel Sessions (For Multi-Page Verification)

```bash
# Each session gets its own daemon and browser instance
browser-use --session app-test open http://localhost:3000
browser-use --session api-test open http://localhost:3000/api/health
```

#### Console Error Checking

```bash
browser-use eval "JSON.stringify(
   performance.getEntriesByType('resource')
      .filter(r => r.transferSize === 0 && !r.name.includes('data:'))
      .map(r => r.name)
)"
```

For JavaScript errors, inject an error collector early:

```bash
browser-use eval "window.__errors = window.__errors || []; window.addEventListener('error', e => window.__errors.push(e.message))"
# ... interact with the page ...
browser-use eval "JSON.stringify(window.__errors)"
```

### Playwright MCP (Fallback)

If the user prefers Playwright MCP or has it already configured, it remains a viable option. See **`Evaluation-Strategy-Web-Playwright.md`** for the full Playwright-specific setup, commands, and evaluation patterns.

When to use Playwright instead:
- User already has Playwright MCP configured and working
- Specific need for Playwright's accessibility tree (`page.accessibility.snapshot()`)
- User explicitly chooses Playwright after hearing the tradeoffs

### CLI Tools

- `npm test` / `yarn test` / `pnpm test` — run test suites
- `npm run build` — verify production build succeeds
- `npm run lint` — check for code quality issues
- `curl` — test API endpoints directly
- `node` — run scripts for data verification

## Evaluation Checklist for Web Apps

### Always Do
1. **Build the project** — `npm run build` (or equivalent) must succeed
2. **Run the test suite** — test failures are automatic FAILs
3. **Start the dev server** and verify it responds
4. **Navigate to affected pages** via browser-use (`open` + `state`)
5. **Take screenshots** of new or changed UI (`browser-use screenshot`)

### When the Mission Involves UI
6. **Test the interaction flow** — click through the feature end-to-end using `state` → `click` → `input`
7. **Test responsive layout** — use `browser-use eval "document.documentElement.style.width = '375px'"` for mobile, reset for desktop
8. **Check for console errors** — inject error collector, verify no JavaScript errors during normal use
9. **Verify navigation** — all links and buttons lead somewhere sensible
10. **Check loading states** — does the UI handle async content gracefully?

### When the Mission Involves API
11. **Test endpoints directly** with curl
12. **Verify error responses** — invalid input, unauthorized access, not found
13. **Check CORS headers** if the API is accessed cross-origin

### When the Mission Involves Documentation or Content
Not every mission produces code. For documentation/content missions, verify claims against source code and verified test results. Build/test is not required for PASS unless the spec includes code changes.

### Never Do
- Never mark PASS without building (code missions)
- Never mark PASS without running tests (code missions)
- Never mark PASS without source verification (documentation missions)
- Never assume UI works from code alone — use browser-use to verify
- Never skip error scenario testing — check what happens with bad input

## Role File Template

During init, create `HarnessKit/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
Web application ([React/Vue/Svelte/static/full-stack])

## Build & Test
- Build: `npm run build`
- Test: `npm test`
- Dev server: `npm run dev` (port: XXXX)
- Lint: `npm run lint`

## UI Verification Tools
- browser-use CLI for browser interaction and screenshots (recommended — 10–50× fewer tokens than Playwright)
- Playwright MCP as fallback (see Evaluation-Strategy-Web-Playwright.md)
- Dev server at http://localhost:XXXX

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do
- Build the project before evaluating
- Run the test suite
- Start the dev server and verify it responds
- Take screenshots of changed pages via `browser-use screenshot`
- Check for console errors during interaction
- Use `browser-use eval` for structured data extraction (not `state`)

## Never Do
- Mark PASS without a successful build
- Mark PASS without running tests
- Assume UI works without browser verification
```
