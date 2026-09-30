# Swagger validator preflight investigation

Investigated 2026-09-30 against the public service and official implementation.
The investigation below preceded implementation; its original opt-in policy
was superseded by required validation for new or changed schemas.

Implemented in `R/schema_validation.R` and the generation gate. Live acceptance
checks rejected AMOS with 152 findings and accepted OPERA with zero findings;
both reused cached reports on the next call. `tests/schema-validation.R` checks
exact-byte submission, cache reuse, failure outcomes, coverage, and generation
blocking against a local validator server. Preprocessing remains deferred.

**Implemented policy:** require schema preflight reports for new or changed inputs using
`POST /validator/debug`, initially scoped to Swagger 2.0 and OpenAPI 3.0.
Its located structural errors can block affected operations through Specmill's
existing diagnostics. Do not advertise a clean response as proof of complete
compliance: OpenAPI 3.1 validation has demonstrated false negatives, and service
failures must remain a separate outcome. Keep preprocessing optional and separate.

The subsequent [production AMOS test](AMOS-RESULTS.md) also exposed a Swagger 2.0
backend limitation: the default returned 12 semantic messages but no structured
schema errors; the alternate returned 140 schema errors without instance
pointers. Both diagnostic channels must be checked, and default-backend coverage
must not be assumed from version support alone.

The [wild-type EPA OPERA test](OPERA-RESULTS.md) covers production OpenAPI 3.0.3.
All six profiles reported no errors on the original document. A separate missing-
responses control was rejected by both engines; the default engine supplied an
operation pointer, while the alternate did not.

## Endpoint contract

The [deployed OpenAPI document](https://validator.swagger.io/validator/openapi.json)
reported service version **2.1.9**. Actual routes are:

| Route | Methods | Input | Output/use |
| --- | --- | --- | --- |
| `/validator/` | GET, POST | GET `url`, or POST specification | PNG badge; unsuitable for tooling |
| `/validator/debug` | GET, POST | GET `url`, or POST specification | Validation report; preferred |
| `/validator/parse` | GET, POST | GET `url`, or POST specification | Parsed/resolved document; optional preprocessing |

POST accepts `application/json` and `application/yaml`; request
`Accept: application/json` for machine-readable reports. These endpoints accept
**whole OpenAPI documents**, not arbitrary standalone JSON Schemas. The live API
advertises parser controls including `resolve`, `resolveFully`, `flatten` (parse
only), `validateInternalRefs`, `validateExternalRefs`, `resolveCombinators`,
`jsonSchemaValidation`, and `legacyJsonSchemaValidation`.

The [official README](https://github.com/swagger-api/validator-badge#readme)
mentions `/parseByUrl` and `/parseByContent`; these are operation names, not the
live paths. A synthetic POST to `/validator/parseByContent` returned 404.
The README documents JSON/YAML uploads, Swagger 2.0 and OpenAPI 3.0/3.1 support,
and a Docker/self-hosted deployment. Its broad version support needs the limits
below.

## Live results

The initial uploads were tiny synthetic documents; the GET success probe used
the public Swagger Petstore. The subsequent user-requested AMOS test uploaded
the public production definition and is recorded separately above. Observations
below are from 2026-09-30, not promises about future deployments.

| Version/input | Probe | HTTP | Observed report/result |
| --- | --- | ---: | --- |
| Swagger 2.0 | Minimal operation with `responses` | 200 | `schemaValidationMessages: []` |
| OAS 3.0.3 | Minimal valid operation, JSON | 200 | `schemaValidationMessages: []` |
| OAS 3.0.3 | Minimal valid document, YAML | 200 | `schemaValidationMessages: []` |
| OAS 3.0.3 | GET missing `responses` | 200 | Semantic message and `required` error, instance pointer `/paths/~1items/get` |
| OAS 3.0.3 | Parameter schema `type: bogus` | 200 | `oneOf` error at `/paths/~1items/get/parameters/0` |
| OAS 3.0.3 | Same type error, `legacyJsonSchemaValidation=false` | 200 | Several string errors; no structured instance pointers |
| OAS 3.1.0 | Same invalid `type: bogus` | 200 | **`{}` — false negative** |
| OAS 3.1.0 | Response schema `minLength: "wrong"` | 200 | **`{}` — false negative** |
| OAS 3.2.0 | Version declaration | 200 | Unsupported/deprecated-version error |
| Standalone JSON Schema | `{"type":"object"}` | 200 | Unsupported/deprecated-version error |
| Malformed JSON | `{` | 400 | Input conversion error |
| OAS 3.0.3 | Broken local component reference | 200 | Semantic string message; empty schema error list |
| Public Petstore URL | GET `/debug?url=...` | 200 | Empty schema error list |
| Missing public document URL | GET `/debug?url=https://example.com/specmill-nonexistent-openapi.json` | 200 | `Can't read from file ...` error |
| OAS 3.0.3 | `/parse`, missing operation `responses` | 200 | Returned invalid document, no validation messages |
| OAS 3.0.3 | `/parse?resolve=true&resolveFully=true` | 200 | Inlined referenced response schema; retained components |

HTTP success means the service answered, **not** that the document passed.
Absent `messages` is normal; failures can appear solely in
`schemaValidationMessages`, while unresolved refs can appear solely in `messages`.
An unreachable URL's 200 error is a retrieval failure, not evidence of an invalid
schema. Do not classify missing/unrecognized response bodies as a pass.

For missing `responses`, the response was:

```json
{
  "messages": ["attribute paths.'/items'(get).responses is missing"],
  "schemaValidationMessages": [{
    "level": "error",
    "domain": "validation",
    "keyword": "required",
    "message": "object has missing required properties ([\"responses\"])",
    "schema": {"loadingURI": "#", "pointer": "/definitions/Operation"},
    "instance": {"pointer": "/paths/~1items/get"}
  }]
}
```

Use `instance.pointer` to locate the input defect. `schema.pointer` points into
the validator's meta-schema and cannot identify an API operation. Decode escaped
JSON Pointer tokens (`~1`, `~0`) before matching method/path identities.

## Why 3.1 cannot be a compliance gate

Official source inspected at commit
[`d129a7bb2bbcc7ecf05aed9151cd4e002647ad42`](https://github.com/swagger-api/validator-badge/tree/d129a7bb2bbcc7ecf05aed9151cd4e002647ad42)
(`master`, 2.1.10-SNAPSHOT), which differs from deployed 2.1.9.
Both [FgeValidator](https://github.com/swagger-api/validator-badge/blob/d129a7bb2bbcc7ecf05aed9151cd4e002647ad42/src/main/java/io/swagger/jsonschema/FgeValidator.java)
and [NetworkntValidator](https://github.com/swagger-api/validator-badge/blob/d129a7bb2bbcc7ecf05aed9151cd4e002647ad42/src/main/java/io/swagger/jsonschema/NetworkntValidator.java)
explicitly support 2.0 and 3.0 only. The latter returns message/level pairs without
structured pointers. Both catch schema-engine exceptions and log them rather than
returning a validation-failure marker; this also limits interpreting an empty
report as authoritative.

The [controller](https://github.com/swagger-api/validator-badge/blob/d129a7bb2bbcc7ecf05aed9151cd4e002647ad42/src/main/java/io/swagger/handler/ValidatorController.java)
runs the OpenAPI parser for 3.1 but skips meta-schema validation when neither
engine supports the version. This explains the observed false negatives. A 3.1
report should say **incomplete coverage**, even when no errors are returned.
OpenAPI 3.1 Schema Objects use JSON Schema 2020-12 with the OAS dialect; this
service's semantic parser is not evidence of full dialect validation.
[Normative Schema Object](https://spec.openapis.org/oas/v3.1.1.html#schema-object).

## Preprocessing and references

Swagger Parser's [official options documentation](https://github.com/swagger-api/swagger-parser#options)
describes `resolve` (retrieve external references and rewrite/bundle references),
`resolveFully` (inline references), and `flatten` (extract inline models into
components). These transform document representation and can affect reference
identity, composition and provenance; validate the original before any transform.

The live `/parse` probe added `servers: [{"url":"/"}]` to a document without
servers. `returnFullParseResult=true` was advertised but, with `Accept:
application/json`, still returned the bare document for both valid and invalid
input, without diagnostic messages. Therefore `/parse` is neither a validation
verdict nor a safe automatic repair step. Preserve the original, display a diff,
and validate transformed output separately if preprocessing is introduced.

A POST body has no source-file URL for relative external references; local sibling
files are unavailable to the hosted service. Prefer a shape-preserving local
bundle, with a source-location map, before an explicitly authorized upload.
GET preserves an origin but validates whatever bytes the remote server fetches,
which may differ from Specmill's snapshot. The parser receives no authentication
credentials from this service's controller. Remote resolution adds server-side
network fetches; `resolve=false` is not a general no-network sandbox, especially
across version/backend differences.

## Integration with Specmill

The current shared flow loads JSON/YAML in
[`read_schema_document()`](../../../R/schema_document.R), resolves local file
references in [`resolve_schema_references()`](../../../R/schema_references.R),
and reads/classifies operations in [`read_operations()`](../../../R/operations.R).
Remote refs are deliberately not fetched. Existing diagnostics distinguish
`schema_defect`, `capability_gap` and `review_required`, retain source pointers,
and exclude unsupported operations from ordinary generation. Plans expose the
inventory and diagnostics; reuse this mechanism.

There is concrete added value: on this checkout, a synthetic OAS 3.0 GET missing
`responses` produced **one ready generation candidate and zero diagnostics** in
Specmill, while Swagger rejected it above. Reproduce the local observation with:

```r
pkgload::load_all(".", quiet = TRUE)
p <- tempfile(fileext = ".json")
writeLines('{"openapi":"3.0.3","info":{"title":"Validator probe","version":"1"},"paths":{"/missing":{"get":{"operationId":"get_missing"}}}}', p)
x <- specmill::read_operations(p)
stopifnot(length(x$operations) == 1L, !length(x$diagnostics))
print(x$inventory[[1L]][c("key", "status", "classification")])
unlink(p)
```

Minimal proposed shipping scope:

1. Add one explicit preflight entry point returning a report: source fingerprint,
   validator URL/version, options, coverage, raw messages and normalized findings.
   A possible API is `validate_schema(files, validator_url = ...)`, with the
   report supplied to generation through supported configuration. Validate once
   per unchanged source snapshot; keep default generation offline. Existing
   suggested `httr2`/`curl` can support an optional `requireNamespace()` capability;
   no new dependency or preprocessing framework is needed.
2. Preserve JSON object/array distinctions and source locations. Upload original
   self-contained bytes, or an explicitly bundled representation with provenance;
   do not round-trip through R lists in ways that change empty objects/arrays.
3. At operation reading, consume a matching preflight report before operation
   normalization. Validate the whole original document, including policy-excluded
   operations; keep their findings visible rather than pruning them before
   validation. Precisely located operation errors block that operation;
   path-level errors affect all its methods. Shared component errors require
   reverse-reference consumers or a document-wide block. Global, unlocated, or
   ambiguous semantic strings require document review; never guess a method/path
   from dotted message text.
4. Keep outcomes separate: structural errors; no errors reported within supported
   coverage; incomplete coverage; and validator unavailable. A strict gate blocks
   unavailable/incomplete results as **unverified**, not **noncompliant**. Never
   silently pass a timeout, non-JSON response, HTTP error or malformed report.

Complete mappings can cover known Specmill capability gaps, but cannot make a
malformed OpenAPI structure valid. Structural validity is also separate from
Specmill generator support and live server request/response compliance. These
endpoints inspect documents; they do not exercise each API endpoint.

## Hosting, privacy and reproducibility

Uploading transmits the entire definition, including examples, internal hosts,
and any embedded credentials, to a third party. Public-service usage should be
explicit; private documents need a configured self-hosted validator. The official
README provides a Docker image and local Maven run; pin an image/version or digest
rather than assuming public-service behavior remains stable. Self-hosting the
same implementation does not fix its 3.1 coverage hole. No service SLA,
retention guarantee, or rate-limit contract was found in the inspected README/API.

The [URL utility implementation](https://github.com/swagger-api/validator-badge/blob/d129a7bb2bbcc7ecf05aed9151cd4e002647ad42/src/main/java/io/swagger/Utils.java)
uses five-second connection/read timeouts for root URL retrieval and disables TLS
certificate/hostname verification for its outbound client. Its local-address
check covers loopback/link-local/unspecified addresses, not every private range.
Do not treat self-host defaults as a complete network isolation policy; retain
restricted network access when processing untrusted definitions. Parser reference
fetching follows its own implementation, rather than this root-fetch utility.

For deterministic CI, keep a recorded report tied to source bytes and validator
version/options; a report for different bytes cannot authorize generation.
A timeout-bounded, opt-in HTTP call is sufficient for the first integration;
background jobs, automatic repair, and a custom endpoint-inference engine are
unnecessary now.

## Minimal repeatable remote probe

Run this only with synthetic inputs. Python uses the standard library; the
20-second timeout bounds each request. Assertions capture observed behavior and
will fail if the deployed validator changes, including a future 3.1 fix.

```sh
python3 - <<'PY'
import copy, json, urllib.request
base = "https://validator.swagger.io/validator"
spec = {"openapi": "3.0.3", "info": {"title": "Synthetic probe", "version": "1"},
        "paths": {"/items": {"get": {"responses": {"200": {"description": "OK"}}}}}}
def post(path, doc):
    req = urllib.request.Request(base + path, data=json.dumps(doc).encode(),
        headers={"Content-Type": "application/json", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as response:
        result = json.load(response)
        print(response.status, path, json.dumps(result))
        return result
valid = post("/debug", spec)
assert not valid.get("messages") and not valid.get("schemaValidationMessages")
missing = copy.deepcopy(spec)
del missing["paths"]["/items"]["get"]["responses"]
invalid = post("/debug", missing)
assert any(e.get("instance", {}).get("pointer") == "/paths/~1items/get"
           for e in invalid["schemaValidationMessages"])
bad_type = copy.deepcopy(spec)
bad_type["paths"]["/items"]["get"]["parameters"] = [
    {"name": "q", "in": "query", "schema": {"type": "bogus"}}]
assert post("/debug", bad_type).get("schemaValidationMessages")
bad_type["openapi"] = "3.1.0"
assert post("/debug", bad_type) == {}  # Observed coverage defect, not validity.
parsed = post("/parse?returnFullParseResult=true", missing)
assert "responses" not in parsed["paths"]["/items"]["get"]
assert "messages" not in parsed  # Invalid output is not a validation pass.
PY
```
