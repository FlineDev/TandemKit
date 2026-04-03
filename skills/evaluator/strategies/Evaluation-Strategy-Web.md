# Evaluation Strategy: Web Applications

This document guides the evaluator setup and verification approach for web applications (frontend, full-stack, static sites).

## Available Verification Tools

### Playwright MCP (Primary)

The most capable tool for web evaluation. Lets the evaluator interact with the running app like a real user: navigate pages, click buttons, fill forms, read content, take screenshots.

**Setup in Claude Code:**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic-ai/mcp-playwright"]
    }
  }
}
```

**Key capabilities:**
- Navigate to URLs
- Click elements by selector or text
- Fill form fields
- Read page content and DOM structure
- Take screenshots (full page or element)
- Execute JavaScript in the page context
- Handle navigation, redirects, and async content
- Test responsive layouts at different viewport sizes

**Best practice:** Use `browser_run_code` as the primary tool for combining multiple actions in a single call. Use `browser_snapshot` only for initial exploration of an unknown page.

### CLI Tools

- `npm test` / `yarn test` / `pnpm test` — run test suites
- `npm run build` — verify production build succeeds
- `npm run lint` — check for code quality issues
- `curl` — test API endpoints directly
- `node` — run scripts for data verification

### Browser DevTools (via Playwright)

Through Playwright's JavaScript execution, you can:
- Check console errors: `page.evaluate(() => window.__consoleErrors)`
- Verify network requests
- Check localStorage/sessionStorage
- Inspect CSS computed styles
- Test accessibility via `page.accessibility.snapshot()`

## Evaluation Checklist for Web Apps

### Always Do
1. **Build the project** — `npm run build` (or equivalent) must succeed
2. **Run the test suite** — test failures are automatic FAILs
3. **Start the dev server** and verify it responds
4. **Navigate to affected pages** via Playwright
5. **Take screenshots** of new or changed UI

### When the Mission Involves UI
6. **Test the interaction flow** — click through the feature end-to-end
7. **Test responsive layout** — check at mobile (375px) and desktop (1280px) widths
8. **Check for console errors** — no JavaScript errors should appear during normal use
9. **Verify navigation** — all links and buttons lead somewhere sensible
10. **Check loading states** — does the UI handle async content gracefully?

### When the Mission Involves API
11. **Test endpoints directly** with curl or Playwright's network interception
12. **Verify error responses** — invalid input, unauthorized access, not found
13. **Check CORS headers** if the API is accessed cross-origin

### When the Mission Involves Documentation or Content
Not every mission produces code. For documentation/content missions, verify claims against source code and verified test results. Build/test is not required for PASS unless the spec includes code changes.

### Never Do
- Never mark PASS without building (code missions)
- Never mark PASS without running tests (code missions)
- Never mark PASS without source verification (documentation missions)
- Never assume UI works from code alone — use Playwright to verify
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
- Playwright MCP for full browser interaction and screenshots
- Dev server at http://localhost:XXXX

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do
- Build the project before evaluating
- Run the test suite
- Start the dev server and verify it responds
- Take screenshots of changed pages via Playwright
- Check for console errors during interaction

## Never Do
- Mark PASS without a successful build
- Mark PASS without running tests
- Assume UI works without Playwright verification
```
