# Issue #84: nullable scalar queries

Verified on 2026-10-06 against the unchanged FAIR-TPs schema with SHA-256
`b4c772a777554cf665214a1237081b44331d94a99819290b97486bd207e0095a`.
Source: <https://fairtps.lcsb.uni.lu/api/v1/openapi.json>.

The supported slice is OpenAPI 3.1 query `anyOf` with one scalar branch and
one bare null branch. The original schema remains available to validation;
the scalar wire type is separate metadata. Optional NULL omits a query value,
required NULL fails, and omitted optional arguments retain schema defaults.
No explicit query-null encoding is inferred.

## FAIR-TPs

The same seven-operation inventory improves from three supported operations
and four `parameter_composition` blockers to seven supported operations with
no diagnostics. All eight nullable string query declarations are optional.
There are no independently exposed blockers.

Plan, apply, and generation freshness checks passed. All seven generated
wrappers prepared httr2 requests offline using generated fixtures, including
the newly supported compound search, compound connections, and both
substructure search operations. The explicit base URL remains
`https://fairtps.lcsb.uni.lu` because this schema has `servers: []`.

The generated client passed R CMD check with zero errors, warnings, or notes.
These checks demonstrate generation and request preparation, not live API
responses or the validity of placeholder search terms.

## Natural-products stress schema

The bundled, unchanged `inst/schema-stress/natural-products.json` improves
from 40 to 43 selectable operations with no parser diagnostics. The gains are
`GET /chem/tanimoto`, `GET /depict/2D`, and `GET /depict/2D_enhanced`. Full
43-operation generation passes with the explicit default overrides below.
`tests/schema-stress.R` exercises the
three gained wrappers alongside the four existing local HTTP contracts,
including nullable integer/string values, percent encoding, and omission.

Generation now catches the independent default problems before writing any
wrappers. The unconfigured plan reports two `parameter_default_schema`
diagnostics for tanimoto's string `nBits` and `radius` defaults, and one
`parameter_default_transport` diagnostic for enhanced depiction's empty
`arrow` default. Two operations need review; parsing still accepts all 43.
Apply fails without changing files.

Service configuration corrects the effective defaults without altering the
frozen schema:

```yaml
operations:
  GET /chem/tanimoto:
    parameters:
      query nBits: {default: 2048}
      query radius: {default: 2}
  GET /depict/2D_enhanced:
    parameters:
      query arrow: {default: null}
```

With those settings, generation succeeds for all 43 operations. The local
HTTP tests verify default tanimoto calls with both integer defaults, depiction
with arrow omission by default, explicit nullable values and omission, and
continued rejection of invalid caller values. No defaults are silently coerced
or discarded. These are default-value/transport limits, not remaining nullable
composition blockers.

## Other frozen schemas

The September 21 corpus contains five OpenAPI 3.1 documents. Comparing the
same files with nullable-query recognition disabled and enabled gives:

| Schema | Before | After | Lost |
| --- | ---: | ---: | ---: |
| non-oauth-scopes | 1 | 1 | 0 |
| tictactoe | 3 | 3 | 0 |
| openapi-generator 3.1 oneOf | 1 | 1 | 0 |
| GitHub descriptions-next | 1,195 | 1,195 | 0 |

The webhook-only example still fails with `Missing paths` in both runs.
No additional operation gains were observed in this corpus. Compositions of
multiple non-null types, nullable arrays/objects, other parameter locations,
and type-array query unions remain outside this slice.

## Regression checks

`tests/nullable-query.R` verifies generated requests against a local recording
server for all four scalar types, branch and sibling constraints, valid and
invalid values, omitted/default/null arguments, required arguments, explicit
empty strings, fixtures, reversed branches, references, and unsupported
composition diagnostics. Rejected values are checked before transport.

Existing parameter serialization, JSON composition constraints and transport,
and OpenAPI version checks passed.

All 65 package test files passed in R CMD check, which finished with zero
errors, warnings, or notes. After the final guard
for sibling types excluding all non-null scalars, the focused nullable-query
check passed again. The latest source also passed
`R CMD check --no-manual --no-tests` with zero errors, warnings, or notes;
tests were skipped in that final source check because the complete suite and
the focused rerun had already run separately.

Run the focused checks against this checkout with:

```r
pkgload::load_all()
source('tests/nullable-query.R'); nullable_query_acceptance()
source('tests/schema-stress.R'); schema_stress_acceptance()
```
