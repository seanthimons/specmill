# Issue 63 implementation and integration notes

Scope: [specmill #63](https://github.com/seanthimons/specmill/issues/63).
Branch: `feat/63-response-policy`. This implements upstream response support;
it does not migrate ComptoxR, establish downstream adoption, or close issues.

## Source review and flow

Read #63 and its empty comment thread, ComptoxR #331 and its image-decoding
comment, the two request audits, the request template, helper provenance,
response tests, hook scaffold, and helper-preservation checks. The current
ComptoxR `R/z_generic_request.R` has Git blob
`699c0da3dee9dcbad7313c2f2ed334556a02fad6` both locally and on GitHub main at
inspection. Reviewed `generic_request()`, `generic_chemi_request()`,
`parse_delimited_response()`, `safe_tidy_bind()`, their shared functions and
call sites. The parser's read.table settings and formatter's heterogeneous
field recovery are reusable; requested-media dispatch, guessed envelopes,
chemical attribution rules, and warning/empty behavior remain client choices.

The generation path remains configuration inheritance and validation,
`configure_operation()`, `render_operation()`, and helper-call compatibility
validation in `generate_client()`. Single- and multi-API initialization both
use `request_helper_scaffold()`. Initialization records the entire helper file
as its provenance baseline. Generation changes wrappers, retaining helper files.
Existing `post_response` calls still wrap only the helper's returned result.

Runtime construction, authentication, timeout and httr2 retry setup are
unchanged. `req_error(is_error = function(response) FALSE)` already exposes the
final response. Policy now runs there, before status checking and decoding.
Authoritative references consulted:
[httr2 error policy](https://httr2.r-lib.org/reference/req_error.html) and
[R read.table](https://stat.ethz.ch/R-manual/R-devel/library/utils/html/read.table.html).

## Callback and selections

`response_policy(response, context, decode)` receives the final httr2 response
and context containing only method, status, and normalized actual response
media. It receives no request parameters, URL, headers, body, or credentials
through context. The raw response may contain sensitive information; the client
owns what it observes or logs.

- `decode()` delegates to native status checking and decoding.
- Every callback return is a replacement, including NULL.
- Warning and error conditions propagate.
- `decode(check_status = FALSE)` explicitly bypasses HTTP error handling.
- `decode(format = 'delimited', col_classes = ...)` selects delimited parsing
  from actual response media, preserving native decoding for other media.
- Returning `list(response = response, result = decode())` preserves headers,
  status, URLs and envelope metadata for future pagination code.

There is no delegate sentinel, new wrapper stage, retry loop, or hidden result
metadata. Policies run once after retries, and never on dry runs or transport
failures with no response. A direct helper argument accepts NULL, a function, or
a client function name. The package-scoped `.response_policy` option supplies a
shared helper default; explicit arguments override it, including NULL.

YAML `defaults.response_policy` accepts a client function name and inherits at
project/API/group/service/operation levels. The generator validates names and
client definitions and rejects wrapper collisions. A null override removes the
generated selection, restoring the helper default. Complete request mappings
continue to own their whole call and must pass policy explicitly.

## Decoding and formatting

No selected policy preserves existing HTTP errors, sanitized malformed-JSON
errors, JSON scalar/object/array/null returns, charset-aware text, binary bytes,
and empty NULL returns. No envelope guessing occurs.

The emitted `<helper>_delimited` policy selects CSV for text/csv or
application/csv, and TSV for text/tab-separated-values or text/tsv. Native CSV
and TSV remain strings. Delimited parsing uses utils::read.table with original
headers, quoted separators/newlines, disabled comments, fill = FALSE, and
optional column classes. A field-count check rejects surplus fields that R
would otherwise reinterpret as row names. Parser warnings become errors so
unterminated quotes cannot silently return partial data. Empty delimited input
returns data.frame(); header-only input retains columns.

`<helper>_records()` is explicitly selected collection formatting for existing
post_response hooks or client facades. It accepts an exact extraction path,
object/array/scalar/data-frame records, query attribution, shallow NULL-to-NA
cleanup, and explicitly keyed outer collections. It preserves nested values and
returns list() for empty collections. It does not guess correspondence between
API inputs and results.

`<helper>_table()` unions heterogeneous fields, collapses nested values with
semicolon separators, optionally recovers types, and preserves selected query
attributes or outer keys. This compatibility formatter deliberately loses
nested structure and can convert identifiers such as "001" to 1. Disable type
recovery when required. Base data frames are its default. Pass tibble::as_tibble
as the explicit `as_table` function and declare tibble in client Imports for
tibble output, including empty tibbles. Emitted code does not refer to a tibble
namespace or specmill runtime calls. No new runtime dependency was added.

Shared response policy is selected once per service/helper. Formatting functions
are reusable in the existing hook executor; exceptional public-parameter
transformations can retain existing hook registrations. No wrapper signatures
or new hook stages are introduced.

## Shared-file integration with issues 66 and 67

No #66/#67 worktree or concurrent edits were visible in this checkout. Review
these additive changes when integrating their separate branches:

- `inst/templates/request.R`: appended response_policy formal and validation;
  wrapped existing final-response decoding in a callable decoder; added three
  helper-prefixed companions after the request function. Body and retry branches
  were left unchanged. Keep #66's body changes and #67's retry changes intact.
- `R/mappings.R`: added response_policy to allowed settings, validated its
  declarative function name, and copied the selected value to the operation.
  No request-control or body-media validators changed.
- `R/generation.R`: passes selected response_policy, checks definitions and
  companion collisions. Preserve independent body/retry rendering changes.
- `R/helper-provenance.R`: substitutes the helper prefix throughout the template
  so companion names are unique across services. Baseline format, ownership and
  manual adoption remain unchanged.

The full-file provenance includes the companions. Existing clients must review
and manually adopt the proposal; routine generation never replaces customized
helpers. No ComptoxR files were changed. EPA settings, observer registries,
PubChem Fault behavior and magick conversion remain client-owned.

## Verification

Focused localhost checks passed:

- `tests/response-handling.R`: unchanged native types/errors; response observation
  before HTTP/decode failures, once after three retry attempts; replacement NULL;
  selected warnings/aborts;
  explicit 404-body decoding and 503 replacement; metadata retention; CSV/TSV
  headers/types, explicit character identifiers, empty/header-only/multiline
  input, ragged/surplus/unterminated rows; selected heterogeneous formatting,
  query/key attribution, object/scalar/array/envelope responses and empty classes,
  including an empty JSON object.
- `tests/response-policy.R`: service defaults, operation null overrides,
  declarative validation and missing functions, shared policy plus existing
  post_response hook formatting, deterministic repeated generation, scoped
  companion names, customized-helper/baseline preservation, and installed-client
  HTTP execution in a fresh process with specmill absent from loaded namespaces.
- Existing native-transport, request-controls, helper-provenance, hook-scaffold,
  mappings, multi-api and generated-names suites passed.

Build rebuilt all vignettes successfully. The final source archive passed
`R CMD check --no-manual` with Status: OK, zero errors, warnings or notes,
all 58 test scripts, and rebuilt vignette outputs. The final check log is
`/tmp/specmill-63-check/final/specmill.Rcheck/00check.log`.

Reproduce from the checkout with an isolated installation:

```sh
mkdir -p /tmp/specmill-63-library /tmp/specmill-63-check
R CMD INSTALL --library=/tmp/specmill-63-library .
R_LIBS=/tmp/specmill-63-library Rscript tests/response-handling.R
R_LIBS=/tmp/specmill-63-library Rscript tests/response-policy.R
# From /tmp/specmill-63-check, build the absolute source directory, then:
R_LIBS=/tmp/specmill-63-library R CMD check --no-manual specmill_0.1.8.tar.gz
```

`git diff --check` passed. New tests, template and
provenance code passed jarl. Its three warnings in generation/mappings are
pre-existing implicit-assignment/outer-negation warnings outside changed lines.
Air formatted changed blocks and new tests; unrelated pre-existing generator
formatting was retained to avoid integration churn.

## Remaining limits

This is response support, not a paginator, batching port, text-body port, or
retry-predicate port. Response policies must retain raw responses/envelopes when
later pagination code needs their metadata. Compatibility formatting is lossy
and selected; NULL cleanup is shallow. Delimited column inference requires
explicit column classes for identifiers with significant leading zeroes. The
actual response Content-Type must be correct; plain text is never guessed as
CSV, JSON, or a collection. Transport failures without a response bypass policy.
ComptoxR adoption and behavioral parity remain owned by #331/#342.
