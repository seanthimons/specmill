# AGENTS.md

Repo rules for coding agents. Adapted from `seanthimons/baseline` `AGENTS.md`;
it stands alone, so a clone works without global agent files.

## Project

specmill is an R package that generates and maintains R API clients from local
OpenAPI/Swagger schemas and reviewed YAML policy. It writes wrappers,
documentation, and request contract tests. Generated clients keep their own
request helpers and hooks and must not need specmill at runtime.

Read before non-trivial changes: `README.md`, `vignettes/`, `dev/WORKFLOWS.md`,
`HANDOFF.md` (proving-ground state).

### Known gotchas

- Tests are plain scripts in `tests/*.R`, not `tests/testthat/`. Each ends with
  `if (sys.nframe() == 0L) ...`, so it runs only via `Rscript tests/<name>.R`,
  not `source()`. They call `specmill::`, so install the package first.
- `yaml12` is compiled from Rust. On Linux, put `~/.cargo/bin` on `PATH` before
  `R CMD INSTALL .` or `install.packages('yaml12', type = 'source')`.
- Acceptance tests start a localhost API with `callr::r_bg()` plus
  `httpuv::startServer()`, then generate a client and `sys.source()` its `R/`
  files into a fresh env. Copy `tests/native-transport.R` or
  `tests/new-client.R` for new ones.
- The repo uses Air defaults (no `air.toml`). Do not add one; the 120-column
  baseline config reformats most of `R/`.

## Layout

- `R/`: package source (parser, generation, configuration, hooks, tests).
- `inst/templates/`: request, auth, hook, and option templates copied into
  generated clients. Edit these, not generated output.
- `inst/catalogue/`, `inst/configuration/`, `inst/schema-stress/`: fixture
  schemas and a sample catalogue package.
- `tests/`: standalone test scripts (see gotchas).
- `vignettes/`: user guides, also the pkgdown site.
- `dev/`: proving-ground, audit, release, and verification scripts
  (`.Rbuildignore`d). `dev/audits/` holds audit evidence.
- `evidence/`, `artifacts/`, `docs/`, `.docs-lib/`: local output, gitignored.

## Commands

- Shell: Bash on Linux; PowerShell on the maintainer's Windows box
  (R at `C:\Program Files\R\R-4.5.1\bin\Rscript.exe`). Use that shell's syntax.
- Setup: `pak::local_install_deps()`, then `R CMD INSTALL .`
- Test one: `Rscript tests/<name>.R` (after `R CMD INSTALL .`)
- Test all / check: `rcmdcheck::rcmdcheck(args = '--no-manual')` or
  `devtools::check()`.
- Docs: `devtools::document()` after roxygen changes.
- Format and lint: `air format <files>`, then `jarl check <files>`. `dev/` and
  some `R/` files carry pre-existing jarl warnings; lint only changed files to
  isolate new findings.

## Workflow

- Research before editing. Read the relevant files, tests, docs, and current
  implementation. For externally defined behavior (OpenAPI, Swagger, httr2),
  check authoritative upstream docs first.
- Start file-changing work with `git status --short`. Never revert, overwrite,
  or clean up unrelated local work.
- State assumptions, uncertainty, and tradeoffs. If several readings are
  plausible and the wrong one is risky, ask before changing files.
- Push back when an approach is more complex than the problem needs.
- Keep changes scoped to the request. No broad refactors, generated churn,
  speculative features, or unrelated formatting.
- Search `R/` and `dev/` for existing helpers before writing new ones.
- Write the minimum code that solves the request. Match existing style.
- Remove what your change made unused. Leave pre-existing dead code; mention it.
- Before using a name, read the source: field names, signatures, schema keys.
- Generated code: trace the whole generator and edit the source or template,
  not the output. Test generated output with real schemas.
- Bugs: reproduce first, state a root-cause hypothesis, fix, verify.
- Refactors: confirm behavior is unchanged with the same tests before and
  after.

### Definition of done

- Every referenced name resolves, targeted tests pass, format and lint pass.
- `devtools::document()` diff reviewed; `NAMESPACE` and `.Rd` match roxygen.
- If a check cannot run (credentials, services, packages), say so and report
  the closest validation performed.

## Git

### Branches

- Use a feature branch for non-trivial work; never commit to `main`.
- Commit Lint only accepts `feature/`, `feat/`, `bugfix/`, `fix/`, `hotfix/`,
  `release/`, `chore/` prefixes, lowercase and hyphen-separated. `ci/` and
  `docs/` fail; use `chore/` for those.
- Put issue ids in the description: `fix/issue-123-api-timeout`.
- Hard block: no agent, assistant, model, or AI source names in branch names.
- Renaming a PR's head branch closes the PR; open a new PR instead.

### Commits

- Conventional Commits: `type(scope)!: description`. Types for `NEWS.md`:
  `feat`, `fix`, `refactor`, `perf`, `build`, `test`, `ci`, `docs`, `style`,
  `chore`. Scopes use ASCII letters, digits, and underscores only.
- Write the first line as the release note. Issue or PR refs go at the end.
- Never write the literal skip-ci marker (square brackets around `skip ci`)
  anywhere in a commit message; GitHub then skips every PR workflow.
- Small commits, one reason each.
- Hard block: no agent, assistant, model, or AI source names in commit
  messages. No `Co-authored-by` or attribution trailers.

### Releases

- Every merge to `main` that touches files outside `.github/` cuts a patch
  release (`release-r-package.yaml`). Manual dispatch picks minor/major.
- Do not edit `Version:` in `DESCRIPTION`, create tags, or hand-edit
  `NEWS.md`; the release regenerates it via `dev/build_news.R`.

## R style

- Use `TRUE`/`FALSE`, never `T`/`F`. `snake_case` names; keep names inherited
  from external APIs as they are.
- Single-quoted strings, matching existing code.
- `cli::cli_alert_*()` for status and `cli::cli_abort()` for fatal errors.
- Namespace non-base calls in package code (`purrr::map()`,
  `stringr::str_detect()`).
- `dev/` scripts must run with `source('dev/<script>.R')` from an interactive
  session. Run multi-statement R from a temporary `.R` file, not `Rscript -e`.

## Testing

- Prefer targeted tests; run the full check for shared helpers, generation,
  templates, or cross-module contracts.
- Cover edge cases relevant to the change: empty, invalid, duplicate, large
  inputs, and schema variants (Swagger 2, OpenAPI 3, YAML).
- New tests follow existing `tests/*.R` patterns and use local fixtures or a
  localhost server; routine tests never call live APIs.
- Derive assertions from the real implementation, not assumptions.

## Issue tracking

- GitHub issues: `gh issue list`, `gh issue view <n> --comments`,
  `gh issue comment <n>`, `gh issue close <n> --comment '<evidence>'`.
- Close an issue only after its verification passes, or after user
  acceptance when none is specified. Record the evidence first.
- Planning dirs such as `.planning/` are local-only.

## Session end

1. File issues for follow-up work.
2. Run quality gates if code changed: targeted tests, format, lint.
3. Commit and push your feature branch; do not push to `main` or force-push
   unless asked.
4. Clean up only what you created.
5. Hand off: what changed, what is left, how to verify.

## Communication

- When asked to review or scan, report findings first; act after.
- When asked for a plan or options, wait for approval before changing code.
- Final message: changed files and targeted validation. If no tests ran, say
  why.
- No agent, assistant, or model names in code, docs, branches, or commits.

## Security

- Never write real API keys, tokens, credentials, or private URLs into tracked
  files, fixtures, logs, examples, or generated docs.
- `.Renviron` and `.env` are never committed.
- Add `.gitleaksignore` or `.gitleaks.toml` entries only for confirmed false
  positives.

## CI

Workflows are callers of reusable workflows in `seanthimons/baseline`, pinned
by full SHA. See `dev/WORKFLOWS.md`. Callers: `gitleaks`, `commit-lint`,
`lint-workflows`, `r-cmd-check`, `pkgdown`, `release-r-package`.
