# Combined request capability verification

Branch: `feat/66-67-request-capabilities`.
Scope: [#66](https://github.com/seanthimons/specmill/issues/66) and
[#67](https://github.com/seanthimons/specmill/issues/67).

The branch starts from the committed request review and existing response-policy
work at `35fff373ca1ce47a0f8275a10ef01f50f5f25687`, then preserves the route guard
work at `e8c1e9f25f13e46deb5e925655128fbdb8809973`. The existing untracked
instruction files were preserved. No archived schemas or package version changed.

Changed implementation files: `R/configuration.R`, `R/form_bodies.R`,
`R/operations.R`, `R/generation.R`, `R/mappings.R` and
`inst/templates/request.R`. Acceptance changes are in the new
`tests/plain-text-transport.R` and existing `tests/media-types.R`,
`tests/helper-provenance.R`, `tests/schema-stress.R`, `tests/request-controls.R`.
Contracts are documented in `README.md`, `vignettes/configuration.Rmd` and the
two issue-specific audits beside this report.

## Contracts and integration

Plain-text selection flows through `request_body_media()`, `read_operations()`,
reviewed configuration, wrapper validation/rendering, and the client request
helper. Declared scalar string bodies preserve their UTF-8 text, including blank,
embedded and trailing newlines. `text_encoding: lines` explicitly joins character
entries with LF without adding a final newline. Limits count entries before
joining and exact UTF-8 bytes before HTTP. Optional omission differs from an
explicit empty string; explicit NULL and NA fail wrapper validation.

Retry selection uses `request_controls.retry_policy`, a declarative client
function name in YAML or a function/name in runtime options. The compatibility
example retries 429 and 500 through 599; a narrower predicate uses the same httr2
hook. Native statuses and zero-retry default remain unchanged. Two retries allow
three total attempts, and write replay still requires `retry_writes`. Existing
Retry-After/backoff, authentication, response policy and safe diagnostics remain.

Both paths use the shared request template and mapping validator. Generation
checks client retry function definitions and wrapper collisions. Existing #63
response handling is retained. No runtime specmill dependency, new retry loop,
automatic batching, pagination port or downstream adoption was added.

Normal generation still preserves client-owned helpers and their provenance.
The provenance regression's manual-adoption fixture now joins its custom lines
before the native scalar-text check and compares the resulting raw bytes.

## Combined installation and focused checks

Installed the combined source into `artifacts/issue-66-67/library` using
`R CMD INSTALL --library=artifacts/issue-66-67/library .`. Checks used that library
through `R_LIBS`, retaining ordinary dependency libraries. Individual checks do
not substitute for these combined-source runs.

All 14 focused standalone checks passed:

- `plain-text-transport.R`, `media-types.R`, `schema-stress.R`.
- `request-controls.R`.
- `native-transport.R`, `form-transport.R`, `authentication.R`, `batching.R`.
- `helper-provenance.R`, `new-client.R`, `routes.R`, `formatting.R`.
- `response-handling.R`, `response-policy.R`.

The text checks exercise OAS 3.0/3.1 and Swagger 2 generated wrappers, exact
bytes/media, schema constraints, auth/query, item/byte limits, invalid inputs,
empty/omitted bodies, repeat generation and customized helpers. Fresh child
processes execute generated text wrappers and retry transport without loading
specmill. The retry suite verifies native/compatibility/narrow policies,
408/429/501/505/404, recovery/exhaustion, default counts, write authorization,
Retry-After, credential-safe failures and identical JSON/text bytes across
attempts. Text replay includes UTF-8, blank lines and a trailing newline.
The unchanged Natural Products archive now has 40 supported operations and three
diagnostics, with exactly five newly supported text operations. Its stress test
also generates and checks an archived text operation on localhost.

## Full package check and existing quality findings

The clean source snapshot excludes unrelated untracked workspace files. Its
changed code, documentation and tests were compared byte-for-byte with the final
workspace. Build and check commands:

```sh
R CMD build --no-manual ../source/specmill
R CMD check --no-manual --output=verified specmill_0.1.8.tar.gz
```

Full check result: **Status: OK**, zero errors, warnings or notes. All 59 test
scripts and vignette rebuilding passed. Logs and archive are under
`artifacts/issue-66-67/final/`; the successful check directory is
`artifacts/issue-66-67/final/verified/specmill.Rcheck/`.

Air checks pass for touched files except pre-existing formatting drift in
`R/generation.R`. The same check against its unchanged branch-base version also
requests reformatting; unrelated formatting hunks were excluded. Newly added
code was formatted. Jarl reports exactly the same 22 findings against current
and branch-base touched files: 15 internal-function accesses in tests, six outer
negations and one implicit assignment. No new lint finding was introduced.
`git diff --check` passes. No roxygen or manually maintained help contract changed.

## Limits

Plain text requires a scalar string schema; array/object/composed/binary text
schemas remain diagnostics. Scalar text has no inferred records and no automatic
splitting. Existing clients must manually adopt the template changes. Predicate
names/types and bounds validate before HTTP; return values/errors validate when
an actual response reaches the predicate. Native connection and decode behavior
is unchanged. This work does not implement #64/#65 or ComptoxR adoption, change
#63's response contract, close issues, push branches or publish artifacts.
