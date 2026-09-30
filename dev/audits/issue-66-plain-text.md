# Plain-text request bodies, issue 66

Implemented on 2026-09-30. This adds generated request media and explicit input
encoding. Generated wrappers and their client-owned request helper have no
specmill runtime dependency. ComptoxR adoption is outside this change.

## Research

[OpenAPI 3.0.3 request bodies](https://spec.openapis.org/oas/v3.0.3.html#request-body-object)
select a schema through media-keyed `content`.
[Swagger 2](https://spec.openapis.org/oas/v2.0.html#operation-object)
uses operation/root `consumes` with an `in: body` parameter schema. Neither
specification defines joining an arbitrary array into lines.

The unchanged archived `inst/schema-stress/natural-products.json` declares
`text/plain` string bodies for `/chem/standardize`, `/chem/all_filters`,
`/chem/all_filters_detailed`, `/convert/molblock`, and `/convert/xyz`. Its MOL
examples include leading and blank lines; XYZ examples include final newlines.
Splitting those strings into inferred records would lose their contract.

The independent [InfluxDB write API](https://docs.influxdata.com/influxdb/v2/api/write/)
accepts line protocol as a text request body. This supports generic plain-text
transport; it does not justify a line-protocol parser or automatic record
splitting. ComptoxR's `R/z_generic_request.R` explicitly selects `raw_text` and
uses `paste(query_part, collapse = '\n')` before `req_body_raw(type = 'text/plain')`.
That explicit conversion informs the selected lines policy here.

[ComptoxR 331](https://github.com/seanthimons/ComptoxR/issues/331), its comments,
and the two request-review audits were read. Existing authentication, query
serialization, response policy, retry machinery, helper provenance and adoption
remain the transport boundaries.

## Selected contract

`body_media: text/plain` participates in existing media selection and reviewed
project/service/operation overrides. Native media priority is unchanged. Plain
text accepts an explicitly declared scalar `type: string` schema; arrays,
objects, composition, binary/byte formats and media encoding declarations remain
diagnostics. Missing or unavailable request media remains a review diagnostic.
Archived schemas are unchanged.

`text_encoding: scalar` is the default. It accepts one nonmissing character
string. `text_encoding: lines` explicitly accepts a character vector and joins
its elements with LF. It preserves duplicates, empty entries and embedded
newlines and appends no final LF. An empty vector encodes an empty string.
Neither mode trims, splits or normalizes already encoded text. Objects, matrices,
named vectors, noncharacters and NA values fail before HTTP. Lines encoding with
another media or without a body is diagnosed. Invalid encoding names fail YAML
validation and direct parser policy validation.

Scalar schema constraints apply to the encoded string, including lines mode.
Omitting an optional argument omits the body and its Content-Type. Supplying `''`
sends an explicitly empty body with Content-Type `text/plain`. Supplying NULL
fails validation, including for a required body. The helper itself retains its
ordinary NULL-means-omitted contract for direct calls.

Wrappers encode lines before calling the retained helper. No new helper argument
is needed. Transport converts the encoded character string to UTF-8 raw bytes
and uses httr2's raw-body path. Embedded CRLF/LF, blank lines and final newlines
are preserved. `batch.max_bytes` measures those exact transmitted bytes.
Explicit lines mode checks `batch.max_items` against the supplied vector before
joining; it never counts newlines inside arbitrary scalar text. Limits reject
oversized input rather than implicitly split or resend bodies. Scalar text keeps
the existing rule for nonarray max_items: an explicit operation limit errors and
an inherited array limit is dropped.

Normal generation does not replace client-owned helpers. Clients adopting this
media capability must review the text branch from `inst/templates/request.R`
manually and retain their authentication and response policy. Existing helper
signature validation and baseline provenance still apply.

## Runnable verification

`tests/plain-text-transport.R` generates fresh OAS 3.0, OAS 3.1 and Swagger 2
clients, loads their client code into a base-parent environment, and exercises a
localhost HTTP server. It checks exact bytes and Content-Type for singleton,
multiline, blank, trailing-newline, CRLF, empty and UTF-8 strings; explicit lines
including empty vectors, duplicates and embedded newlines; omitted bodies;
authentication and serialized query parameters; byte and line-count boundaries;
pre-HTTP rejection; declared and reviewed media selection; encoded scalar schema
constraints; unsupported declarations; no-op regeneration; and protection of an
edited client-owned helper. It checks client Imports exclude specmill.

`tests/media-types.R` retains unsupported media checks using application/xml,
since text/plain is now supported. Native, binary and form transport checks are
part of the lead's combined-source verification. No production API calls are
needed by these tests.

The isolated installation and logs are under `artifacts/issue-66/`. Broader
combined-source test results belong to the final integration report. Jarl finds
only six pre-existing warnings in the touched configuration/generation files;
new text code and tests have no lint findings.


The archived natural-products corpus now selects 40 of 43 operations, with three
remaining diagnostics. The five newly supported text declarations are exactly
the five paths listed above. `tests/schema-stress.R` verifies that set and
includes a generated `/chem/standardize` localhost request with UTF-8, leading,
embedded blank and trailing newlines plus exact Content-Type. The archived
schema hash remains unchanged.
