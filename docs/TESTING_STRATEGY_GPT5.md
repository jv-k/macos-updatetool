# Testing and Quality Assurance Strategy for macos-updatetool

This document defines a practical, scalable testing and QA strategy for macos-updatetool, a bash-based CLI utility. It is tailored to the current stack (bats-core tests run via npm scripts) and the tool’s core behaviors (configuration and applist.yaml management, update orchestration, and CLI ergonomics).

The strategy covers:

- Evaluation of the current test suite (including the ad-hoc `_tests` folder)
- Concrete test enhancements (unit, integration, E2E)
- CI/CD integration (lint, tests, coverage, reporting)
- Improvements to npm workflows to streamline developer experience
- Advanced topics: migration of `_tests`, config/completions testing, TTY behavior, flake prevention, security, release validation, helpers, PR process, and open decisions


---

## 1) Evaluation of Existing Test Suite

Summary

- Strengths
  - Clear directory separation: unit, integration, e2e, config, completions. This aligns with best practice and keeps test intent readable.
  - bats-core is appropriate for shell projects and integrates well with PATH-based mocks and temporary directories.
  - npm script orchestration lowers the bar for contributors.

- Weaknesses and gaps observed
  - Brittle tests tied to system state:
    - Direct calls to brew/mas/npm, network, or the real filesystem without isolation lead to flakiness and slow CI.
    - Reliance on developer’s Homebrew environment or network availability increases nondeterminism.
  - Gaps in negative-path coverage:
    - Error handling (e.g., missing config, malformed YAML, partial failures during updates) lacks assertions on exit codes, log messages, and cleanup.
  - Shallow assertions:
    - Tests often assert only exit code or a single line match, but not outputs, side-effects, idempotency, or branch-specific behavior.
  - Branch coverage blind spots:
    - init/setup paths (first run vs existing config), dry-run vs execute, interactive vs non-interactive, per-app failure handling.
  - Maintainability:
    - Repeated setup/teardown logic (temp dirs, PATH stubbing) across tests, rather than shared helpers.
    - Test names occasionally omit intent and preconditions.
  - Completions and config tests:
    - Completions tests typically verify “file exists” but not that completions reflect current commands/flags.
    - Config tests validate creation but not schema validation or migration behavior.


Note about the `_tests` folder
- Several ad-hoc/debug scripts (e.g., `check_serious.zsh`, `test_cask_fix.zsh`) are not integrated into automated runs, often with minimal assertions and hard-coded paths. These can drift from the main test suite and become non-deterministic. Either formalize the useful scenarios into unit/integration/e2e or archive/remove them (see Section 5).

Coverage baseline

- No line/function/branch coverage is currently collected. For bash, practical coverage focuses on:
  - Line coverage (via kcov or bashcov)
  - Branch coverage where possible (kcov supports limited branch coverage for bash)
  - Function coverage (approximated by tracing or post-processing kcov output)
- Introduce automated coverage collection to quantify progress and identify gaps (details in CI/CD section).

---

## 2) Proposed Testing Enhancements

### 2.1 Unit Tests

Goals

- Isolate and accelerate tests by mocking external dependencies (brew, mas, npm, curl, yq) and using sandboxed HOME/XDG_CONFIG_HOME.
- Increase granularity and branch coverage on:
  - Configuration bootstrap: creating default applist.yaml and ensuring config directory exists
  - Argument parsing and CLI dispatch
  - Update orchestration logic, including dry-run and non-interactive modes
  - Error/edge cases: malformed YAML, missing tools, partial failures, permission issues

Key shell functions to target (example names; adapt to actual code)

- ensure_config_dir (creates config dir with correct permissions)
- create_default_applist_yaml (writes a default applist.yaml if missing)
- parse_args (handles flags like --config, --dry-run, --non-interactive, --help)
- run_updates (iterates applist, calls brew/mas/npm operations, handles failures)
- run_or_dryrun (executes commands or logs in dry-run)
- log/info/warn/error helpers (consistent formatting)
- resolve_config_path (XDG_CONFIG_HOME/HOME precedence)

Mocking strategy

- Use a temporary bin directory prepended to PATH to shadow external commands:
  - Provide lightweight shell scripts named brew, mas, npm, yq, curl that simulate responses.
  - Write logs of invocations to a temp file to assert call order and arguments.
- Use `mktemp -d` for a per-test sandbox; set HOME or XDG_CONFIG_HOME to point inside it.
- Ensure cleanup in teardown to avoid cross-test leakage.

Example: unit tests with PATH stubbing and assertions

```bash
# filepath: tests/unit/config_creation.bats
#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR="$(mktemp -d)"
  export XDG_CONFIG_HOME="$TEST_TMPDIR/xdg"
  export HOME="$TEST_TMPDIR/home"
  mkdir -p "$XDG_CONFIG_HOME" "$HOME"

  export PATH_STUB="$TEST_TMPDIR/bin"
  mkdir -p "$PATH_STUB"
  export PATH="$PATH_STUB:$PATH"

  # Optional: stub yq if used by the tool
  cat >"$PATH_STUB/yq" <<'EOF'
#!/usr/bin/env bash
echo "yq-stub"
EOF
  chmod +x "$PATH_STUB/yq"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "create_default_applist_yaml: creates file when missing" {
  run bash -c 'XDG_CONFIG_HOME='"$XDG_CONFIG_HOME"' ./macos-updatetool --init'
  [ "$status" -eq 0 ]
  [ -f "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml" ]

  run grep -E '^apps:' "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml"
  [ "$status" -eq 0 ]
}

@test "create_default_applist_yaml: does not overwrite existing file" {
  mkdir -p "$XDG_CONFIG_HOME/macos-updatetool"
  echo "apps: [foo]" > "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml"

  run ./macos-updatetool --init
  [ "$status" -eq 0 ]
  run grep -F "apps: [foo]" "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml"
  [ "$status" -eq 0 ]
}

@test "resolve_config_path prefers XDG_CONFIG_HOME over HOME" {
  mkdir -p "$XDG_CONFIG_HOME/macos-updatetool"
  echo "apps: []" > "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml"

  run ./macos-updatetool --print-config-path
  [ "$status" -eq 0 ]
  [[ "$output" == "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml" ]]
}
```

Example: unit tests mocking brew and asserting dry-run behavior

```bash
# filepath: tests/unit/dry_run_and_brew.bats
#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR="$(mktemp -d)"
  export XDG_CONFIG_HOME="$TEST_TMPDIR/xdg"
  mkdir -p "$XDG_CONFIG_HOME/macos-updatetool"
  cat > "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml" <<EOF
apps:
  - name: jq
  - name: wget
EOF

  export PATH_STUB="$TEST_TMPDIR/bin"
  mkdir -p "$PATH_STUB"
  export PATH="$PATH_STUB:$PATH"

  export BREW_LOG="$TEST_TMPDIR/brew_calls.log"
  cat >"$PATH_STUB/brew" <<'EOF'
#!/usr/bin/env bash
echo "brew $@" >> "$BREW_LOG"
if [[ "$1" == "--version" ]]; then
  echo "Homebrew 4.x"
  exit 0
fi
if [[ "$1" == "upgrade" && "$2" == "--dry-run" ]]; then
  echo "Would upgrade"
  exit 0
fi
exit 0
EOF
  chmod +x "$PATH_STUB/brew"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

@test "dry-run mode does not execute real upgrades, logs intent" {
  run ./macos-updatetool --dry-run --config "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml"
  [ "$status" -eq 0 ]
  run grep -F "brew upgrade --dry-run" "$BREW_LOG"
  [ "$status" -eq 0 ]
}
```

Additional unit scenarios to add

- parse_args: all flags; unknown flags produce usage and nonzero exit.
- Error paths:
  - Missing applist.yaml without --init produces actionable error and exit 1.
  - Malformed YAML produces clear error and nonzero exit.
  - brew not found in PATH results in error unless in --dry-run with skip-exec policy.
- Idempotency:
  - Running --init twice does not modify existing file (validate file mtime unchanged).
- Non-interactive:
  - With --non-interactive, no prompts are emitted; defaults are applied; exit codes are deterministic.

Reusable helpers

- Create `tests/helpers/load.bash` to centralize sandbox creation, PATH stubs, and assertions. Consider bats-assert and bats-support for concise assertions.

### 2.2 Integration Tests

Focus

- Validate realistic interactions within the process boundary while still mocking external command side-effects.
- Execute typical sequences across multiple functions (e.g., parse → plan → run_or_dryrun) with a real applist.yaml fixture.

Recommended cases

- Using a valid applist.yaml with a mix of brew formulae and casks, assert:
  - brew is invoked with correct subcommands and argument order
  - Failures on one package don’t abort the entire run if the tool is designed to continue
  - Summary output includes counts of successes/failures
- Config override precedence:
  - Explicit --config path overrides defaults; handles relative and absolute paths.

### 2.3 End-to-End (E2E) Tests

Approach

- Prefer hermetic E2E by default (mock brew/mas/npm with high-fidelity stubs).
- Maintain a small number of “smoke” E2E tests against real brew using --dry-run to avoid network changes in CI. Gate them to run on a nightly schedule to reduce flakiness.

Critical workflows and success criteria

1. First-run setup and default configuration creation

   - Preconditions: Empty HOME/XDG_CONFIG_HOME.
   - Action: `macos-updatetool --init`
   - Success:
     - Exit 0.
     - Directory `macos-updatetool` exists under XDG_CONFIG_HOME (or HOME fallback).
     - `applist.yaml` created with a valid schema (has `apps:`).
     - No prompts in --non-interactive mode.

2. Updating a predefined list of applications

   - Preconditions: `applist.yaml` with several entries.
   - Action: `macos-updatetool --update`
   - Success:
     - Exit 0.
     - For dry-run: only “Would upgrade …” style logging, calls recorded to `brew --dry-run`.
     - For real run (only in local/dev): appropriate brew commands invoked in the right order; summary printed.

3. Handling failed updates gracefully

   - Preconditions: applist contains one invalid/nonexistent app; brew stub returns nonzero for that name.
   - Action: `macos-updatetool --update`
   - Success:
     - Exit code follows defined policy (e.g., 0 if partial failures allowed with summary, or nonzero if any failure should fail the run).
     - Error details logged; processing continues to other apps.
     - Summary reflects failures accurately.

4. CI/non-interactive mode

   - Preconditions: CI=true or --non-interactive
   - Action: `macos-updatetool --update --non-interactive`
   - Success:
     - No interactive prompts; retries/timeouts adhere to defaults.
     - Consistent exit code and machine-readable logs if applicable.

5. Idempotency and re-runs

   - Running the tool twice with the same config does not produce spurious changes; logs remain consistent; exit codes stable.

Example E2E with isolated HOME and PATH stubs

```bash
# filepath: tests/e2e/first_run_and_update.bats
#!/usr/bin/env bats

setup() {
  export E2E_TMPDIR="$(mktemp -d)"
  export XDG_CONFIG_HOME="$E2E_TMPDIR/xdg"
  export HOME="$E2E_TMPDIR/home"
  mkdir -p "$XDG_CONFIG_HOME" "$HOME"

  export PATH_STUB="$E2E_TMPDIR/bin"
  mkdir -p "$PATH_STUB"
  export PATH="$PATH_STUB:$PATH"

  # High-fidelity brew stub
  export BREW_LOG="$E2E_TMPDIR/brew_calls.log"
  cat >"$PATH_STUB/brew" <<'EOF'
#!/usr/bin/env bash
echo "brew $@" >> "$BREW_LOG"
case "$1" in
  "--version") echo "Homebrew 4.x"; exit 0 ;;
  "update") echo "Updated taps"; exit 0 ;;
  "upgrade")
     if [[ "$2" == "--dry-run" ]]; then
       echo "Would upgrade"
       exit 0
     fi
     if [[ "$2" == "nonexistent-app" ]]; then
       echo "Error: No available formula" >&2
       exit 1
     fi
     echo "Upgraded $2"
     exit 0
     ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$PATH_STUB/brew"
}

teardown() {
  rm -rf "$E2E_TMPDIR"
}

@test "first run creates default config" {
  run ./macos-updatetool --init --non-interactive
  [ "$status" -eq 0 ]
  [ -f "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml" ]
}

@test "update executes against applist and summarizes result (dry-run)" {
  mkdir -p "$XDG_CONFIG_HOME/macos-updatetool"
  cat > "$XDG_CONFIG_HOME/macos-updatetool/applist.yaml" <<EOF
apps:
  - name: jq
  - name: nonexistent-app
EOF

  run ./macos-updatetool --update --dry-run
  [ "$status" -eq 0 ] # or per your policy for dry-run with failures
  run grep -F "brew upgrade --dry-run jq" "$BREW_LOG"
  [ "$status" -eq 0 ]
  run grep -F "brew upgrade --dry-run nonexistent-app" "$BREW_LOG"
  [ "$status" -eq 0 ]
}
```

---

## 3) CI/CD Integration Strategy

Platform

- GitHub Actions recommended for macOS runners; matrix across macos-13 and macos-14 if needed.

Stages and triggers

- On push to feature branches:
  - lint (shellcheck, shfmt), unit, integration
- On pull_request to main:
  - lint, unit, integration, e2e (hermetic), coverage, report publishing
- Nightly scheduled:
  - Optional smoke E2E with real brew and --dry-run

Reporting and coverage

- Lint: shellcheck output surfaces inline via problem matchers
- Tests: run bats with `--tap`; convert TAP to JUnit for PR annotations
- Coverage: kcov to collect line/branch for bash; upload to Codecov (or store as artifact)

Tooling

- shellcheck for static analysis
- shfmt for formatting
- bats-core + bats-support + bats-assert
- tap-junit (npm) to convert TAP → JUnit
- kcov for coverage

Example GitHub Actions workflow (high level)

```yaml
name: CI

on:
  push:
    branches: ['**']
  pull_request:
    branches: ['main']
  schedule:
    - cron: '0 3 * * *' # nightly

jobs:
  lint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: brew install shellcheck shfmt
      - name: ShellCheck
        run: shellcheck -S style -x $(git ls-files '*.sh' 'macos-updatetool' 2>/dev/null || true)
      - name: shfmt (verify)
        run: |
          shfmt -d -i 2 -ci -sr .
  test:
    runs-on: macos-latest
    strategy:
      fail-fast: false
      matrix:
        suite: [unit, integration, e2e]
    steps:
      - uses: actions/checkout@v4
      - run: brew install bats-core
      - run: npm ci
      - name: Run ${{ matrix.suite }} tests (TAP)
        run: npm run test:${{ matrix.suite }} -- --tap | npx tap-junit > junit-${{ matrix.suite }}.xml
      - name: Upload JUnit report
        uses: actions/upload-artifact@v4
        with:
          name: junit-${{ matrix.suite }}
          path: junit-${{ matrix.suite }}.xml
  coverage:
    runs-on: macos-latest
    if: github.event_name == 'pull_request' || github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4
      - run: brew install bats-core kcov
      - run: npm ci
      - name: Coverage with kcov
        run: |
          mkdir -p coverage
          # Run each test file under kcov to capture shell coverage
          for f in tests/unit/*.bats tests/integration/*.bats; do
            [ -e "$f" ] || continue
            kcov --include-path=$(pwd) --verify "coverage/$(basename "$f")" bats "$f" || true
          done
          # Merge kcov reports
          mkdir -p coverage-merged
          kcov --merge coverage-merged coverage/*
      - name: Upload coverage artifact
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage-merged
      # Optional: upload to Codecov
      # - uses: codecov/codecov-action@v4
      #   with:
      #     directory: coverage-merged
```

Notes

- The kcov step runs per-test-file; adjust include-path to your repository root.
- If you adopt Codecov, add CODECOV_TOKEN to repo secrets when required.
- Keep E2E hermetic (mock brew); schedule real-brew smoke tests with `--dry-run` only.

---

## 4) Workflow Command Improvements (package.json)

Goals

- A single, intuitive interface for all tests via npm scripts
- Consistency across suites (flags, reporters, environment)
- A watch mode for rapid TDD on macOS

Recommended scripts

- lint: shellcheck + shfmt
- test:unit, test:integration, test:e2e, test:config, test:completions
- test:all to orchestrate: unit → integration → e2e → config → completions
- test:watch using chokidar-cli (or entr) to re-run a target suite on changes
- coverage to produce a local kcov report

Example package.json snippet

```json
{
  "scripts": {
    "lint": "shellcheck -S style -x $(git ls-files '*.sh' 'macos-updatetool' 2>/dev/null || true) && shfmt -d -i 2 -ci -sr .",
    "format": "shfmt -w -i 2 -ci -sr .",
    "test": "npm run test:unit",
    "test:unit": "bats tests/unit",
    "test:integration": "bats tests/integration",
    "test:e2e": "bats tests/e2e",
    "test:config": "bats tests/config",
    "test:completions": "bats tests/completions",
    "test:all": "npm run test:unit && npm run test:integration && npm run test:e2e && npm run test:config && npm run test:completions",
    "test:tap:unit": "bats --tap tests/unit",
    "test:tap:integration": "bats --tap tests/integration",
    "test:tap:e2e": "bats --tap tests/e2e",
    "coverage": "rm -rf coverage coverage-merged && mkdir -p coverage && for f in tests/unit/*.bats tests/integration/*.bats; do [ -e \"$f\" ] && kcov --include-path=$(pwd) --verify \"coverage/$(basename \"$f\")\" bats \"$f\" || true; done && mkdir -p coverage-merged && kcov --merge coverage-merged coverage/* && echo 'Coverage in coverage-merged/index.html'",
    "watch:unit": "chokidar 'macos-updatetool' 'lib/**/*.sh' 'tests/unit/**/*.bats' -c 'npm run test:unit'"
  },
  "devDependencies": {
    "chokidar-cli": "^3.0.0",
    "tap-junit": "^2.5.0"
  }
}
```

Notes

- On macOS, install dependencies via Homebrew:
  - `brew install bats-core shellcheck shfmt kcov`
- chokidar-cli adds a fast, cross-platform watch. Alternatively:
  - `brew install entr`
  - `watch:unit`: `ls macos-updatetool lib/**/*.sh tests/unit/**/*.bats | entr -c npm run test:unit`

---

## 5) Audit and Migration Plan for the _tests Directory

Objective

- Eliminate duplication and drift by migrating useful scenarios into the canonical `tests/*` suites or archiving them.

Action plan

- Inventory:
  - List all files in `_tests` and classify by intent: unit-like, integration-like, e2e-like, fixtures, and ad-hoc debug scripts.
  - Identify overlaps with `tests/unit`, `tests/integration`, `tests/e2e`, `tests/config`, `tests/completions`.
- Migrate:
  - Rewrite using bats-core with hermetic setup:
    - Replace absolute paths with mktemp sandbox + HOME/XDG_CONFIG_HOME pointing into sandbox.
    - Replace real brew/network usage with PATH stubs and captured call logs.
    - Convert echo-style assertions into explicit checks: exit code, stdout/stderr, side-effects (files), and logs.
  - Move into the appropriate suite directory and adopt naming convention: `<area>_<behavior>_<condition>.bats`.
- Remove or archive:
  - Delete brittle, non-deterministic, or duplicated tests covered elsewhere.
  - If a script is valuable as a manual debug tool, move under `scripts/dev/` and document usage in CONTRIBUTING.md.
- Gatekeeping:
  - Add a CI check that fails if new executable files appear under `_tests`.
- Traceability:
  - Map each migrated test to a user-facing behavior or requirement in this strategy for future maintenance.

Deliverable

- PR that removes `_tests` and increases coverage, accompanied by a brief migration log in the PR description.

---

## 6) Deep Dive: Config and Completions Testing

### 6.1 Config validation strategy

- Minimal schema expectations:
  - Top-level key: `apps`
  - `apps` is an array
  - Each entry is either a string (formula/cask name) or an object with at least `name`
  - No duplicate app names
- Tests:
  - Valid configs load without error; invalid shapes cause clear error and nonzero exit.
  - `--config` path resolution: relative and absolute paths, and precedence rules (XDG_CONFIG_HOME > HOME).
  - Idempotent `--init` (file mtime unchanged on second run).
- Implementation hint:
  - Use `yq` to validate structure in tests or add an internal validator that checks keys and types.
- Example checks (adapt to your function/flags):
  - Missing `apps`: error and exit 1
  - `apps: null` or `apps: {}` rejected
  - Duplicate names detected when the allowed set must be unique

### 6.2 Shell completions tests (bash/zsh/fish)

- Scope:
  - Generated completions exist and include all current commands and flags.
  - No stale options after CLI changes.
- Tests:
  - Golden test approach: compare generated completion output against version-controlled “golden” files.
  - Lint completions: ensure no placeholders like `TODO` or `<command>`.
  - For zsh, validate `compdef` lines reference the correct command name.
- Maintenance:
  - Provide a script to regenerate goldens and a review step to diff outputs on PRs.
- Success criteria:
  - Any CLI surface change fails CI unless goldens are updated intentionally.

Example golden test skeleton

```bash
# filepath: tests/completions/completions_golden.bats
#!/usr/bin/env bats

setup() {
  export TMPDIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "bash completion matches golden" {
  run ./macos-updatetool --gen-completion bash
  [ "$status" -eq 0 ]
  diff -u completions/golden/macos-updatetool.bash <(printf "%s\n" "$output") >/dev/null
  [ "$?" -eq 0 ]
}
```

---

## 7) Interactive/TTY Behavior Tests

Goals

- Verify differences between interactive and non-interactive modes without flaky TTY dependencies.

Techniques

- Simulate TTY using `script` to allocate a pseudo-terminal (macOS: `script -q /dev/null <cmd>`).
- For non-interactive, ensure stdin/stdout are not TTY and `CI=true` or `--non-interactive` is used.

Example

```bash
# filepath: tests/integration/tty_behavior.bats
#!/usr/bin/env bats

@test "non-interactive mode produces no prompts" {
  run env CI=true ./macos-updatetool --update --non-interactive
  [ "$status" -eq 0 ]
  [[ "$output" != *"Proceed?"* ]]
}

@test "interactive mode can prompt when TTY is present" {
  skip "Enable when prompts exist and can be controlled with env flags"
  run script -q /dev/null ./macos-updatetool --update
  [ "$status" -eq 0 ]
  [[ "$output" == *"Proceed?"* ]]
}
```

---

## 8) Flake Prevention and Performance

Determinism controls

- Force locale and timezone: `export LC_ALL=C TZ=UTC`
- Disable color in CI to stabilize output diffs: `NO_COLOR=1` or custom flag
- Sort any unordered lists before printing; normalize whitespace in logs for assertions
- Use timeouts around long-running operations even when stubbed
- Avoid `sleep`; when necessary, gate with `SLOW_TESTS=true`

Isolation

- Unique temp dirs per test via `mktemp -d`; never write to `/tmp` directly without isolation folder
- Always stub external commands via PATH; assert stubs were invoked (log file) to ensure paths are correct

Runtime budget

- Unit: < 1s per file
- Integration: < 5s per file
- E2E (hermetic): < 15s total
- Fail fast in CI with matrix and independent jobs

---

## 9) Security and Compliance Checks (CI)

Static and secret scanning

- shellcheck: enable `-S style` and treat warnings as errors on `main`
- Gitleaks or GitHub secret scanning: prevent committing secrets
- License scanning for any vendored scripts; maintain a `THIRD_PARTY_NOTICES.md` if needed
- Optional: shellharden in advisory mode for unsafe patterns

Job snippet (augment CI)

```yaml
security:
  runs-on: macos-latest
  steps:
    - uses: actions/checkout@v4
    - name: Gitleaks
      uses: gitleaks/gitleaks-action@v2
```

---

## 10) Release and Packaging Validation

Versioning

- Tests:
  - `--version` prints semver and commit sha (if available)
  - README’s install snippet stays in sync with the current version (guard with a simple grep)
- Homebrew tap (if applicable):
  - Lint formula with `brew audit --strict --online` in nightly (skip on PRs)
  - Dry-run install with `brew install --build-from-source --dry-run macos-updatetool`

Release checklist (automated where possible)

- CI tag build runs full suite + coverage
- Attach binaries or scripts to GitHub Release with checksum
- Update completion goldens
- Regenerate and commit `applist.yaml` example if applicable

---

## 11) Shared Test Helpers and Assertion Libraries

Adopt bats-support and bats-assert

- Improves readability and richer assertions: `assert_success`, `assert_output`, `assert_line`, `refute_line`, etc.

Shared helper file

- `tests/helpers/load.bash` centralizes environment and PATH stubs

Skeleton helper

```bash
# filepath: tests/helpers/load.bash
#!/usr/bin/env bash
set -euo pipefail

setup_sandbox() {
  export TEST_TMPDIR="$(mktemp -d)"
  export XDG_CONFIG_HOME="$TEST_TMPDIR/xdg"
  export HOME="$TEST_TMPDIR/home"
  mkdir -p "$XDG_CONFIG_HOME" "$HOME"
  export PATH_STUB="$TEST_TMPDIR/bin"
  mkdir -p "$PATH_STUB"
  export PATH="$PATH_STUB:$PATH"
  export LC_ALL=C
  export TZ=UTC
  export NO_COLOR=1
}

teardown_sandbox() {
  rm -rf "${TEST_TMPDIR:-}"
}

stub_cmd() {
  local name="$1"; shift
  printf '%s\n' "#!/usr/bin/env bash" "$@" > "$PATH_STUB/$name"
  chmod +x "$PATH_STUB/$name"
}
```

Usage in tests

```bash
# filepath: tests/unit/example_using_helpers.bats
#!/usr/bin/env bats

load 'tests/helpers/load.bash'

setup() { setup_sandbox; }
teardown() { teardown_sandbox; }

@test "example" {
  stub_cmd brew 'echo "brew $@" >> '"$TEST_TMPDIR"'/brew.log; exit 0'
  run ./macos-updatetool --dry-run
  [ "$status" -eq 0 ]
  run grep -F "brew" "$TEST_TMPDIR/brew.log"
  [ "$status" -eq 0 ]
}
```

---

## 12) PR Process, Ownership, and Quality Gates

PR template (enforce via `.github/PULL_REQUEST_TEMPLATE.md`)

- What changed
- How to test
- Screenshots/logs for key behaviors
- Checklist:
  - [ ] Unit/integration/e2e tests added or updated
  - [ ] shellcheck/shfmt pass locally
  - [ ] Coverage not decreased or justified
  - [ ] Completions and goldens updated if CLI changed

Ownership

- Designate codeowners for:
  - `tests/` (all suites)
  - CI workflows
  - completions and config schema

Quality gates on `main`

- Lint and all tests required
- Minimum coverage threshold enforced by Codecov or a coverage check script
- No new files under `_tests`

---

## 13) Readme Badges and Documentation Links

Add badges to README for quick status visibility

- CI build: GitHub Actions status badge
- Coverage: Codecov badge (if enabled)
- ShellCheck: link to latest lint status (optional)

Contributor docs

- CONTRIBUTING.md should include:
  - `brew install bats-core shellcheck shfmt kcov`
  - `npm run test:all`, `npm run coverage`, `npm run watch:unit`
  - How to regenerate completion goldens

---

## 14) Open Questions and Decisions to Finalize

- Exit code policy on partial failures:
  - Option A: nonzero if any app fails
  - Option B: zero with summary unless `--strict` is set
- Config schema strictness:
  - Allow strings and objects, or normalize to objects only?
- Real-brew smoke tests:
  - Enable nightly with `--dry-run` or keep fully hermetic?
- Minimum coverage target for core script(s):
  - Start at 75% and ratchet by +2% monthly?

Document and adopt these in a follow-up PR; update tests accordingly.
