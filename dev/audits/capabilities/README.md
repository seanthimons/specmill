# Generated-client capability audit

Verified against the checkout on 2026-09-15 for [GH #6](https://github.com/seanthimons/specmill/issues/6).
This is an implementation audit, not a claim that a schema which merely parses is
supported. A capability is **supported and tested** only when an acceptance script
asserts the relevant generated call, wire representation, validation, or ownership
behavior.

## Classification

| Status | Meaning |
| --- | --- |
| **Supported + tested** | The default parser, renderer, and client helper carry the contract, and a focused acceptance check exercises it. |
| **Supported, untested** | The current implementation has an end-to-end path, but no focused assertion proves the final behavior. |
| **Customizable** | The default path does not implement the capability, but a documented client-owned helper, complete request mapping, hook, or retained implementation can own it. |
| **Unsupported** | There is no native path. "Diagnosed" means generation stops loudly; "silent" means metadata is omitted or misapplied without a diagnostic. |

The normative comparison is the [OpenAPI 2.0 specification](https://spec.openapis.org/oas/v2.0.html),
[OpenAPI 3.0.4 specification](https://spec.openapis.org/oas/v3.0.4.html), and
[OpenAPI 3.1.1 specification](https://spec.openapis.org/oas/v3.1.1.html).

## Contract flow

1. JSON or YAML is loaded and local file references are bundled by
   [`read_schema_document()`](../../../R/schema_document.R#L1) and
   [`resolve_schema_references()`](../../../R/schema_references.R#L62).
2. [`read_operations()`](../../../R/operations.R#L1) selects methods, resolves
   path/operation parameters, chooses a request media type, normalizes parameter
   serialization, request schemas, and security, and records diagnostics. It then
   calls the older compatibility parser through
   [`endpoint_records()`](../../../R/endpoint_records.R#L4) to add legacy metadata.
3. [`configure_operation()`](../../../R/mappings.R#L188) applies public names,
   defaults, explicit inputs, complete helper-argument mappings, and per-operation
   settings.
4. [`render_operation()`](../../../R/generation.R#L49) emits the wrapper and passes
   path/query/header/cookie values, serialization metadata, body media/encoding,
   batching, and authentication to the selected helper.
5. The initialized, client-owned [`api_request()`](../../../inst/templates/request.R#L2)
   serializes the request with `httr2`, performs it, and decodes the actual response
   `Content-Type`. Generation verifies helper formals before applying output
   ([`generation.R`](../../../R/generation.R#L653)).

## Capability matrix

### Documents, operations, references, and servers

| Capability | Status | Evidence and limits |
| --- | --- | --- |
| OpenAPI 2.0, 3.0.x, and 3.1.x JSON/YAML documents | **Supported + tested** | Versions are admitted at [`operations.R`](../../../R/operations.R#L41); JSON/YAML parity and malformed YAML are exercised in [`schema-loading.R`](../../../tests/schema-loading.R#L1) and version-specific bodies in [`schema-versions.R`](../../../tests/schema-versions.R#L1). OpenAPI 3.2 is rejected. |
| Local JSON/YAML `$ref`, including sibling files | **Supported + tested** | Local references, escaping, dependency tracking, depth, recursion, and missing files are checked in [`local-references.R`](../../../tests/local-references.R#L1). Remote URL references are deliberately not fetched and become diagnostics ([`schema_references.R`](../../../R/schema_references.R#L120)). |
| GET, POST, and DELETE operations | **Supported + tested** | Real localhost requests cover GET/POST in [`new-client.R`](../../../tests/new-client.R#L267) and DELETE in [`native-transport.R`](../../../tests/native-transport.R#L103). |
| PUT, PATCH, HEAD, and OPTIONS operations | **Supported, untested** | They are selected by [`operations.R`](../../../R/operations.R#L78), flow through generic `req_method()`, and are accepted by the compatibility boundary, but no focused wire test invokes them. |
| TRACE operations | **Unsupported (diagnosed)** | The outer reader selects TRACE, but the compatibility parser's method list omits it ([`endpoint_records.R`](../../../R/endpoint_records.R#L9)); the resulting `parser_failure` removes it. The generated configuration nevertheless advertises TRACE ([`configuration-scaffold.R`](../../../R/configuration-scaffold.R#L237)). |
| One reviewed absolute base URL per API/helper | **Supported + tested** | Initialization embeds the reviewed URL in the client helper ([`initialization.R`](../../../R/initialization.R#L27)); multi-API generation creates one helper per reviewed URL ([`multi-api.R`](../../../R/multi-api.R#L84)). Localhost and multi-API checks exercise those helpers. |
| Catalogue discovery of Swagger `schemes` + `host` + `basePath`, relative root URLs, and OAS 3 server-variable defaults | **Supported, untested** | The reviewed catalogue/multi-API path resolves these through [`schema_server()`](../../../R/api-catalogue.R#L14), but there is no focused test for Swagger assembly or variable substitution. Multiple distinct candidates and unresolved variables intentionally require a reviewed `base_url`. |
| Direct single-schema server inference, path/operation `servers`, and runtime server choice | **Unsupported (silent)** | Direct `initialize_client()` copies the first root server URL literally and does not substitute variable defaults ([`initialization.R`](../../../R/initialization.R#L27)). The reader also retains no effective path/operation server despite OAS precedence being operation > path > root ([3.0 Operation Object](https://spec.openapis.org/oas/v3.0.4.html#operation-object), [3.1 Operation Object](https://spec.openapis.org/oas/v3.1.1.html#operation-object)); the helper always uses embedded `BASE_URL` ([`request.R`](../../../inst/templates/request.R#L103)). Server-only schema changes are absent from [`compare_operations()`](../../../R/operations.R#L628). Reproduced by [`operation-server.json`](../../../tests/fixtures/capability-audit/operation-server.json) and tracked in [GH #11](https://github.com/seanthimons/specmill/issues/11). |
| OAS 3 callbacks and OAS 3.1 top-level webhooks | **Unsupported (silent omission)** | The reader iterates only `document$paths` ([`operations.R`](../../../R/operations.R#L45)). Schema callbacks and webhooks are unrelated to specmill's client runtime hooks. Normative objects: [3.0 Callback Object](https://spec.openapis.org/oas/v3.0.4.html#callback-object), [3.1 Callback Object](https://spec.openapis.org/oas/v3.1.1.html#callback-object), and [3.1 OpenAPI Object](https://spec.openapis.org/oas/v3.1.1.html#openapi-object). |

### Parameters

The standards are the [2.0 Parameter Object](https://spec.openapis.org/oas/v2.0.html#parameter-object),
[3.0 Parameter Object](https://spec.openapis.org/oas/v3.0.4.html#parameter-object), and
[3.1 Parameter Object](https://spec.openapis.org/oas/v3.1.1.html#parameter-object), with
3.x style definitions in the [3.0 style table](https://spec.openapis.org/oas/v3.0.4.html#style-values)
and [3.1 style table](https://spec.openapis.org/oas/v3.1.1.html#style-values).

| Capability | Status | Evidence and limits |
| --- | --- | --- |
| Scalar string/integer/number/boolean path, query, header, and cookie parameters | **Supported + tested** | Type checks and URI/header safety are in [`request.R`](../../../inst/templates/request.R#L11); exact localhost bytes and pre-HTTP failures are exercised by [`parameter-transport.R`](../../../tests/parameter-transport.R#L1). Swagger 2.0 has no cookie parameter. |
| OAS 3 arrays/flat objects: path `simple`, `label`, `matrix`; query `form`, `spaceDelimited`, `pipeDelimited`, `deepObject`; header `simple`; cookie `form`; explode true/false | **Supported + tested** | Accepted combinations are normalized by [`parameter_shape()`](../../../R/parameter_shapes.R#L75) and 56 generated localhost contracts cover structural delimiters and encoded data ([`parameter-transport.R`](../../../tests/parameter-transport.R#L110)). `deepObject` is flat only; the specification leaves nested representation undefined. Empty arrays/maps are rejected because omission and an empty expansion cannot be distinguished. |
| Swagger 2 array `collectionFormat` csv/ssv/tsv/pipes/multi | **Supported + tested** | Validation is at [`parameter_shapes.R`](../../../R/parameter_shapes.R#L53), with all query formats plus header pipes and path csv exercised at [`parameter-transport.R`](../../../tests/parameter-transport.R#L302). `multi` remains query/formData-only. |
| Opt-in `name[]=value` query arrays | **Customizable** | `query_array_style: brackets` is a deliberate non-OpenAPI extension, tested in [`bracket-transport.R`](../../../tests/bracket-transport.R#L1). It is not inferred from schema metadata. |
| Parameter `content` and query `allowReserved: true` | **Unsupported (diagnosed)** | Both produce `parameter_encoding` diagnostics at [`parameter_shapes.R`](../../../R/parameter_shapes.R#L42); neither is silently approximated. |
| Nested parameter objects, composed parameters, arrays of objects/arrays, and binary parameters | **Unsupported (diagnosed/review required)** | The bounded flat subset is enforced at [`parameter_shapes.R`](../../../R/parameter_shapes.R#L7). Binary source-contract review was completed in [GH #16](https://github.com/seanthimons/specmill/issues/16); native binary parameter transport remains unsupported. |
| Parameter-contract integrity: route-template correspondence, uniqueness, reserved header names, and `allowEmptyValue` | **Supported + tested** | [`read_operations()`](../../../R/operations.R) diagnoses missing/unmatched path parameters and same-array duplicates while preserving operation overrides, and ignores the three reserved OAS 3 header definitions. Generated wrappers reject empty query strings unless `allowEmptyValue` is true. The corrected parser and rendered-request contracts are exercised by [`parameter-contracts.json`](../../../tests/fixtures/capability-audit/parameter-contracts.json), [`capability-audit.R`](../../../tests/capability-audit.R), and [`parameter-transport.R`](../../../tests/parameter-transport.R). Swagger 2 header definitions remain valid because its Parameter Object has no reserved-header rule. |

### Request bodies and media types

Normative objects are the [2.0 Operation/consumes rules](https://spec.openapis.org/oas/v2.0.html#operation-object),
[3.0 Request Body Object](https://spec.openapis.org/oas/v3.0.4.html#request-body-object),
[3.0 Encoding Object](https://spec.openapis.org/oas/v3.0.4.html#encoding-object), and their
[3.1 Request Body](https://spec.openapis.org/oas/v3.1.1.html#request-body-object) and
[Encoding](https://spec.openapis.org/oas/v3.1.1.html#encoding-object) counterparts.

| Capability | Status | Evidence and limits |
| --- | --- | --- |
| OAS 3 JSON request bodies and deterministic selection when JSON is one alternative | **Supported + tested** | Supported-media priority is explicit in [`request_body_media()`](../../../R/form_bodies.R#L7); 3.0/3.1 references, required bodies, alternative ordering, and invalid bodies are covered by [`media-types.R`](../../../tests/media-types.R#L1). |
| `application/octet-stream` request body declared as string/binary | **Supported + tested** | Parser rejects other binary schemas ([`operations.R`](../../../R/operations.R#L429)); raw-vector wire transport is exercised by [`native-transport.R`](../../../tests/native-transport.R#L110). |
| `application/x-www-form-urlencoded` and `multipart/form-data`, including Swagger `formData`, primitive arrays, binary file(s), and JSON object parts | **Supported + tested** | Media/encoding validation is in [`form_bodies.R`](../../../R/form_bodies.R#L39), serialization in [`request.R`](../../../inst/templates/request.R#L125), and OAS 3 plus Swagger wire contracts in [`form-transport.R`](../../../tests/form-transport.R#L1). Dynamic fields, nested URL-encoded fields, part headers, and ambiguous part shapes are diagnosed. |
| Explicit supported-media selection per service/operation | **Supported + tested** | `body_media` accepts the four native media types and is checked against operation availability ([`mappings.R`](../../../R/mappings.R#L56)); inheritance, overrides, unavailable choices, and old-helper compatibility are tested in [`media-types.R`](../../../tests/media-types.R#L93). |
| Swagger 2 body `consumes`, including operation-over-document precedence | **Supported + tested** | Body parameters use [`request_body_media()`](../../../R/form_bodies.R#L7) with operation-level then document-level `consumes`; missing, empty, and unsupported effective media are diagnosed. JSON inheritance and octet-stream override are covered by [`swagger-consumes.json`](../../../tests/fixtures/capability-audit/swagger-consumes.json), [`media-types.R`](../../../tests/media-types.R), and exact localhost bytes in [`native-transport.R`](../../../tests/native-transport.R). Resolved by [GH #21](https://github.com/seanthimons/specmill/issues/21). |
| Other request media types/ranges, including XML and text | **Unsupported (diagnosed)** | The native allowlist is four exact types ([`form_bodies.R`](../../../R/form_bodies.R#L7)). A complete request mapping to another helper can implement them. |
| Request bodies on OAS 3.0 GET/HEAD/DELETE versus OAS 3.1 | **Supported + tested** | OAS 3.0 bodies on these methods are ignored as required by the [3.0 Operation Object](https://spec.openapis.org/oas/v3.0.4.html#operation-object). OAS 3.1 bodies are rejected unless the exact operation has a `body_media` override; that override records review acknowledgment, and parsing warns that interoperability semantics remain undefined per the [3.1 Operation Object](https://spec.openapis.org/oas/v3.1.1.html#operation-object). Parser and exact localhost-byte regressions use [`oas30-get-body.json`](../../../tests/fixtures/capability-audit/oas30-get-body.json). Resolved by [GH #24](https://github.com/seanthimons/specmill/issues/24). |

### Authentication and request controls

Security semantics come from the [2.0 Security Scheme](https://spec.openapis.org/oas/v2.0.html#security-scheme-object)
and [Security Requirement](https://spec.openapis.org/oas/v2.0.html#security-requirement-object), plus the
[3.0](https://spec.openapis.org/oas/v3.0.4.html#security-scheme-object) and
[3.1](https://spec.openapis.org/oas/v3.1.1.html#security-scheme-object) Security Scheme Objects.

| Capability | Status | Evidence and limits |
| --- | --- | --- |
| API keys in header/query/cookie and HTTP bearer tokens | **Supported + tested** | Scheme normalization is at [`authentication.R`](../../../R/authentication.R#L31). Inheritance, operation override, public/anonymous access, OR alternatives, AND requirements, missing-token preflight, URL encoding, redaction, and localhost rejection are covered in [`authentication.R`](../../../tests/authentication.R#L1). Swagger 2 API keys are normatively header/query only. |
| OAuth 2 login/refresh, OpenID Connect, HTTP basic/digest/other schemes, and OAS 3.1 mutual TLS | **Unsupported (loud at runtime)** | Unsupported schemes are preserved as such ([`authentication.R`](../../../R/authentication.R#L48)); an unsupported-only requirement fails before HTTP. OAuth lifecycle work is tracked separately in [GH #4](https://github.com/seanthimons/specmill/issues/4). |
| Caller-selected security alternative or per-call credential override | **Customizable** | Native auth chooses the first satisfiable declared alternative from configured environment variables. A complete request mapping or client helper can expose a different policy. Tokens are never written into tracked configuration. |
| Batch `max_items` and serialized `max_bytes` guards | **Supported + tested** | Wrapper eligibility is checked in [`generation.R`](../../../R/generation.R#L538), transport guards in [`request.R`](../../../inst/templates/request.R#L91), and pre-HTTP failures in [`native-transport.R`](../../../tests/native-transport.R#L244). This validates limits; it does not automatically split calls. |
| Automatic pagination across multiple requests | **Customizable** | Generated wrappers perform one request. Pagination-like metadata is only advisory/legacy parser metadata; a client helper or retained wrapper must loop and merge results. Configurable pagination is tracked in [GH #13](https://github.com/seanthimons/specmill/issues/13). |
| Timeouts, retries/backoff, proxy/TLS options, redirects, arbitrary per-call headers, streaming, cancellation, and custom error policy | **Customizable** | The default helper calls bare `httr2::req_perform()` ([`request.R`](../../../inst/templates/request.R#L193)) and wrappers expose only schema-derived values. Edit/replace the client-owned helper, or use explicit `inputs` + `request.arguments` to pass controls. |
| Pre-request and post-response client hooks | **Supported + tested** | Wrapper ordering is emitted at [`generation.R`](../../../R/generation.R#L224) and mapping/hook state is exercised in [`mappings.R`](../../../tests/mappings.R#L27). Hooks see public parameters and the decoded result, not the raw `httr2_response`. |
| Per-package dry-run env flag returning the unexecuted request | **Supported + tested** | A truthy `<PACKAGE>_DRY_RUN` variable makes the helper return the fully-formed `httr2_request` before [`req_perform()`](../../../inst/templates/request.R#L193); the token is substituted at [`initialization.R`](../../../R/initialization.R#L103) and [`multi-api.R`](../../../R/multi-api.R#L88), and the return-and-skip contract is exercised in [`dry-run.R`](../../../tests/dry-run.R#L1). |

### Responses and schemas

| Capability | Status | Evidence and limits |
| --- | --- | --- |
| Runtime decoding from actual response `Content-Type`: JSON, text, SVG text, raw bytes, empty body; HTTP error propagation | **Supported + tested** | Dispatch is at [`request.R`](../../../inst/templates/request.R#L193). JSON, text, SVG, octet bytes, empty 204, invalid JSON, and 503 are tested in [`new-client.R`](../../../tests/new-client.R#L285). |
| Structured-suffix `application/*+json` response decoding | **Supported, untested** | The branch exists at [`request.R`](../../../inst/templates/request.R#L200), but no focused response contract exercises it. |
| Declared response media/schema used for `Accept`, status-specific decoding, or output validation | **Customizable** | Raw response metadata is retained for documentation/diffing ([`operations.R`](../../../R/operations.R#L501)), but the wrapper passes none of it to the helper. The default helper returns only the decoded body. A custom helper/mapping must retain status/headers or validate response schemas. |
| JSON body primitives, nested objects/arrays/maps, required fields, and `additionalProperties` | **Supported + tested** | Recursive validation is in [`body_value()`](../../../R/body_shapes.R#L338); nested and open-shape transport is covered by [`nested-bodies.R`](../../../tests/nested-bodies.R#L1) and [`native-transport.R`](../../../tests/native-transport.R#L142). |
| `oneOf`, `anyOf`, `allOf`, OAS 3.0 `nullable`, and OAS 3.1 null/type unions | **Supported + tested** | Exact branch-count validation is at [`body_shapes.R`](../../../R/body_shapes.R#L528), with generated transport in [`composition-transport.R`](../../../tests/composition-transport.R#L1) and version semantics in [`schema-versions.R`](../../../tests/schema-versions.R#L1). Composition is not supported for form bodies or parameters. |
| Numeric/string/container bounds, `multipleOf`, `pattern`, `enum`, `const`, and `uniqueItems` | **Supported + tested** | Accepted keyword set and validation are at [`body_shapes.R`](../../../R/body_shapes.R#L31) and [`body_shapes.R`](../../../R/body_shapes.R#L451); adversarial assertions are in [`composition-constraints.R`](../../../tests/composition-constraints.R#L1). R/PCRE regex behavior is used for JSON Schema `pattern`, so dialect-level regex differences are not modeled. |
| `readOnly`/`writeOnly` request semantics | **Supported + tested** | Request normalization recursively removes `readOnly` properties from effective required sets while preserving `writeOnly` and ordinary requirements ([`input_schema.R`](../../../R/input_schema.R)). Generated fixtures omit read-only properties, and request validation rejects callers that supply them ([`body_shapes.R`](../../../R/body_shapes.R)). Referenced, nested, composed, conflicting-direction, and pre-transport cases are covered by [`read-only-request.json`](../../../tests/fixtures/capability-audit/read-only-request.json) and [`capability-audit.R`](../../../tests/capability-audit.R). The documented client policy is to reject, rather than silently strip, supplied read-only fields, as permitted by OAS 3.1; resolved by [GH #22](https://github.com/seanthimons/specmill/issues/22). |
| Discriminator-driven model selection | **Unsupported, validation-neutral** | `discriminator` is retained but unused. Structural `oneOf`/`anyOf` validation still applies. This is not itself a validation error: the OAS [3.0 discriminator rules](https://spec.openapis.org/oas/v3.0.4.html#discriminator-object) and [3.1 rules](https://spec.openapis.org/oas/v3.1.1.html#discriminator-object) state that a discriminator must not change validation outcome. Code generation does not expose named model classes or implicit/mapped discriminator dispatch. |
| Other OAS 3.1 / JSON Schema 2020-12 assertions (`not`, `if`/`then`/`else`, `contains`, `prefixItems`, `unevaluatedProperties`, dependent keywords, and boolean schemas) | **Unsupported (diagnosed)** | Unknown validation keywords fail through [`supported_body()`](../../../R/body_shapes.R#L76); boolean input schemas get a dedicated capability diagnostic ([`input_schema.R`](../../../R/input_schema.R#L22)). The tool does not claim general JSON Schema dialect support. |
| `format`, `contentEncoding`, and `contentMediaType` validation other than binary transport | **Unsupported (silent annotation only)** | These names are accepted but not validated by `body_value()`. This is normally annotation behavior, but APIs relying on client-side format/base64 validation need a custom mapping/helper. |

## Silent-misgeneration reproductions

[`tests/capability-audit.R`](../../../tests/capability-audit.R#L1) executes two
unresolved silent-risk fixtures plus the corrected parameter, request-direction,
and media regressions:

| Fixture | Reproduced behavior | Follow-up |
| --- | --- | --- |
| [`parameter-contracts.json`](../../../tests/fixtures/capability-audit/parameter-contracts.json) | Regression coverage verifies parser diagnostics, ignored OAS 3 reserved headers, valid operation-level overrides, and rejected/permitted empty query values. | Resolved by [GH #20](https://github.com/seanthimons/specmill/issues/20) |
| [`read-only-request.json`](../../../tests/fixtures/capability-audit/read-only-request.json) | Regression coverage verifies omitted/rejected read-only fields, preserved writable requirements, recursive referenced/composed schemas, fixture direction, and conflicting-direction diagnostics. | Resolved by [GH #22](https://github.com/seanthimons/specmill/issues/22) |
| [`swagger-consumes.json`](../../../tests/fixtures/capability-audit/swagger-consumes.json) | Regression coverage verifies inherited document JSON and operation-level octet-stream selection through the generated wrapper. | Resolved by [GH #21](https://github.com/seanthimons/specmill/issues/21) |
| [`operation-server.json`](../../../tests/fixtures/capability-audit/operation-server.json) | Direct initialization embeds the unresolved root `{region}` template; the operation server remains only in `source_operation`, and neither normalized operation nor helper arguments receive a server/base URL. | [GH #11](https://github.com/seanthimons/specmill/issues/11) |
| [`oas30-get-body.json`](../../../tests/fixtures/capability-audit/oas30-get-body.json) | An OAS 3.0 GET `requestBody`, which consumers must ignore, is omitted before wrapper generation and exercised against localhost transport. | Resolved by [GH #24](https://github.com/seanthimons/specmill/issues/24). |

Run the common proof with:

```r
source('tests/capability-audit.R'); capability_audit_acceptance()
```

Callbacks and webhooks are also silently omitted.
The five executable fixtures focus on cases that can produce a wrong target, URL,
media type, or request contract.

## Customization and ownership

- **Keep the request runtime client-owned.** `initialize_client()` creates
  `R/api_request.R` only during initial scaffolding and refuses a conflicting file
  ([`initialization.R`](../../../R/initialization.R#L87)). Normal generation discovers
  the helper and validates its formals; it does not place the helper in generated
  output. Edit it for retries, timeouts, response objects, extra media types, or
  server selection.
- **Use a named helper or a complete request mapping.** `helper` can select another
  client function. Per-operation `inputs` plus `request.arguments` replaces the
  schema-derived facade and can build literals, objects, compact objects, arrays,
  vectors, parameter/hook-state references, or development callbacks
  ([`mappings.R`](../../../R/mappings.R#L322)). Unsupported parser metadata remains
  visible as `mapping_diagnostics`; it is not relabeled native support
  ([`configuration.R`](../../../R/configuration.R#L101)).
- **Retain a hand-written wrapper.** `implementation: existing` requires explicit
  inputs and an exact generated public-formal match, then retains the source rather
  than writing it ([`generation.R`](../../../R/generation.R#L638)). This also permits
  retaining a wholly unsupported operation with an explicit reviewed name
  ([`configuration.R`](../../../R/configuration.R#L69)).
- **Use hooks for parameter/result policy, not transport access.** Pre-request hooks
  can alter public parameter state or skip; post-response hooks receive the decoded
  result. A hook cannot configure the `httr2_request` because the default helper
  constructs and performs it internally.
- **Generated wrappers and auth helpers stay hash-owned.** Manifest hashes and
  lifecycle protection prevent overwriting edited outputs
  ([`application.R`](../../../R/application.R#L200)). An edited generated wrapper or
  `R/api_auth.R` is protected; choose `implementation: existing` before taking
  ownership rather than relying on a conflicting edit.

## Ranked follow-up work

| Rank | Work | Why it ranks here | Tracking |
| ---: | --- | --- | --- |
| 1 | Carry effective root/path/operation server metadata or explicitly diagnose non-root precedence. | Wrong-host requests are high impact. Start with a diagnostic; runtime-selectable servers can remain a client-helper feature until demanded. | [GH #11](https://github.com/seanthimons/specmill/issues/11) |
| 2 | Harden response handling and add a decoder matrix for `application/*+json` and missing `Content-Type`. | Response status/headers and declared contracts are currently lost; the existing decoder also needs its remaining branches pinned down. | [GH #10](https://github.com/seanthimons/specmill/issues/10) |
| 3 | Add configurable pagination while preserving the single-request default. | Broad usability gain for collection APIs, but less immediate correctness risk than silently wrong single requests. | [GH #13](https://github.com/seanthimons/specmill/issues/13) |
| 4 | Remove the TRACE compatibility-parser mismatch and add one method matrix wire check. | The advertised method set currently overstates support; the narrow fix also proves PUT/PATCH/HEAD/OPTIONS. | [GH #23](https://github.com/seanthimons/specmill/issues/23) |
| 5 | Add catalogue tests for Swagger URL assembly, relative origin resolution, multiple servers, and server-variable defaults as part of server controls. | These paths are implemented and documented but currently supported only by inspection. | [GH #11](https://github.com/seanthimons/specmill/issues/11) |
| 6 | Add OAuth lifecycle only when GH #4's contract is settled. | Broad authentication value, but intentionally separate from this audit and substantially larger than the correctness fixes above. | [GH #4](https://github.com/seanthimons/specmill/issues/4) |

GH #11 links the remaining executable silent-risk fixture to bounded follow-up
work.

## Verification commands

These standalone acceptance scripts are the focused executable evidence for this
matrix:

```r
source('tests/parameter-transport.R'); parameter_transport_acceptance()
source('tests/bracket-transport.R'); bracket_transport_acceptance()
source('tests/media-types.R'); media_type_acceptance()
source('tests/form-transport.R'); form_transport_acceptance()
source('tests/authentication.R'); authentication_acceptance()
source('tests/native-transport.R'); native_transport_acceptance()
source('tests/composition-transport.R'); composition_transport_acceptance()
source('tests/composition-constraints.R'); composition_constraints_acceptance()
source('tests/schema-versions.R'); schema_version_acceptance()
source('tests/local-references.R'); local_references_acceptance()
source('tests/mappings.R'); mappings_acceptance()
source('tests/source-layout.R'); source_layout_acceptance()
source('tests/capability-audit.R'); capability_audit_acceptance()
```

The audit changes no production code.
