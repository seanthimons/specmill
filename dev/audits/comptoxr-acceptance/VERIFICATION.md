# ComptoxR request acceptance

Verified 2026-09-14 against the adjacent ComptoxR checkout at `e01a34a8`.
The check is offline: it uses ComptoxR's existing fixed contracts and real
`generic_request()` runtime with a temporary `callr`/`httpuv` localhost server.
No EPA request or real credential is used.

## Exercised slice

The generated fixed-contract tests passed first, proving that each wrapper's
helper call and returned value still match
`tests/testthat/fixtures/apipak/ctx.rds`. The same recorded inputs and response
records then passed through ComptoxR's real HTTP helper.

| Workflow | Wire contract |
| --- | --- |
| `ct_chemical_detail_search()` | `GET /ctx-api/chemical/detail/search/by-dtxsid/DTXSID7020182?projection=chemicaldetailall` |
| `ct_chemical_detail_search_bulk()` | `POST /ctx-api/chemical/detail/search/by-dtxsid/?projection=chemicaldetailall`, `application/json`, body `["DTXSID7020182"]` |
| `ct_hazard_toxval_search()` | `GET /ctx-api/hazard/toxval/search/by-dtxsid/DTXSID7020182` |

All three sent the fixture-only `x-api-key`. The server returned the recorded
contract response records as JSON, and each parsed result matched ComptoxR's
current typed response normalization. [requests.csv](requests.csv) records the
exact observed method, path, query, content type, body, and comparison status.

## Explicit exclusions

This slice does not call AMOS. [excluded-amos.csv](excluded-amos.csv) keeps the
four retrieval/search operations visible. The verification also asserts that
all four remain `schema_defect` blockers with `Invalid input schema type` in the
active source-contract audit. Their query encodings remain unknown and must not
be inferred until an AMOS workflow needs them and a service-owned contract is
available.

No broader method, media-type, authentication, response, or serialization matrix
was added. Extend the matrix only if one of these real workflows exposes a gap.

## Reproduction

```r
source('dev/verify_comptoxr_acceptance.R')
verify_comptoxr_acceptance()
```

