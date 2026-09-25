# Current corpus evaluation

Evaluated 2026-09-21 with specmill 0.1.4 installed from checkout `c30e66f`.
Uncommitted changes in this session add audit reporting, not parser or transport
behavior. All methods were considered. The original corpus evaluation was offline;
the subsequent authorized EPA live check is recorded below.

| Inputs | Documents | Declared operations | Parsed and rendered | Parser blockers | Fixture failures | Invocation failures | Offline passes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Frozen canonical inventory | 27 | 548 | 495 | 53 | 0 | 0 | 495 |
| Frozen EPA ECHO All Data | 1 | 16 | 16 | 0 | 4 | 0 | 12 |
| Frozen EPA ECHO SDWIS | 1 | 8 | 8 | 0 | 0 | 0 | 8 |
| Fresh canned and wild inputs | 33 | 5,353 | 4,134 | 1,215 | 122 | 1 | 4,011 |

The additional collection has six document-level rejections: one webhook-only
document, one unsupported OpenAPI 3.2 document containing four operations, and
four JSON Schema test-suite arrays that are not OpenAPI documents. Hence its
declared-operation count exceeds selected plus diagnosed by four. It is not a
full response-schema, callback, webhook, authentication, or live-contract test.

The 27 canonical input hashes were checked against the historical ledger.
The reviewed CHET naming override for `OPTIONS /reaction/batchsearch` was retained;
no source schema was rewritten. The 53 blockers cover the unresolved AMOS media,
AMOS declarations, binary/nested queries, and resolver GET-body contract reviews.
The numeric EPI fixture and four finite recursive Standardizer operations now pass.

The additional inputs were downloaded afresh from `testing_specs.R`, including
same-repository relative-reference targets. All 2,924 downloads succeeded. Their
hashes may differ from historical runs, so count differences alone are not
generator regressions. DigitalOcean was rechecked after all references finished
downloading; the recorded results use that final run.

## EPA results

Both new inputs match their transfer-ZIP provenance hashes:

- ECHO: `638d51d2e53aeee357c0944e55f390c1f86464655b8b41c7da3738dbee3f52e6`.
- SDWIS: `11018915d7acd25f309c0a02da649a30f08f8e57ddfa08b15096885ff96067b0`.

ECHO's GET and POST versions of `/echo_rest_services.get_facilities` and
`/echo_rest_services.get_facility_info` fail fixture generation. Their `p_cs`
parameter has numeric type but string enum members `"2"`, `"3"`, `"4"`. No
nonmissing value satisfies both declarations as written. The parameter is optional,
so this does not mean every possible request to these operations is invalid.
The audit attempts fixtures for optional parameters too. No enum coercion or
fixture override was applied. The current parser accepts the declaration and
the fixture error does not identify `p_cs`; earlier, more specific diagnostics
would help users distinguish source problems from synthesis limitations.

Both EPA client packages generated and passed `generate_client(mode = 'check')`.
Both built successfully with `R CMD build`. `R CMD check --no-manual
--no-vignettes --no-examples` finished with zero errors, zero warnings, and one
NOTE each: generated `api_request` references `api_auth`, which is absent when
authentication is not configured. See [ECHO check](epa/echo-check.log) and
[SDWIS check](epa/sdwis-check.log). These packages contain no generated test suite;
the operation checks above come from the separate corpus audit.

## Subsequent EPA live check

At 20:54 UTC on 2026-09-21, four direct HTTP requests tested numeric `p_cs = 2`
against GET and POST versions of both affected endpoints. Each used ZIP 20001,
JSON output, and `responseset=1`. Every request returned HTTP 200 and
`Results.Message = "Success"`, with `QueryRows = "16"`. Both `get_facility_info`
responses explicitly echoed `p_cs` as `"2"`. See [live evidence](epa/live-pcs.json).

GET sent a query string; POST sent `application/x-www-form-urlencoded` data.
Both serialize numeric 2 as `p_cs=2`, identical to string "2". This proves the
service accepts that wire value for all four operations, but does not establish
the server's internal type or repair the schema contradiction. POST was sent
directly to avoid the generated wrapper's local enum rejection. A prior localhost
check found that GET wrappers accept numeric 2, string "2", and even numeric 5;
POST wrappers reject numeric 2 with `Invalid body enum` and string "2" with
`Invalid body scalar type`. No parser or validation changes were made.

## Actionable generator work

1. Fix the empty optional-parameter fixture mismatch. DigitalOcean
   `GET /v2/certificates` declares optional query `name` with string default `""`.
   Fixture synthesis selects that default, then the rendered wrapper rejects it
   with `Empty query parameter: name`. Determine omission/default handling without
   weakening query validation or changing the source contract.
2. Remove the undefined `api_auth` package-check NOTE for clients without generated
   authentication. This is reproducible with both EPA client packages.
3. Report contradictory enum/type declarations at their source location rather
   than issuing a generic fixture failure. ECHO provides four concrete examples.
4. Triage the 122 additional fixture failures individually. They occur in GitHub
   3.0 (28), GitHub 3.1 (83), DigitalOcean (9), and Box (2). This count does not
   establish 122 generator bugs; constraints and supplied hints need review.

The largest parser categories are unsupported body media (582), parameter
serialization (353), and body composition (135). No new serialization should be
inferred from those counts alone. Issues #26, #27, #28, and #31 remain open.

## Locations and reproduction

Package source: `/home/sxthi/Documents/Projects/specmill`.
This run's workspace: `artifacts/corpus-2026-09-21/`, relative to that source root.

- Frozen canonical inputs: `specmill-testing/schema/` beneath the run workspace.
- Frozen EPA inputs: `specmill-testing/additional-schemas/epa/`.
- Fresh canned/wild inputs and download manifest: `additional-schemas/`.
- Generated ECHO package: `clients/echo-all-data/`.
- Generated SDWIS package: `clients/echo-sdwis/`.
- Built archives and check directories: `clients/`.

There is no unified configured canonical client package in this run. The older
configured proving-ground package was recorded at
`C:/Users/sxthi/Documents/specmill-testing` on the previous machine. The transfer
ZIP contains schemas, not its project policies or generated package.

With the extracted inputs still in the run workspace, reproduce the offline audit:

```r
source('dev/audit_testing_specs.R')
root <- 'artifacts/corpus-2026-09-21'
audit_testing_specs(
  native_root = file.path(root, 'specmill-testing/schema'),
  output = file.path(root, 'repeat/base'),
  policies = list('chet.json' = list(names = list(
    'OPTIONS /reaction/batchsearch' = 'default_api_reaction_batchsearch_options'
  )))
)
audit_testing_specs(
  native_root = file.path(root, 'specmill-testing/additional-schemas/epa'),
  output = file.path(root, 'repeat/epa')
)
audit_testing_specs(
  native_root = file.path(root, 'additional-schemas'),
  output = file.path(root, 'repeat/additional')
)
```

Per-operation results, source hashes, and diagnostics are in
[base](base/DIAGNOSTICS.md), [EPA](epa/DIAGNOSTICS.md), and
[additional inputs](additional/DIAGNOSTICS.md). Offline invocation uses a recording
helper, not HTTP. Passing it does not establish live EPA compatibility.
