# Evaluation Strategy: Web Applications — Playwright Fallback

This document provides the Playwright MCP-specific setup and evaluation patterns for web applications. **browser-use CLI is the recommended primary tool** (see `Evaluation-Strategy-Web.md`) — use Playwright only if the user explicitly prefers it or already has it configured.

## Why This Is the Fallback

Playwright MCP works but is significantly less token-efficient:
- `browser_snapshot` returns the **full accessibility tree** (50K–270K chars on complex pages)
- browser-use `state` returns only clickable elements (2K–21K chars for the same pages)
- This means Playwright uses **10–50× more tokens** for page inspection

Playwright remains useful when:
- The user already has it configured and prefers not to switch
- Specific need for `page.accessibility.snapshot()` for WCAG auditing
- Need for Playwright's network interception capabilities

## Setup in Claude Code

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

## Key Capabilities

- Navigate to URLs
- Click elements by selector or text
- Fill form fields
- Read page content and DOM structure
- Take screenshots (full page or element)
- Execute JavaScript in the page context
- Handle navigation, redirects, and async content
- Test responsive layouts at different viewport sizes

**Best practice:** Use `browser_run_code` as the primary tool for combining multiple actions in a single call. Use `browser_snapshot` only for initial exploration of an unknown page.

## Browser DevTools (via Playwright)

Through Playwright's JavaScript execution, you can:
- Check console errors: `page.evaluate(() => window.__consoleErrors)`
- Verify network requests
- Check localStorage/sessionStorage
- Inspect CSS computed styles
- Test accessibility via `page.accessibility.snapshot()`

## Playwright-Specific Evaluation Checklist

The general checklist from `Evaluation-Strategy-Web.md` applies. Playwright-specific notes:

1. **Navigate to affected pages** via Playwright's `browser_navigate`
2. **Take screenshots** via `browser_take_screenshot`
3. **Test interaction flows** via `browser_click`, `browser_fill_form`
4. **Check for console errors** via `browser_run_code` with `page.evaluate()`
5. **Test endpoints** with curl or Playwright's network interception

## Role File Additions (Playwright)

If the user chose Playwright, add to `TandemKit/Evaluator.md`:

```markdown
## UI Verification Tools
- Playwright MCP for full browser interaction and screenshots
- Dev server at http://localhost:XXXX

## Always Do
- Take screenshots of changed pages via Playwright
- Check for console errors during interaction

## Never Do
- Assume UI works without Playwright verification
```
