# AMOS production validation

Tested 2026-09-30 using the live production
[Swagger document](https://hcd.rtpnc.epa.gov/api/amos/swagger.json).
The saved [input snapshot](amos-production-schema.json) is Swagger 2.0,
61,499 bytes, with 72 paths and 77 operations. Its SHA-256 is
`4591f49840d0f0f5c8e092fd588c43087a8582e8555c3d477ef4c1a98390eaf4`.
Only the schema was fetched and uploaded; no AMOS operation was exercised.

The adjacent ComptoxR production snapshot was tested first. It produced the same
counts below. Its hash is
`1d0ef1fbd813e2381a1e6e841d69e5070ee438e588a01dc3298b984ba7ca5f35`.
Besides formatting, the live input differs in two numeric example values, so the
retained results use the live bytes. Neither snapshot matches the older hash in
the [AMOS source-contract review](../source-contracts/AMOS.md).

## Results

| Check | Result | Evidence |
| --- | --- | --- |
| Default `POST /validator/debug` | HTTP 200; 12 semantic messages, zero structured schema errors | [Default response](amos-production-validator.json) |
| Same input with `legacyJsonSchemaValidation=false` | HTTP 200; 12 semantic messages and 140 schema errors, all at error level | [Alternate response](amos-production-validator-alternate.json) |
| Current workspace `read_operations()` | 77 inventoried; 45 generation candidates; 32 blocked | [Specmill diagnostics and inventory](amos-production-specmill.json) |

The 140 errors include cascading `oneOf` failures. They are not 140 distinct
defects or endpoints. Specmill's 32 blockers comprise six `schema_defect` and
26 `capability_gap` diagnoses. Most capability gaps are ambiguous body media;
these counts do not establish that 32 operations violate Swagger. Likewise,
45 generation candidates do not establish 45 compliant operations.

Default Swagger messages identify:

- Seven POST operations with empty `responses` objects, reported as missing.
  These include the five document/spectrum creation routes, `/api/amos/dtxsids/`,
  and `/api/amos/search_for_document_ids/{record_type}`.
- Arrays missing `items` in `NewAnalyticalQCSpectrum` and
  `dtxsids_search_schema`.
- Missing declarations for the `identifier_type` and `identifier` route tokens
  in `/api/amos/get_similar_structures/{identifier_type}/{identifier}`, and
  `record_type` in `/api/amos/list_sources_by_record_type/{record_type}`.

The alternate backend additionally exposes invalid query parameter structures,
including `type: "array of strings"` in document retrieval operations and
`type: "dict"` in document search. Its messages also reject the seven empty
response objects. Swagger 2.0 requires at least one response and restricts
non-body parameter types. See the normative
[Responses Object](https://spec.openapis.org/oas/v2.0.html#responses-object) and
[Parameter Object](https://spec.openapis.org/oas/v2.0.html#parameter-object).

Specmill already blocks the operations implicated by the default semantic
messages, but can stop at a different first blocker, such as ambiguous body
media. Swagger adds independent structural findings rather than 12 newly
blocked operations. Complete mappings or guessed schema repairs would not
resolve the underlying contract defects.

## Consequence for shipping

AMOS is a useful real regression input. An implementation checking only
`schemaValidationMessages` would incorrectly pass it with the default backend.
It must inspect both diagnostic channels and distinguish backend coverage from
schema validity. This also weakens the earlier recommendation to trust the
default Swagger 2.0 backend's structured error list.

For this snapshot, using the alternate backend makes document rejection clear.
However, its errors contain dotted message strings without structured instance
pointers. Treat these as document-level blockers until operation attribution is
reliable. Do not count cascades as endpoints or silently discard errors that
cannot be located. Keep Specmill's existing per-operation diagnostics for the
local generator checks. This test did not establish a safe schema repair or
change production generation behavior.

## Repeat the check

The check script was removed once `validate_schema()` stopped calling the hosted
validator; it remains in git history. Use `specmill::validate_schema()` for the
current local check.

## Do the other toggles help?

The first check used omitted defaults, then changed only
`legacyJsonSchemaValidation=false`. It did not explicitly enable every option.
Follow-up tests exercised all 11 booleans advertised for POST `/debug`.
[Recorded options, counts and diagnostic fingerprints](amos-option-profiles.json)
use the same production snapshot above and service version 2.1.9.

| Profile | Semantic messages | Schema errors | Instance pointers |
| --- | ---: | ---: | ---: |
| Omitted defaults | 12 | 0 | 0 |
| Explicit `jsonSchemaValidation=true` | 12 | 0 | 0 |
| JSON validation on, alternate engine | 12 | 140 | 0 |
| Every advertised boolean true | 12 | 0 | 0 |
| Every boolean true except legacy engine false | 12 | 140 | 0 |
| Alternate engine plus resolution and both reference checks | 12 | 140 | 0 |
| Alternate engine, internal checks on, all other parser options false | 12 | 140 | 0 |
| JSON validation off | 12 | 0 | 0 |

The semantic messages were identical across all profiles. The 140 schema
findings were also identical across every alternate-engine profile, comparing
complete findings after sorting. Turning everything on added no findings.

The deployed contract does not document omitted defaults. These come from the
[version 2.1.9 controller](https://github.com/swagger-api/validator-badge/blob/v2.1.9/src/main/java/io/swagger/handler/ValidatorController.java#L895)
and its dependency's
[parser 2.1.37 options](https://github.com/swagger-api/swagger-parser/blob/v2.1.37/modules/swagger-parser-core/src/main/java/io/swagger/v3/parser/core/models/ParseOptions.java#L7).

| Toggle | Omitted default | Effect on AMOS, Swagger 2.0 |
| --- | --- | --- |
| `resolve` | true for Swagger 2; false for OAS 3 | Passed to the Swagger 2 parser; resolves references |
| `resolveFully` | false | Ignored by the Swagger 2 adapter |
| `validateInternalRefs` | true | Ignored by the Swagger 2 adapter |
| `validateExternalRefs` | false | Ignored by the Swagger 2 adapter |
| `resolveRequestBody` | false | Ignored by the Swagger 2 adapter |
| `resolveCombinators` | true | Ignored by the Swagger 2 adapter |
| `allowEmptyStrings` | false | Ignored by the Swagger 2 adapter |
| `legacyYamlDeserialization` | false | Ignored by the Swagger 2 adapter |
| `inferSchemaType` | true | Ignored by the Swagger 2 adapter |
| `jsonSchemaValidation` | true | Enables the schema-validation engine |
| `legacyJsonSchemaValidation` | true | Selects FGE; false selects the alternate engine |

For OAS 3, those eight parser controls are forwarded. Some perform checks;
others infer types, inline references or select compatibility behavior. Setting
them all true is not a stricter-validation profile. `flatten` and
`returnFullParseResult` belong to `/parse`, not `/debug`. See the
[deployed API contract](https://validator.swagger.io/validator/openapi.json) and
[parser options documentation](https://github.com/swagger-api/swagger-parser#options).

For the proposed AMOS gate, explicitly select
`jsonSchemaValidation=true&legacyJsonSchemaValidation=false` and inspect both
diagnostic channels. No exposed toggle adds structured locations to the alternate
backend; its [implementation](https://github.com/swagger-api/validator-badge/blob/v2.1.9/src/main/java/io/swagger/jsonschema/NetworkntValidator.java)
returns only level/message pairs. These toggles also do not add OAS 3.1
meta-schema support. Retain the document-level blocking limitation.
