# EPA OPERA wild-type validation

Tested 2026-09-30 against the public production
[EPA OPERA schema](https://hcd.rtpnc.epa.gov/api/opera/swagger.json).
This is an unmodified OpenAPI 3.0.3 document with five paths and six operations.
Its parsed contents match our adjacent ComptoxR `schema/chemi-opera-prod.json`.
The existing production acquisition workflow identified its EPA host; the
document is served at `swagger.json`, while `api-docs` and `openapi.json`
returned 404 during discovery.

The [saved original bytes](opera-production-schema.json) are 23,554 bytes,
SHA-256 `f1e4b6ab1aba9f641c6b3a04e3b09c48659f98c8eb432efcf3d2dad34a518c6a`.
Only the schema was fetched. No prediction, upload or other OPERA operation was
called. All baseline validator requests uploaded those exact original bytes.

## Results

Swagger service version 2.1.9 returned HTTP 200 with no semantic messages and
an empty `schemaValidationMessages` array under all six profiles:

| Profile | Semantic messages | Schema errors |
| --- | ---: | ---: |
| Omitted defaults | 0 | 0 |
| JSON validation on, alternate engine | 0 | 0 |
| All 11 advertised booleans true | 0 | 0 |
| All true except legacy engine false | 0 | 0 |
| Alternate engine, resolution and both reference checks on | 0 | 0 |
| Alternate engine, internal checks on, other parser controls false | 0 | 0 |

The [recorded profiles](opera-option-profiles.json) include every query option
and complete response. This establishes that the validator reported no errors
on this wild-type 3.0 input. It does not establish live API compatibility or
exhaustive standards conformance.

## Check that validation actually runs

Two separate negative controls copied the document and removed only
`GET /api/opera`'s `responses`. The saved original and every baseline request
remained unchanged.

- The default engine returned one semantic message and one structured schema
  error, with instance pointer `/paths/~1api~1opera/get`.
- The alternate engine returned the same semantic message and one schema error
  as a level/message pair, without an instance pointer.

Both controls failed validation as expected. These results are also retained in
the profile evidence. They demonstrate that the default engine can produce
usable operation locations for this OAS 3.0 input, despite its observed
[Swagger 2.0 failure on AMOS](AMOS-RESULTS.md).

## Specmill comparison

The workspace parser accepted all six operations with zero operation blockers.
It produced six server-selection diagnostics because OPERA declares
`servers: [{"url":""}]`. Generation can proceed, but requests need a recorded
origin or an explicit base URL override. Swagger's clean structural report
does not resolve that runtime selection. See the
[local inventory and diagnostics](opera-specmill.json).

For shipping, keep the default 3.0 validator's located findings and use the
alternate engine as an additional structural check. Do not assume an engine
that works for 3.0 also covers 2.0 or 3.1. Full resolution and other toggles added
no findings on this unmodified OPERA schema.

## Repeat

Run from the Specmill checkout:

```sh
python3 dev/check_epa_validator.py
```

The [stdlib-only check](../../check_epa_validator.py) refreshes the EPA snapshot,
runs the six baseline profiles, and asserts that both negative controls are
rejected. It completed successfully. New downloads are fingerprinted so future
results can be distinguished from this snapshot.

For a narrow offline workspace-parser comparison:

```r
pkgload::load_all(".", quiet = TRUE)
x <- specmill::read_operations("dev/audits/swagger-validator/opera-production-schema.json")
stopifnot(length(x$operations) == 6L, !length(x$diagnostics))
x$server_diagnostics
```
