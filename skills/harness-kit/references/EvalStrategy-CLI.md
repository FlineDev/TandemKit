# Evaluation Strategy: CLI Tools & Libraries

This document guides the evaluator setup and verification approach for command-line tools, libraries, frameworks, and packages.

## Available Verification Tools

### Test Suites (Primary)

For CLI tools and libraries, the test suite is the primary verification mechanism:
- **Swift:** `swift test`, `xcodebuild test`
- **Node.js:** `npm test`, `jest`, `vitest`
- **Python:** `pytest`, `python -m unittest`
- **Rust:** `cargo test`
- **Go:** `go test ./...`

### Command Execution

For CLI tools, verify behavior by running the tool with various inputs:
```bash
# Test the happy path
my-tool --input test-data.json --output result.json
echo $?  # Exit code should be 0

# Test error cases
my-tool --input nonexistent.json 2>&1
echo $?  # Exit code should be non-zero

# Test help/version
my-tool --help
my-tool --version
```

### Output Verification

Compare actual output against expected output:
```bash
# Exact match
diff <(my-tool process input.txt) expected-output.txt

# Pattern match
my-tool status | grep -q "healthy" && echo "PASS" || echo "FAIL"

# JSON output verification
my-tool export --format json | jq '.items | length' | grep -q "^5$"
```

### Build Verification

- **Swift packages:** `swift build`
- **npm packages:** `npm pack` (verify package contents)
- **Rust:** `cargo build`
- **Go:** `go build ./...`

## Evaluation Checklist for CLI/Libraries

### Always Do
1. **Build the project** — compilation must succeed
2. **Run the full test suite** — test failures are automatic FAILs
3. **Test the happy path** — run the primary use case end-to-end
4. **Test error cases** — invalid input, missing files, bad arguments
5. **Check exit codes** — 0 for success, non-zero for errors

### When the Mission Involves a Library/Package
6. **Verify the public API** — does the API match what the spec describes?
7. **Check for breaking changes** — if this is an update, verify backward compatibility
8. **Test import/integration** — can a consumer actually use the library?
9. **Check documentation** — are new public APIs documented?

### When the Mission Involves a CLI Tool
10. **Test argument parsing** — all flags and options work as specified
11. **Test output format** — JSON, CSV, plain text as specified
12. **Test piping** — does stdin/stdout work correctly for chaining?
13. **Test with large inputs** — performance and memory usage

### Never Do
- Never mark PASS without building
- Never mark PASS without running the test suite
- Never assume correctness from code reading — run the actual commands
- Never skip error case testing

## Role File Template

During init, create `HarnessKit/Roles/Evaluator.md` with:

```markdown
# Evaluator — Project-Specific Context

## Project Type
[CLI tool / Library / Package / Framework]

## Build & Test
- Build: [build command]
- Test: [test command]
- Run: [how to run the tool, if CLI]

## Verification Approach
- Primary: test suite execution
- Secondary: direct command execution with test inputs
- [Any project-specific verification tools]

## Evaluation Priorities
1. [From user input during init]
2. [From user input during init]

## Always Do
- Build the project before evaluating
- Run the full test suite
- Test the primary use case end-to-end
- Test at least one error case

## Never Do
- Mark PASS without a successful build
- Mark PASS without running tests
- Assume correctness from code review alone
```
