# Newly visible fixture failures under #38

The 25 newly failing default fixtures are expected results of the agreed
selected-example validation rule. They do not indicate lost parser support or
broken request construction. Twenty-four media-level examples have the wrong
JSON type, and one parameter-level example conflicts with its string schema.
The [operation ledger](fixture-findings.csv) records each exact key, source
pointer, literal example, type, source hash, and baseline fixture.

| Measure | Baseline | Branch |
| --- | ---: | ---: |
| Declared operations | 986 | 986 |
| Parser blockers | 53 | 53 |
| Rendered wrappers | 933 | 933 |
| Default fixture/invocation passes | 925 | 902 |
| Default fixture failures | 8 | 31 |

Two Envirofacts fixtures now pass using their valid parameter examples. Twenty-five
previously passing fixtures now reject incompatible selected examples. The net
change is minus 23 default passes, with six other fixture failures unchanged.
These are the frozen audit results, distinct from installed-client requests,
explicit fixture overrides, minimal mode, and live service behavior.

## Exact evidence selected

The 24 POST operations span CTX Bioactivity, Chemical, Exposure, and Hazard.
Every request body is required and declares `application/json` with schema
`array<string>`. The chosen evidence is the **media-level** `example`, not a
schema example. Each value is a JSON string containing serialized array text.
For example, `/bioactivity/assay/search/by-aeid/` declares:

```json
{
  "example": "[\"111\",\"3032\"]",
  "schema": {"type": "array", "items": {"type": "string"}}
}
```

The example's value is a string, while the schema requires an array. All 24
schemas have neither a schema example nor a default. Parsing the string again
would change its declared value and invent a conversion rule. The agreed #38
policy requires validating the selected evidence and retaining the failure;
it does not authorize decoding strings as a fallback.

`GET /chemical/file/image/search/by-gsid/{gsid}` declares required path
parameter `gsid`, with **parameter-level** numeric `example: 20182` and
`schema: {type: string}`. Converting that number into a string would likewise
change the selected value. Its fixture now fails before invocation.

OpenAPI expects example values to match the associated schema and permits tools
to reject incompatible examples. Its provision for escaped string examples
addresses media types that cannot naturally be represented in JSON or YAML;
JSON arrays have a native representation. See the
[OpenAPI 3.1 Example Object](https://spec.openapis.org/oas/v3.1.0.html#example-object)
and [Parameter Object](https://spec.openapis.org/oas/v3.1.0.html#parameter-object).
This is a finding about incompatible example evidence, not a declaration that
all 25 operation schemas are unusable.

## Why the baseline passed

All four affected source files are byte-identical between the preserved baseline
and rebuilt audit. Their SHA-256 values are repeated in the ledger. There was no
source or configuration change to these operations.

The baseline toolkit recorded in `provenance.json` is commit
`071267df1118aa71ef68e6f68f1043887742c464`. Its parser selected only
`body$content[[body_media]]$schema` and did not preserve media-level examples.
It likewise did not preserve OpenAPI parameter-level examples outside the
parameter schema. The baseline fixture builder therefore never saw these
25 invalid hints. This was omission of evidence, not successful validation of
those examples followed by a fallback.

An isolated R process loaded the preserved baseline library, asserted its exact
package path, and regenerated all 25 fixtures from the original schema bytes.
Every POST produced `{"body":["example"]}`. The GSID operation produced
`{"gsid":"example"}`. None of the parsed operations retained a body or
parameter example. Those successful synthetic fixtures are recorded per key in
the ledger.

The branch preserves both kinds of example separately from public defaults,
then applies the agreed precedence before validation. These inputs are all
required, so minimal-input mode cannot legitimately omit them. Valid explicit
caller inputs can still exercise the wrappers; no override was introduced in
this investigation, and no default-pass count includes one.

## Reproduction

The main frozen comparison is reproduced by
`dev/rebuild_hardened_proving_ground.R` and
`dev/compare_hardened_proving_ground.R`. To inspect the representative baseline
case in a fresh R process:

```r
baseline <- 'artifacts/proving-ground-20260921T213801Z'
.libPaths(c(file.path(baseline, 'library'), .libPaths()))
stopifnot(normalizePath(find.package('specmill')) ==
  normalizePath(file.path(baseline, 'library/specmill')))
file <- file.path(baseline, 'inputs/specmill-testing/schema/ctx_bioactivity.json')
parsed <- specmill::read_operations(file)
op <- Filter(function(x) x$key ==
  'POST /bioactivity/assay/search/by-aeid/', parsed$operations)[[1L]]
stopifnot(is.null(op$body_example))
specmill::operation_fixtures(list(op))
```

Repeat in a separate process using the branch installation. The parsed
`op$body_example$example` is the scalar string shown above, and default fixture
construction raises `Invalid body scalar type`. Inspect GSID analogously in
`ctx_chemical.json`; `p$example$example` is numeric while `p$schema$type` is
`string`. No network access is needed.
