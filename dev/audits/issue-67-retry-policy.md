# Explicit retry predicates

Reviewed for [specmill #67](https://github.com/seanthimons/specmill/issues/67)
and [ComptoxR #331](https://github.com/seanthimons/ComptoxR/issues/331).

`request_controls.retry_policy` selects a client-owned function. YAML accepts a
syntactic function name or null; runtime request options accept a name or a
function. No YAML code is evaluated. Generation requires the name to resolve in
client R source and forbids generated-wrapper collisions. Runtime lookup stays
inside the request helper's client environment.

The function takes one httr2 response and returns one nonmissing logical value.
The documented compatibility example selects 429 and 500 through 599, excluding
408 and permanent 4xx. Narrower service predicates use the same contract. This
uses httr2's existing `is_transient` hook and leaves Retry-After and jittered
backoff unchanged. See the [official httr2 contract](https://httr2.r-lib.org/reference/req_retry.html).

Native defaults remain zero retries and the existing 408, 429, 500, 502, 503, 504
status set. Two retries permit three total attempts. POST/PATCH replay still
requires `retry_writes = TRUE`. Connection failures and JSON decode failures do
not acquire retries. Invalid policy names and bounds fail before HTTP; invalid
predicate return values and thrown predicate errors use safe diagnostics after a
response arrives. Function shape/output cannot be checked before the actual
response without executing client code against a fabricated response.

`tests/request-controls.R` uses real localhost requests and intercepts only
httr2's sleep to avoid long waits. It verifies both policies for 408, 429, 501,
505 and 404, all six native retry statuses, successful recovery, exhaustion,
write replay authorization, exact scalar UTF-8 text with blank/trailing newlines,
identical authentication/query/body bytes across
three attempts, invalid policy inputs/results, Retry-After waits, safe errors,
YAML inheritance and runtime overrides. Generated files load in an environment
whose parent is `baseenv()` and the generated package has no specmill Import.
Repeated generation checks and client helper hash comparisons protect ownership.
The standalone retry check also runs in a fresh child process and asserts that
the specmill namespace is never loaded.

Validation passed using an isolated installation at `artifacts/issue-67/library`:
`R_LIBS="$PWD/artifacts/issue-67/library" Rscript tests/request-controls.R`.
`air format tests/request-controls.R` passes. `jarl check` reports the same nine
pre-existing internal-function warnings in server-selection assertions and no new
findings. The lead must rerun against the final combined installation.

This implements upstream policy selection. It does not adopt the helper or
change the reviewed toolkit pin in ComptoxR. Existing client helpers still need
manual review and adoption; generation does not replace them.
